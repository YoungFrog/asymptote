/*****
 * util.cc
 * John Bowman
 *
 * A place for useful utility functions.
 *****/

#include <cassert>
#include <iostream>
#include <cstdio>
#include <cfloat>
#include <sstream>
#include <cerrno>
#include <sys/wait.h>
#include <sys/param.h>
#include <unistd.h>
#include <signal.h>

#include "util.h"
#include "settings.h"
#include "errormsg.h"
#include "camperror.h"
#include "interact.h"

using namespace settings;

bool False=false;

string stripext(const string& name, const string& ext)
{
  string suffix = "." + ext;
  size_t p=name.rfind(suffix);
  if (p == name.length()-suffix.length())
    return name.substr(0,p);
  else return name;
}

void backslashToSlash(string& s) 
{
  size_t p;
  while ((p=s.find('\\')) < string::npos)
    s[p]='/';
}

#ifdef __CYGWIN__
string Getenv(const char *name, bool quote)
{
  char *s=getenv(name);
  if(!s) return "";
  string S=string(s);
  backslashToSlash(S);
  if(quote) S="'"+S+"'";
  return S;
}
#else
string Getenv(const char *name, bool)
{
  char *s=getenv(name);
  if(!s) return "";
  return string(s);
}
#endif

string& stripDir(string& name)
{
  size_t p;
#ifdef __CYGWIN__  
  p=name.rfind('\\');
  if(p < string::npos) name.erase(0,p+1);
#endif  
  p=name.rfind('/');
  if(p < string::npos) name.erase(0,p+1);
  return name;
}

string buildname(string name, string suffix, string aux, bool stripdir) 
{
  if(stripdir) stripDir(name);
    
  name = stripext(name,getSetting<mem::string>("outformat"));
  name += aux;
  if(!suffix.empty()) name += "."+suffix;
  return name;
}

string auxname(string filename, string suffix)
{
  return buildname(filename,suffix,"_");
}
  
bool checkFormatString(const string& format)
{
  if(format.find(' ') != string::npos) { // Avoid potential security hole
    ostringstream msg;
    msg << "output format \'" << format << "\' is invalid";
    camp::reportError(msg);
  }
  return true;
}
  
// Return an argv array corresponding to the fields in command delimited
// by spaces not within matching single quotes.
char **args(const char *command)
{
  if(command == NULL) return NULL;
  
  int n=0;
  char **argv=NULL;  
  for(int pass=0; pass < 2; ++pass) {
    if(pass) argv=new char*[n+1];
    ostringstream buf;
    const char *p=command;
    bool empty=true;
    bool quote=false;
    n=0;
    char c;
    while((c=*(p++))) {
      if(!quote && c == ' ') {
	if(!empty) {
	  if(pass) {
	    argv[n]=strcpy(new char[buf.str().size()+1],buf.str().c_str());
	    buf.str("");
	  }
	  empty=true;
	  n++;
	}
      } else {
	empty=false;
	if(c == '\'') quote=!quote;
	else if(pass) buf << c;
      }
    }
    if(!empty) {
      if(pass) argv[n]=strcpy(new char[buf.str().size()+1],buf.str().c_str());
      n++;
    }
  }
  
  argv[n]=NULL;
  return argv;
}

void execError(const char *command, const char *hint, const char *application)
{
    cerr << "Cannot execute " << command << endl;
    if(hint) 
      cerr << "Please set the environment variable " << hint << endl
	   << "to the location of " << application << endl;
    exit(-1);
}
						    
int System(const char *command, bool quiet, bool wait,
	   const char *hint, const char *application, int *ppid)
{
  int status;

  if(!command) return 1;
  if(settings::verbose > 1) cerr << command << endl;

  cout.flush(); // Flush stdout to avoid duplicate output.
    
  int pid = fork();
  if(pid == -1)
    camp::reportError("Cannot fork process");
  
  char **argv=args(command);
  if(pid == 0) {
    if(interact::interactive) signal(SIGINT,SIG_IGN);
    if(quiet) close(STDOUT_FILENO);
    if(argv) execvp(argv[0],argv);
    execError(argv[0],hint,application);
  }

  if(ppid) *ppid=pid;
  for(;;) {
    if(waitpid(pid, &status, wait ? 0 : WNOHANG) == -1) {
      if(errno == ECHILD) return 0;
      if(errno != EINTR) {
        ostringstream msg;
        msg << "Command " << command << " failed";
        camp::reportError(msg);
      }
    } else {
      if(!wait) return 0;
      if(WIFEXITED(status)) {
	if(argv) {
	  char **p=argv;
	  char *s;
	  while((s=*(p++)) != NULL)
	    delete [] s;
	  delete [] argv;
	}
	return WEXITSTATUS(status);
      } else {
        ostringstream msg;
        msg << "Command " << command << " exited abnormally";
        camp::reportError(msg);
      }
    }
  }
}

int System(const ostringstream& command, bool quiet, bool wait,
	   const char *hint, const char *application, int *pid)
{
  return System(command.str().c_str(),quiet,wait,hint,application,pid);
}

string stripblanklines(string& s)
{
  bool blank=true;
  const char *t=s.c_str();
  size_t len=s.length();
  
  for(size_t i=0; i < len; i++) {
    if(t[i] == '\n') {
      if(blank) s[i]=' ';
      else blank=true;
    } else if(t[i] != '\t' && t[i] != ' ') blank=false;
  }
  return s;
}

static char *startpath=NULL;
char *currentpath=NULL;

char *startPath()
{
  return startpath;
}

void noPath()
{
  camp::reportError("Cannot get current path");
}

char *getPath(char *p)
{
  static int size=MAXPATHLEN;
  if(!p) p=new char[size];
  if(!p) noPath();
  else while(getcwd(p,size) == NULL) {
    if(errno == ERANGE) {
      size *= 2;
      delete [] p;
      p=new char[size];
    } else {noPath(); p=NULL;}
  }
  return p;
}

int setPath(const char *s)
{
  if(s != NULL && *s != 0) {
    if(startpath == NULL) startpath=getPath(startpath);
    return chdir(s);
  } return 0;
}
