/*****
 * coder.cc
 * Andy Hammerlindl 2004/11/06
 *
 * Handles encoding of syntax into programs.  It's methods are called by
 * abstract syntax objects during translation to construct the virtual machine
 * code.
 *****/

#include <utility>

#include "errormsg.h"
#include "coder.h"
#include "genv.h"
#include "entry.h"

using namespace sym;
using namespace types;

namespace trans {

namespace {
function *inittype();
function *bootuptype();
}

// The dummy environment of the global environment.
// Used purely for global variables and static code blocks of file
// level modules.
coder::coder(modifier sord)
  : level(new frame(0, 0)),
    recordLevel(0),
    recordType(0),
    l(new vm::lambda),
    funtype(bootuptype()),
    parent(0),
    sord(sord),
    perm(READONLY),
    program(),
    numLabels(0)
{
  sord_stack.push(sord);
}

// Defines a new function environment.
coder::coder(function *t, coder &parent, modifier sord)
  : level(new frame(parent.getFrame(), t->sig.getNumFormals())),
    recordLevel(parent.recordLevel),
    recordType(parent.recordType),
    l(new vm::lambda),
    funtype(t),
    parent(&parent),
    sord(sord),
    perm(READONLY),
    program(),
    numLabels(0)
{
  sord_stack.push(sord);
}

// Start encoding the body of the record.  The function being encoded
// is the record's initializer.
coder::coder(record *t, coder &parent, modifier sord)
  : level(t->getLevel()),
    recordLevel(t->getLevel()),
    recordType(t),
    l(t->getInit()),
    funtype(inittype()),
    parent(&parent),
    sord(sord),
    perm(READONLY),
    program(),
    numLabels(0)
{
  sord_stack.push(sord);
}

coder coder::newFunction(function *t, modifier sord)
{
  return coder(t, *this, sord);
}

record *coder::newRecord(symbol *id)
{
  frame *underlevel = getFrame();

  frame *level = new frame(underlevel, 0);
  
  vm::lambda *init = new vm::lambda;

  record *r = new record(id, level, init);

  return r;
}

coder coder::newRecordInit(record *r, modifier sord)
{
  return coder(r, *this, sord);
}


bool coder::encode(frame *f)
{
  frame *toplevel = getFrame();
  
  if (f == 0) {
    encode(inst::constpush,(item)0);
  }
  else if (f == toplevel) {
    encode(inst::pushclosure);
  }
  else {
    encode(inst::varpush,0);
    
    frame *level = toplevel->getParent();
    while (level != f) {
      if (level == 0)
	// Frame request was in an improper scope.
	return false;

      encode(inst::fieldpush,0);

      level = level->getParent();
    }
  }

  return true;
}

bool coder::encode(frame *dest, frame *top)
{
  //std::cerr << "coder::encode()\n";
  
  if (dest == 0) {
    encode(inst::pop);
    encode(inst::constpush,(item)0);
  }
  else {
    frame *level = top;
    while (level != dest) {
      if (level == 0) {
	// Frame request was in an improper scope.
	//std::cerr << "failed\n";
	
	return false;
      }

      encode(inst::fieldpush,0);

      level = level->getParent();
    }
  }

  //std::cerr << "succeeded\n";
  return true;
}

int coder::defLabel()
{
  if (isStatic())
    return parent->defLabel();
  
  //defs.insert(std::make_pair(numLabel,program.size()));
  return defLabel(numLabels++);
}

int coder::defLabel(int label)
{
  if (isStatic())
    return parent->defLabel(label);
  
  assert(label >= 0 && label < numLabels);

  defs.insert(std::make_pair(label,program.end()));

  std::multimap<int,vm::program::label>::iterator p = uses.lower_bound(label);
  while (p != uses.upper_bound(label)) {
    p->second->label = program.end();
    ++p;
  }

  return label;
}

void coder::useLabel(inst::opcode op, int label)
{
  if (isStatic())
    return parent->useLabel(op,label);
  
  std::map<int,vm::program::label>::iterator p = defs.find(label);
  if (p != defs.end()) {
    inst i; i.op = op; i.label = p->second;
    program.encode(i);
  } else {
    // Not yet defined
    uses.insert(std::make_pair(label,program.end()));
    inst i; i.op = op; 
    program.encode(i);
  }
}

int coder::fwdLabel()
{
  if (isStatic())
    return parent->fwdLabel();
  
  // Create a new label without specifying its position.
  return numLabels++;
}

void coder::markPos(position pos)
{
  if (isStatic())
    parent->markPos(pos);
  else
    l->pl.push_back(lambda::instpos(program.end(), pos));
}

// When translating the function is finished, this ties up loose ends
// and returns the lambda.
vm::lambda *coder::close() {
  // These steps must be done dynamically, not statically.
  sord = EXPLICIT_DYNAMIC;
  sord_stack.push(sord);

  // Add a return for void types; may be redundant.
  if (funtype->result->kind == types::ty_void)
    encode(inst::ret);

  l->code = program;
  l->maxStackSize = 10; // NOTE: To be implemented.
  l->params = level->getNumFormals();
  l->vars = level->size();

  sord_stack.pop();
  sord = sord_stack.top();

  return l;
}

bool coder::isRecord()
{
  return (funtype==inittype());
}

namespace {
function *inittype()
{
  static function t(types::primVoid());
  return &t;
}

function *bootuptype()
{
  static function t(types::primVoid());
  return &t;
}
} // private

} // namespace trans

