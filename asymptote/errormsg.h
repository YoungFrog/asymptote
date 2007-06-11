/*****
 * errormsg.h
 * Andy Hammerlindl 2002/06/17
 *
 * Used in all phases of the compiler to give error messages.
 *****/

#ifndef ERRORMSG_H
#define ERRORMSG_H

#include <iostream>
#include "common.h"
#include "settings.h"

using std::ostream;

struct handled_error {}; // Exception to process next file.
struct interrupted {};   // Exception to interrupt execution.
struct quit {};          // Exception to quit current operation.
struct eof {};           // Exception to exit interactive mode.

class fileinfo : public gc {
  string filename;
  size_t lineNum;

public:
  fileinfo(string filename, size_t lineNum=1)
    : filename(filename), lineNum(lineNum) {}

  size_t line() const
  {
    return lineNum;
  }
  
  string name() const {
    return filename;
  }
  
  // Specifies a newline symbol at the character position given.
  void newline() {
    ++lineNum;
  }
  
};

inline bool operator == (const fileinfo& a, const fileinfo& b)
{
  return a.line() == b.line() && a.name() == b.name();
}



class position {
  fileinfo *file;
  size_t line;
  size_t column;

public:
  void init(fileinfo *f, int p) {
    file = f;
    if (file) {
      line = file->line();
      column = p;
    } else {
      line = column = 0;
    }
  }

  string filename() const
  {
    return file ? file->name() : "";
  }
  
  size_t Line() const
  {
    return line;
  }
  
  size_t Column() const
  {
    return column;
  }
  
  bool match(const string& s) {
    return file && file->name() == s;
  }
  
  bool match(size_t l) {
    return line == l;
  }
  
  bool matchColumn(size_t c) {
    return column == c;
  }
  
  bool operator! () const
  {
    return (file == 0);
  }
  
  friend ostream& operator << (ostream& out, const position& pos);

  static position nullPos() {
    position p;
    p.init(0,0);
    return p;
  }
};

inline bool operator == (const position& a, const position& b)
{
  return a.Line() == b.Line() && a.Column() == b.Column() && 
    a.filename() == b.filename(); 
}

class errorstream {
  ostream& out;
  bool anyErrors;
  bool anyWarnings;
  bool floating;	// Was a message output without a terminating newline?
  
  // Is there an error that warrants the asy process to return 1 instead of 0?
  bool anyStatusErrors;

public:
  static bool interrupt; // Is there a pending interrupt?
  
  errorstream(ostream& out = cerr)
    : out(out), anyErrors(false), anyWarnings(false), floating(false),
      anyStatusErrors(false) {}


  void clear();

  void message(position pos, const string& s);
  
  void Interrupt(bool b) {
    interrupt=b;
  }
  
  // An error is encountered, not in the user's code, but in the way the
  // compiler works!  This may be augmented in the future with a message
  // to contact the compiler writers.
  void compiler();
  void compiler(position pos);

  // An error encountered when running compiled code.  This method does
  // not stop the executable, but the executable should be stopped
  // shortly after calling this method.
  void runtime(position pos);

  // Errors encountered when compiling making it impossible to run the code.
  void error(position pos);

  // Indicate potential problems in the code, but the code is still usable.
  void warning(position pos);

  // Print out position in code to aid debugging.
  void trace(position pos);
  
  // Sends stuff to out to print.
  // NOTE: May later make it do automatic line breaking for long messages.
  template<class T>
  errorstream& operator << (const T& x) {
    flush(out);
    out << x;
    return *this;
  }

  // Reporting errors to the stream may be incomplete.  This draws the
  // appropriate newlines or file excerpts that may be needed at the end.
  void sync();

  void cont();
  
  bool errors() const {
    return anyErrors;
  }
  
  bool warnings() const {
    return anyWarnings || errors();
  }

  void statusError() {
    anyStatusErrors=true;
  }

  // Returns true if no errors have occured that should be reported by the
  // return value of the process.
  bool processStatus() const {
    return !anyStatusErrors;
  }
};

extern errorstream *em;

#endif
