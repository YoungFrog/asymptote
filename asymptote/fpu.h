#ifndef FPU_H
#define FPU_H

#ifdef HAVE_CONFIG_H
#include "config.h"
#endif

#ifdef HAVE_FENV_H
#include <fenv.h>

inline int fpu_exceptions() {
  int excepts=0;
#ifdef FE_INVALID    
  excepts |= FE_INVALID;
#endif    
#ifdef FE_DIVBYZERO
  excepts |= FE_DIVBYZERO;
#endif  
#ifdef FE_OVERFLOW
  excepts |= FE_OVERFLOW;
#endif  
  return excepts;
}

#ifdef _GNU_SOURCE
inline void fpu_trap(bool trap)
{
  // Conditionally trap FPU exceptions on NaN, zero divide and overflow.
  if(trap) feenableexcept(fpu_exceptions());
  else fedisableexcept(fpu_exceptions());
}
#else
inline void fpu_trap(bool) {}
#endif  

#endif

#endif
