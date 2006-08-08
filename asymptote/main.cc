#include <iostream>
#include <csignal>
#include <cstdlib>

#ifdef HAVE_CONFIG_H
#include "config.h"
#endif

#ifdef HAVE_LIBSIGSEGV
#include <sigsegv.h>
#endif

#include "types.h"
#include "errormsg.h"
#include "fpu.h"
#include "genv.h"
#include "stm.h"
#include "settings.h"
#include "locate.h"
#include "vm.h"
#include "program.h"
#include "interact.h"
#include "envcompleter.h"
#include "parser.h"
#include "fileio.h"

#include "stack.h"
#include "runtime.h"
#include "texfile.h"

namespace run {
  void cleanup();
  void exitFunction(vm::stack *Stack);
  void updateFunction(vm::stack *Stack);
}

namespace vm {
  bool indebugger;  
}

using namespace settings;
using std::list;

using absyntax::file;
using trans::genv;
using trans::coenv;
using trans::env;
using trans::coder;
using types::record;

errorstream *em;
using interact::interactive;
using interact::virtualEOF;
using interact::resetenv;
using interact::uptodate;

#ifdef HAVE_LIBSIGSEGV
void stackoverflow_handler (int, stackoverflow_context_t)
{
  if(em) em->runtime(vm::getPos());
  cerr << "Stack overflow" << endl;
  abort();
}

int sigsegv_handler (void *, int emergency)
{
  if(!emergency) return 0; // Really a stack overflow
  if(em) em->runtime(vm::getPos());
  cerr << "Segmentation fault" << endl;
  cerr << "Please report this programming error to" << endl 
       << BUGREPORT << endl;
  abort();
}
#endif 

void setsignal(RETSIGTYPE (*handler)(int))
{
#ifdef HAVE_LIBSIGSEGV
  char mystack[16384];
  stackoverflow_install_handler(&stackoverflow_handler,
				mystack,sizeof (mystack));
  sigsegv_install_handler(&sigsegv_handler);
#endif
  signal(SIGBUS,handler);
  signal(SIGFPE,handler);
}

void signalHandler(int)
{
  if(em) em->runtime(vm::getPos());
  signal(SIGBUS,SIG_DFL);
  signal(SIGFPE,SIG_DFL);
}

void interruptHandler(int)
{
  if(em) em->Interrupt(true);
}

bool status=true;

namespace loop {

void init()
{
  vm::indebugger=false;
  setPath(startPath());
  ShipoutNumber=0;
  if(!em)
    em = new errorstream();
}

void purge()
{
#ifdef USEGC
  GC_gcollect();
#endif
}

// Run (an already translated) module of the given filename.
void doRun(genv& ge, std::string filename)
{
  vm::stack s;
  s.setInitMap(ge.getInitMap());
  s.load(filename);
  run::exitFunction(&s);
}

typedef vm::interactiveStack istack;
using absyntax::runnable;
using absyntax::block;

// Abstract base class for the core object being run in line-at-a-time mode, it
// may be a runnable, block, file, or interactive prompt.
struct icore {
  virtual ~icore() {}
  virtual void run(coenv &e, istack &s) = 0;
};

struct irunnable : public icore {
  runnable *r;

  irunnable(runnable *r)
    : r(r) {}

  void run(coenv &e, istack &s) {
    e.e.beginScope();
    lambda *codelet=r->transAsCodelet(e);
    em->sync();
    if(!em->errors()) {
      if(getSetting<bool>("translate")) print(cout,codelet->code);
      s.run(codelet);
    } else {
      e.e.endScope(); // Remove any changes to the environment.
      status=false;
    }
  }
};

struct itree : public icore {
  absyntax::block *ast;

  itree() : ast(0) {}
  
  itree(absyntax::block *ast)
    : ast(ast) {}

  void set(block *a) {ast=a;}
  
  void run(coenv &e, istack &s) {
    for(list<runnable *>::iterator r=ast->stms.begin();
	r != ast->stms.end(); ++r)
      if(!em->errors() || getSetting<bool>("debug")) 
	irunnable(*r).run(e,s);
  }
};

struct iprompt : public itree {
  iprompt() : itree() {}
  
  iprompt(absyntax::block *ast)
    : itree(ast) {}
  
  void run(coenv &e, istack &s) {
    interact::setCompleter(new trans::envCompleter(e.e));

    virtualEOF=true;
    while (virtualEOF) {
      try {
      if(!ast) {
	virtualEOF=false;
	set(parser::parseInteractive());
	if(resetenv) {uptodate=true; purge(); break;}
      }
      itree::run(e,s);
      if(!uptodate && virtualEOF)
	run::updateFunction(&s);
      } catch(handled_error) {
	vm::indebugger=false;
      } catch(interrupted&) {
	if(em) em->Interrupt(false);
	cout << endl;
      }
      ast=0;
      purge(); // Close any files that have gone out of scope.
    }
  }
};

void doICore(icore &i, bool embedded=false) {
  assert(em);
  em->sync();
  if(em->errors()) return;
  
  static mem::vector<coenv*> estack;
  static mem::vector<vm::interactiveStack*> sstack;
  
  try {
    if(embedded) {
      assert(estack.size() && sstack.size());
      i.run(*(estack.back()),*(sstack.back()));
    } else {
      purge();
      
      genv ge;
      env base_env(ge);
      coder base_coder;
      coenv e(base_coder,base_env);
      
      vm::interactiveStack s;
      s.setInitMap(ge.getInitMap());

      estack.push_back(&e);
      sstack.push_back(&s);

      std::list<string> TeXpipepreamble_save=
	std::list<string>(camp::TeXpipepreamble);
      std::list<string> TeXpreamble_save=
	std::list<string>(camp::TeXpreamble);
      
      if(settings::getSetting<bool>("autoplain")) {
	absyntax::runnable *r=absyntax::autoplainRunnable();
	irunnable(r).run(e,s);
      }

      // Now that everything is set up, run the core.
      i.run(e,s);
      
      if(interactive) {
	if(resetenv) run::cleanup();
	else {
	  interactive=false;
	  run::exitFunction(&s);
	  interactive=true;
	}
      } else run::exitFunction(&s);
      
      camp::TeXpipepreamble=TeXpipepreamble_save;
      camp::TeXpreamble=TeXpreamble_save;
      
      if(settings::getSetting<bool>("listvariables"))
	base_env.list();
    }
  } catch(std::bad_alloc&) {
    cerr << "error: out of memory" << endl;
    status=false;
  } catch(handled_error) {
    status=false;
    run::cleanup();
  }

  if(!embedded) {
    estack.pop_back();
    sstack.pop_back();
  }
  
  em->clear();
}
      
void doIRunnable(runnable *r, bool embedded=false) {
  assert(r);
  irunnable i(r);
  doICore(i,embedded);
}

void doITree(block *tree, bool embedded=false) {
  assert(tree);
  itree i(tree);
  doICore(i,embedded);
}

void doIFile(const string& filename) {
  init();

  string basename = stripext(filename,suffix);
  if(settings::verbose) cout << "Processing " << basename << endl;
  
  try {
    if(getSetting<bool>("parseonly")) {
      absyntax::file *tree = parser::parseFile(filename);
      assert(tree);
      em->sync();
      if(!em->errors())
	tree->prettyprint(cout, 0);
      else status=false;
    } else {
      if(filename == "")
	doITree(parser::parseString(""));
      else {
	if(getSetting<mem::string>("outname").empty())
	  Setting("outname")=
            (mem::string)((filename == "-") ? "out" : stripDir(basename));
	doITree(parser::parseFile(filename));
	Setting("outname")=(mem::string)"";
      }
    }
  } catch(handled_error) {
    status=false;
  }
}

void doIPrompt() {
  if(!getSetting<bool>("quiet"))
    cout << "Welcome to " << PROGRAM << " version " << VERSION
	 << " (to view the manual, type help)" << endl;
  
  interact::init_interactive();
  
  Setting("outname")=(mem::string)"out";
  
  iprompt i;
  while(virtualEOF) {
    try {
      init();
      resetenv=false;
      doICore(i);
    } catch(interrupted&) {
      if(em) em->Interrupt(false);
      cout << endl;
    }
  }
  Setting("outname")=(mem::string)"";
}

// Run the config file.
void doConfig(string filename) {
  string file = settings::locateFile(filename);
  if(!file.empty()) {
    bool autoplain=getSetting<bool>("autoplain");
    bool listvariables=settings::getSetting<bool>("listvariables");
    if(autoplain) Setting("autoplain")=false; // Turn off for speed.
    if(listvariables) Setting("listvariables")=false;
    doIFile(file);
    if(autoplain) Setting("autoplain")=true;
    if(listvariables) Setting("listvariables")=true;
  }
}

} // namespace loop

int main(int argc, char *argv[])
{
#ifdef USEGC
  GC_free_space_divisor = 2;
  GC_dont_expand = 0;
  GC_INIT();
#endif  
  
  setsignal(signalHandler);

  try {
    setOptions(argc,argv);
  } catch(handled_error) {
    status=false;
  }
  
  fpu_trap(trap());

  if(interactive) {
    signal(SIGINT,interruptHandler);
    loop::doIPrompt();
  } else {
    if(numArgs() == 0)
      loop::doIFile("");
    else {
      for(int ind=0; ind < numArgs() ; ind++) {
	loop::doIFile(string(getArg(ind)));
	try {
	  if(ind < numArgs()-1) setOptions(argc,argv);
	} catch(handled_error) {
	  status=false;
	} 
      }
    }
  }
  loop::purge();
  return status ? 0 : 1;
}
