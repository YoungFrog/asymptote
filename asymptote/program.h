/*****
 * program.h
 * Tom Prince
 * 
 * The list of instructions used by the virtual machine.
 *****/

#ifndef PROGRAM_H
#define PROGRAM_H

#include "memory.h"
#include "inst.h"

namespace vm {
class inst;

class program : public gc {
public:
  class label;
  program();
  void encode(inst i);
  label begin();
  label end();
private:
  friend class label;
  typedef mem::deque<inst> code_t;
  code_t code;
  inst& operator[](size_t);
};

class program::label
{
public: // interface
  label() : where(0), code() {}
public: //interface
  label& operator++();
  bool operator==(const label& right) const;
  bool operator!=(const label& right) const;
  inst& operator*() const;
  inst* operator->() const;
  friend ptrdiff_t offset(const label& left,
                          const label& right);
private:
  label (size_t where, program* code)
    : where(where), code(code) {}
  size_t where;
  program* code;
  friend class program;
};

// Prints one instruction (including arguments) and returns how many
// positions in the code stream were shown.
void printInst(std::ostream& out, const program::label& code,
	       const program::label& base);

// Prints code until a ret opcode is printed.
void print(std::ostream& out, program *base);

// Inline forwarding functions for vm::program
inline program::program()
  : code() {}
inline program::label program::end()
{ return label(code.size(), this); }
inline program::label program::begin()
{ return label(0, this); }
inline void program::encode(inst i)
{ code.push_back(i); }
inline inst& program::operator[](size_t n)
{ return code[n]; }
inline program::label& program::label::operator++()
{ ++where; return *this; }
inline bool program::label::operator==(const label& right) const
{ return (code == right.code) && (where == right.where); }
inline bool program::label::operator!=(const label& right) const
{ return !(*this == right); }
inline inst& program::label::operator*() const
{ return (*code)[where]; }
inline inst* program::label::operator->() const
{ return &**this; }
inline ptrdiff_t offset(const program::label& left,
                        const program::label& right)
{ return right.where - left.where; }

} // namespace vm

#endif // PROGRAM_H
