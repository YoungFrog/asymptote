#include <iostream>
#include <csignal>
#include <cstdlib>

#ifdef HAVE_CONFIG_H
#include "config.h"
#endif

#ifdef HAVE_LIBSIGSEGV
#include <sigsegv.h>
#endif

#include "errormsg.h"
#include "fpu.h"
#include "settings.h"
#include "locate.h"
#include "interact.h"
#include "process.h"

#include "stack.h"

using namespace settings;
using std::list;

errorstream *em;
using interact::interactive;

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
  if (em) {
    // Print the position and trust the shell to print an error message.
    em->runtime(vm::getPos());
  }
  signal(SIGBUS,SIG_DFL);
  signal(SIGFPE,SIG_DFL);
}

void interruptHandler(int)
{
  if(em) em->Interrupt(true);
}

//bool status=true;

// Run the config file.
void doConfig(string filename) {
  string file = locateFile(filename);
  if(!file.empty()) {
    bool autoplain=getSetting<bool>("autoplain");
    bool listvariables=getSetting<bool>("listvariables");
    if(autoplain) Setting("autoplain")=false; // Turn off for speed.
    if(listvariables) Setting("listvariables")=false;

    runFile(file);

    if(autoplain) Setting("autoplain")=true;
    if(listvariables) Setting("listvariables")=true;
  }
}

int main(int argc, char *argv[])
{
#ifdef USEGC
  GC_free_space_divisor = 2;
  GC_dont_expand = 0;
  GC_INIT();
#endif  
  
  setsignal(signalHandler);

  // NOTE: Change em to not be a pointer.
  em = new errorstream;

  try {
    setOptions(argc,argv);
  } catch(handled_error) {
    em->statusError();
  }
  
  fpu_trap(trap());

  if(interactive) {
    signal(SIGINT,interruptHandler);
    processPrompt();
  } else if (getSetting<bool>("listvariables") && numArgs()==0) {
    doUnrestrictedList();
  } else {
    for(int ind=0; ind < numArgs() ; ind++) {
      processFile(string(getArg(ind)));
      try {
        if(ind < numArgs()-1)
          setOptions(argc,argv);
      } catch(handled_error) {
        em->statusError();
      } 
    }
  }

#ifdef USEGC
  GC_gcollect();
#endif

  return em->processStatus() ? 0 : 1;
}
