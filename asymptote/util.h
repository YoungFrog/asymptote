/*****
 * util.h
 * Andy Hammerlindl 2004/05/10
 *
 * A place for useful utility functions.
 *****/

#ifndef UTIL_H
#define UTIL_H

#include <sys/types.h>
#include <iostream>

#include "memory.h"

using std::cout;
using std::cerr;
using std::endl;

#include <strings.h>

mem::string stripExt(mem::string name, const mem::string& suffix="");
  
void writeDisabled();
  
// Check if global writes disabled and name contains a directory.
void checkLocal(mem::string name);
  
// Strip the directory from a filename.
mem::string stripDir(mem::string name);
  
// Construct a filename from the original, adding aux at the end, and
// changing the suffix.
mem::string buildname(mem::string filename, mem::string suffix="",
		      mem::string aux="", bool stripdir=true);

// Construct an alternate filename for a temporary file in the current
// directory.
mem::string auxname(mem::string filename, mem::string suffix="");

// Similar to the standard system call except allows interrupts and does
// not invoke a shell.
int System(const char *command, int quiet=0, bool wait=true,
	   const char *hint=NULL, const char *application="",
	   int *pid=NULL);
int System(const mem::ostringstream& command, int quiet=0, bool wait=true,
	   const char *hint=NULL, const char *application="",
	   int *pid=NULL); 
  
#if defined(__DECCXX_LIBCXX_RH70)
extern "C" int kill(pid_t pid, int sig) throw();
extern "C" char *strsignal(int sig);
extern "C" double asinh(double x);
extern "C" double acosh(double x);
extern "C" double atanh(double x);
extern "C" double cbrt(double x);
extern "C" double erf(double x);
extern "C" double erfc(double x);
extern "C" double tgamma(double x);
extern "C" double remainder(double x, double y);
extern "C" double hypot(double x, double y) throw();
extern "C" double jn(int n, double x);
extern "C" double yn(int n, double x);
#endif

#if defined(__mips)
extern "C" double tgamma(double x);
#endif

#if defined(__DECCXX_LIBCXX_RH70) || defined(__CYGWIN__)
extern "C" int snprintf(char *str, size_t size, const char *format,...);
extern "C" int fileno(FILE *);
extern "C" char *strptime(const char *s, const char *format, struct tm *tm);
#endif

extern bool False;

// Strip blank lines (which would break the bidirectional TeX pipe)
mem::string stripblanklines(mem::string& s);

extern char *currentpath;

const char *startPath();
char *getPath(char *p=currentpath);
const char* setPath(const char *s, bool quiet=false);
const char *changeDirectory(const char *s);
extern char *startpath;

void backslashToSlash(mem::string& s);
void spaceToUnderscore(mem::string& s);
mem::string Getenv(const char *name, bool msdos);

void execError(const char *command, const char *hint, const char *application);
  
// This invokes a viewer to display the manual.  Subsequent calls will only
// pop-up a new viewer if the old one has been closed.
void popupHelp();
#endif
