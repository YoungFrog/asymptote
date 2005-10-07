/*****
 * runtime.cc
 * Andy Hammerlindl 2002/7/31
 *
 * Defines some runtime functions used by the stack machine.
 *
 *****/

#include <cassert>
#include <cstdio>
#include <cfloat>
#include <cmath>
#include <sstream>
#include <iostream>
#include <cassert>
#include <sstream>
#include <time.h>

using std::cin;
using std::cout;
using std::cerr;
using std::endl;
using std::ostringstream;

#ifdef HAVE_CONFIG_H
#include "config.h"
#endif

#include "util.h"
#include "pow.h"
#include "errormsg.h"
#include "runtime.h"
#include "settings.h"
#include "guideflags.h"
#include "stack.h"
#include "callable.h"

#include "angle.h"
#include "pair.h"
#include "triple.h"
#include "transform.h"
#include "path.h"
#include "pen.h"
#include "guide.h"
#include "picture.h"
#include "drawpath.h"
#include "drawfill.h"
#include "drawclipbegin.h"
#include "drawclipend.h"
#include "drawlabel.h"
#include "drawverbatim.h"
#include "drawgsave.h"
#include "drawgrestore.h"
#include "drawlayer.h"
#include "drawimage.h"
#include "drawgroup.h"
#include "fileio.h"
#include "genv.h"
#include "builtin.h"
#include "texfile.h"
#include "pipestream.h"
#include "parser.h"

#ifdef HAVE_LIBFFTW3
#include "fftw++.h"
#endif

using namespace vm;
using namespace camp;
using namespace settings;

const int camp::ColorComponents[]={0,0,1,3,4,0};

namespace vm {
const char *arraymismatch=
  "operation attempted on arrays of different lengths.";
}

namespace run {
  
using vm::stack;
using vm::frame;
using camp::pair;
using camp::triple;
using camp::transform;
using mem::string;

// Math
  
void dividebyzero(size_t i=0)
{
  std::ostringstream buf;
  if(i > 0) buf << "array element " << i << ": ";
  buf << "Divide by zero";
  error(buf.str().c_str());
}
  
void intZero(stack *s)
{
  s->push(0);
}

void realZero(stack *s)
{
  s->push(0.0);
}

void boolFalse(stack *s)
{
  s->push(false);  
}

void boolTrue(stack *s)
{
  s->push(true);  
}

void boolNot(stack *s)
{
  s->push(!pop<bool>(s));
}

void boolXor(stack *s)
{
  bool b=pop<bool>(s);
  bool a=pop<bool>(s);
  s->push(a^b ? true : false);  
}

void boolMemEq(stack *s)
{
  frame* b = pop<frame*>(s);
  frame* a = pop<frame*>(s);
  s->push(a == b);
}

void boolMemNeq(stack *s)
{
  frame* b = pop<frame*>(s);
  frame* a = pop<frame*>(s);
  s->push(a != b);
}

void boolFuncEq(stack *s)
{
  callable *l=pop<callable*>(s);
  callable *r=pop<callable*>(s);
  s->push(l->compare(r));
}

void boolFuncNeq(stack *s)
{
  callable *l=pop<callable*>(s);
  callable *r=pop<callable*>(s);
  s->push(!(l->compare(r)));
}

void realFmod(stack *s)
{
  double y = pop<double>(s);
  double x = pop<double>(s);
  if (y == 0.0) dividebyzero();
  double val = fmod(x,y);
  s->push(val);
}

void realIntPow(stack *s)
{
  int y = pop<int>(s);
  double x = pop<double>(s);
  s->push(pow(x,y));
}

void realAtan2(stack *s)
{ 
  s->push(atan2(pop<double>(s),pop<double>(s)));
}  

void realHypot(stack *s)
{ 
  double y = pop<double>(s);
  double x = pop<double>(s);
  
  double sx;
  sx = hypot(x,y);
  s->push(sx);
}  

void realRemainder(stack *s)
{ 
  double y = pop<double>(s);
  double x = pop<double>(s);
  s->push(remainder(x,y));
}  

void realJ(stack *s)
{
  double x = pop<double>(s);
  int n = pop<int>(s);
  s->push(jn(n,x));
}

void realY(stack *s)
{
  double x = pop<double>(s);
  int n = pop<int>(s);
  s->push(yn(n,x));
}

void intQuotient(stack *s)
{ 
  int y = pop<int>(s);
  int x = pop<int>(s);
  if (y == 0) dividebyzero();
  s->push(div(x,y).quot);
}  

void intAbs(stack *s)
{ 
  s->push(abs(pop<int>(s)));
}  

static inline int round(double x) 
{
  return int(x+((x >= 0) ? 0.5 : -0.5));
}

void intCeil(stack *s)
{ 
  double x = pop<double>(s);
  int sx = round(ceil(x));
  s->push(sx);
}  

void intFloor(stack *s)
{ 
  double x = pop<double>(s);
  int sx = round(floor(x));
  s->push(sx);
}  

void intRound(stack *s)
{ 
  double x = pop<double>(s);
  int sx = round(x);
  s->push(sx);
}  

void intSgn(stack *s)
{ 
  double x = pop<double>(s);
  int sx = (x == 0.0 ? 0 : (x > 0.0 ? 1 : -1));
  s->push(sx);
}  

void intRand(stack *s)
{ 
  s->push(rand());
}  

void intSrand(stack *s)
{ 
  int seed = pop<int>(s);
  srand(seed);
}  

void realPi(stack *s)
{ 
  s->push(PI);
}  

void intIntMax(stack *s)
{ 
  s->push(INT_MAX);
}

void realInfinity(stack *s)
{ 
  s->push(HUGE_VAL);
}  

void realRealMax(stack *s)
{ 
  s->push(DBL_MAX);
}

void realRealMin(stack *s)
{ 
  s->push(DBL_MIN);
}  

void realRealEpsilon(stack *s)
{ 
  s->push(DBL_EPSILON);
}  

void intRandMax(stack *s)
{ 
  s->push(RAND_MAX);
}

void boolDeconstruct(stack *s)
{ 
  s->push(settings::deconstruct != 0.0);
}

// Create an empty array.
void emptyArray(stack *s)
{
  s->push(new array(0));
}

// Helper function to create deep arrays.
static array* deepArray(int depth, int *dims)
{
  assert(depth > 0);
  
  if (depth == 1) {
    return new array(dims[0]);
  } else {
    int length = dims[0];
    depth--; dims++;

    array *a = new array(length);

    for (int index = 0; index < length; index++) {
      (*a)[index] = deepArray(depth, dims);
    }
    return a;
  }
}
 

// Create a new array (technically a vector).
// This array will be multidimensional.  First the number of dimensions
// is popped off the stack, followed by each dimension in reverse order.
// The array itself is technically a one dimensional array of one
// dimension arrays and so on.
void newDeepArray(stack *s)
{
  int depth = pop<int>(s);
  assert(depth > 0);

  int *dims = new int[depth];

  for (int index = depth-1; index >= 0; index--)
    dims[index] = pop<int>(s);

  s->push(deepArray(depth, dims));
  delete [] dims;
}

// Creates an array with elements already specified.  First, the number
// of elements is popped off the stack, followed by each element in
// reverse order.
void newInitializedArray(stack *s)
{
  int n = pop<int>(s);
  assert(n >= 0);

  array *a = new array(n);

  for (int index = n-1; index >= 0; index--)
    (*a)[index] = pop(s);

  s->push(a);
}

// Similar to newInitializedArray, but after the n elements, append another
// array to it.
void newAppendedArray(stack *s)
{
  int n = pop<int>(s);
  assert(n >= 0);

  array *tail = pop<array *>(s);

  array *a = new array(n);

  for (int index = n-1; index >= 0; index--)
    (*a)[index] = pop(s);
  
  copy(tail->begin(), tail->end(), back_inserter(*a));

  s->push(a);
}

static void outOfBounds(const char *op, size_t len, int n)
{
  ostringstream buf;
  buf << op << " array of length " << len << " with out-of-bounds index "
      << n;
  error(buf.str().c_str());
}

item& arrayRead(stack *s, int n)  
{
  array *a = pop<array*>(s);
  checkArray(a);
  size_t len=a->size();
  bool cyclic=a->cyclic();
  if(cyclic && len > 0) n=imod(n,len);
  else if(n < 0 || n >= (int) len) outOfBounds("reading",len,n);
  return (*a)[(unsigned) n];
}
  
// Read an element from an array. Checks for initialization & bounds.
void arrayRead(stack *s)
{
  int n = pop<int>(s);
  item& i=arrayRead(s,n);
  if (i.empty()) {
    ostringstream buf;
    buf << "read uninitialized value from array at index " << n;
    error(buf.str().c_str());
  }
  s->push(i);
}

// Read an element from an array of arrays. Check bounds and initialize
// as necessary.
void arrayArrayRead(stack *s)
{
  int n = pop<int>(s);
  item& i=arrayRead(s,n);
  if (i.empty()) i=new array(0);
  s->push(i);
}

// Write an element to an array.  Increase size if necessary.
void arrayWrite(stack *s)
{
  int n = pop<int>(s);
  array *a = pop<array*>(s);
  item value = pop(s);

  checkArray(a);
  size_t len=a->size();
  bool cyclic=a->cyclic();
  if(cyclic && len > 0) n=imod(n,len);
  else {
    if(cyclic) outOfBounds("writing cyclic",len,n);
    if(n < 0) outOfBounds("writing",len,n);
    if(a->size() <= (size_t) n)
      a->resize(n+1);
  }
  (*a)[n] = value;
  s->push(value);
}

// Returns the length of an array.
void arrayLength(stack *s)
{
  array *a = pop<array*>(s);
  checkArray(a);
  s->push((int)a->size());
}

// Return the cyclic flag for an array.
void arrayCyclicFlag(stack *s)
{
  array *a = pop<array*>(s);
  checkArray(a);
  s->push(a->cyclic());
}

// Set the cyclic flag for an array.
void arrayCyclic(stack *s)
{
  array *a = pop<array*>(s);
  checkArray(a);
  s->push((callable*) new thunk(new bfunc(arrayCyclicHelper),a));
}

// The helper function for the cyclic method that sets the cyclic flag.
void arrayCyclicHelper(stack *s)
{
  array *a = pop<array*>(s);
  checkArray(a);
  a->cyclic(pop<bool>(s));
}

// Returns the push method for an array.
void arrayPush(stack *s)
{
  array *a = pop<array*>(s);
  checkArray(a);
  s->push((callable*) new thunk(new bfunc(arrayPushHelper),a));
}

// The helper function for the push method that does the actual operation.
void arrayPushHelper(stack *s)
{
  array *a = pop<array*>(s);
  item i = pop(s);
  checkArray(a);
  a->push(i);
  s->push(i);
}

// Returns the append method for an array.
void arrayAppend(stack *s)
{
  array *a = pop<array*>(s);
  checkArray(a);
  s->push((callable*) new thunk(new bfunc(arrayAppendHelper),a));
}

// The helper function for the append method that appends b to a.
void arrayAppendHelper(stack *s)
{
  array *a = pop<array*>(s);
  array *b = pop<array*>(s);
  checkArray(a);
  checkArray(b);
  size_t size=b->size();
  for(size_t i=0; i < size; i++)
    a->push((*b)[i]);
}

// Returns the pop method for an array.
void arrayPop(stack *s)
{
  array *a = pop<array*>(s);
  checkArray(a);
  s->push((callable*) new thunk(new bfunc(arrayPopHelper),a));
}

// The helper function for the pop method.
void arrayPopHelper(stack *s)
{
  array *a = pop<array*>(s);
  checkArray(a);
  if(a->size() == 0) 
    error("cannot pop element from empty array");
  item i=a->pop();
  s->push(i);
}

void arrayAlias(stack *s)
{
  array *b=pop<array*>(s);
  array *a=pop<array*>(s);
  s->push(a==b);
}

// construct vector obtained by replacing those elements of b for which the
// corresponding elements of a are false by the corresponding element of c.
void arrayConditional(stack *s)
{
  array *c=pop<array*>(s);
  array *b=pop<array*>(s);
  array *a=pop<array*>(s);
  size_t size=a->size();
  array *r=new array(size);
  if(b && c) {
    checkArrays(a,b);
    checkArrays(b,c);
    for(size_t i=0; i < size; i++)
      (*r)[i]=read<bool>(a,i) ? (*b)[i] : (*c)[i];
  } else {
    r->clear();
    if(b) {
      checkArrays(a,b);
      for(size_t i=0; i < size; i++)
        if(read<bool>(a,i)) r->push((*b)[i]);
    } else if(c) {
      checkArrays(a,c);
      for(size_t i=0; i < size; i++)
        if(!read<bool>(a,i)) r->push((*c)[i]);
    }
  }
  
  s->push(r);
}
  
// Return array formed by indexing array a with elements of integer array b
void arrayIntArray(stack *s)
{
  array *b=pop<array*>(s);
  array *a=pop<array*>(s);
  checkArray(a);
  checkArray(b);
  size_t asize=a->size();
  size_t bsize=b->size();
  array *r=new array(bsize);
  for(size_t i=0; i < bsize; i++) {
    int index=read<int>(b,i);
    if(index < 0) index += (int) asize;
    if(index < 0 || index >= (int) asize)
      error("reading out-of-bounds index from array");
    (*r)[i]=(*a)[index];
  }
  s->push(r);
}

// Generate the sequence {f_i : i=0,1,...n-1} given a function f and integer n
void arraySequence(stack *s)
{
  int n=pop<int>(s);
  callable* f = pop<callable*>(s);
  if(n < 0) n=0;
  array *a=new array(n);
  for(int i=0; i < n; ++i) {
    s->push<int>(i);
    f->call(s);
    (*a)[i]=pop(s);
  }
  s->push(a);
}

// Return the array {0,1,...n-1}
void intSequence(stack *s)
{
  int n=pop<int>(s);
  if(n < 0) n=0;
  array *a=new array(n);
  for(int i=0; i < n; ++i) {
    (*a)[i]=i;
  }
  s->push(a);
}

// Apply a function to each element of an array
void arrayFunction(stack *s)
{
  array *a=pop<array*>(s);
  callable* f = pop<callable*>(s);
  checkArray(a);
  size_t size=a->size();
  array *b=new array(size);
  for(size_t i=0; i < size; ++i) {
    s->push((*a)[i]);
    f->call(s);
    (*b)[i]=pop(s);
  }
  s->push(b);
}

// In a boolean array, find the index of the nth true value or -1 if not found
// If n is negative, search backwards.
void arrayFind(stack *s)
{
  int n=pop<int>(s);
  array *a=pop<array*>(s);
  checkArray(a);
  int size=(int) a->size();
  int j=-1;
  if(n > 0)
    for(int i=0; i < size; i++)
      if(read<bool>(a,i)) {
	n--; if(n == 0) {j=i; break;}
      }
  if(n < 0)
    for(int i=size-1; i >= 0; i--)
      if(read<bool>(a,i)) {
	n++; if(n == 0) {j=i; break;}
      }
  s->push(j);
}

void arrayAll(stack *s)
{
  array *a = pop<array*>(s);
  checkArray(a);
  unsigned int size=(unsigned int) a->size();
  bool c=true;
  for(unsigned i=0; i < size; i++)
    if(!get<bool>((*a)[i])) {c=false; break;}
  s->push(c);
}

void arrayBoolNegate(stack *s)
{
  array *a=pop<array*>(s);
  checkArray(a);
  size_t size=a->size();
  array *c=new array(size);
  for(size_t i=0; i < size; i++)
    (*c)[i]=!read<bool>(a,i);
  s->push(c);
}

void arrayBoolSum(stack *s)
{
  array *a=pop<array*>(s);
  checkArray(a);
  size_t size=a->size();
  int sum=0;
  for(size_t i=0; i < size; i++)
    sum += read<bool>(a,i) ? 1 : 0;
  s->push(sum);
}

void arrayCopy(stack *s)
{
  s->push(copyArray(s));
}

void arrayConcat(stack *s)
{
  array *b=pop<array*>(s);
  array *a=pop<array*>(s);
  checkArray(a);
  checkArray(b);
  size_t asize=a->size();
  size_t bsize=b->size();
  array *c=new array(asize+bsize);
  for(size_t i=0; i < asize; i++) 
    (*c)[i]=(*a)[i];
  for(size_t i=0; i < bsize; i++, asize++) 
    (*c)[asize]=(*b)[i];
  s->push(c);
}

void array2Copy(stack *s)
{
  s->push(copyArray2(s));
}

void array2Transpose(stack *s)
{
  array *a=pop<array*>(s);
  checkArray(a);
  size_t asize=a->size();
  array *c=new array(0);
  for(size_t i=0; i < asize; i++) {
    size_t ip=i+1;
    array *ai=read<array*>(a,i);
    checkArray(ai);
    size_t aisize=ai->size();
    size_t csize=c->size();
    if(csize < aisize) {
      c->resize(aisize);
      for(size_t j=csize; j < aisize; j++) {
	(*c)[j]=new array(ip);
      }
    }
    for(size_t j=0; j < aisize; j++) {
    array *cj=read<array*>(c,j);
    if(cj->size() < ip) cj->resize(ip);
    (*cj)[i]=(*ai)[j];
    }
  }
  s->push(c);
}

#ifdef HAVE_LIBFFTW3
// Compute the fast Fourier transform of a pair array
void pairArrayFFT(stack *s)
{
  int sign = pop<int>(s) > 0 ? 1 : -1;
  array *a=pop<array*>(s);
  checkArray(a);
  unsigned n=(unsigned) a->size();
  Complex *f=FFTWComplex(n);
  fft1d Forward(n,sign,f);
  
  for(size_t i=0; i < n; i++) {
    pair z=read<pair>(a,i);
    f[i]=Complex(z.getx(),z.gety());
  }
  Forward.fft(f);
  
  array *c=new array(n);
  for(size_t i=0; i < n; i++) {
    Complex z=f[i];
    (*c)[i]=pair(z.real(),z.imag());
  }
  FFTWdelete(f);
  s->push(c);
}
#endif //  HAVE_LIBFFTW3

inline void CheckReallocate(double *& A, size_t n, size_t& old)
{
  if(n > old) {delete A; A=new double[n]; old=n;}
}

inline void CheckReallocate(double *& A, double *& B, size_t n, size_t& old)
{
  if(n > old) {delete A; A=new double[n]; delete B; B=new double[n]; old=n;}
}

// Solve the problem L\inv f, where f is an n vector and L is the n x n matrix
//
// [ b[0] c[0]           a[0]   ]
// [ a[1] b[1] c[1]             ]
// [      a[2] b[2] c[2]        ]
// [                ...         ]
// [       c[n-1] a[n-1] b[n-1] ]

void tridiagonal(stack *s)
{
  array *f=pop<array*>(s);
  array *c=pop<array*>(s);
  array *b=pop<array*>(s);
  array *a=pop<array*>(s);
  
  checkArray(f);
  checkArray(c);
  checkArray(b);
  checkArray(a);
  
  size_t n=a->size();
  if(n != b->size() || n != c->size() || n != f->size())
    vm::error(arraymismatch);
  
  array *up=new array(n);
  s->push(up);
  array& u=*up;

  if(n == 0) return;
  
  // Special case: Zero Dirichlet boundary conditions
  if(read<double>(a,0) == 0.0 && read<double>(c,n-1) == 0.0) {
    static double *work;
    static size_t size=0;
  
    CheckReallocate(work,n,size);
    
    double temp=1.0/read<double>(b,0);
    u[0]=read<double>(f,0)*temp;
    work[0]=-read<double>(c,0)*temp;
	
    for(size_t i=1; i < n; i++) {
      double temp=1.0/(read<double>(b,i)+read<double>(a,i)*work[i-1]);
      u[i]=(read<double>(f,i)-read<double>(a,i)*read<double>(u,i-1))*temp;
      work[i]=-read<double>(c,i)*temp;
    }

    for(size_t i=n-1; i >= 1; i--)
      u[i-1]=read<double>(u,i-1)+work[i-1]*read<double>(u,i);
    return;
  }
  
  double binv=read<double>(b,0);
  if(binv == 0.0) dividebyzero();
  binv=1.0/binv;
  
  if(n == 1) {u[0]=read<double>(f,0)*binv; return;}
  if(n == 2) {
    double factor=(read<double>(b,0)*read<double>(b,1)-
		   read<double>(a,0)*read<double>(c,1));
    if(factor== 0.0) dividebyzero();
    factor=1.0/factor;
    double temp=(read<double>(b,0)*read<double>(f,1)-
	  read<double>(c,1)*read<double>(f,0))*factor;
    u[0]=(read<double>(b,1)*read<double>(f,0)-
	  read<double>(a,0)*read<double>(f,1))*factor;
    u[1]=temp;
    return;
  }
	
  static double *gamma,*delta;
  static size_t size=0;
  CheckReallocate(gamma,delta,n-2,size);
  
  gamma[0]=read<double>(c,0)*binv;
  delta[0]=read<double>(a,0)*binv;
  u[0]=read<double>(f,0)*binv;
  double beta=read<double>(c,n-1);
  double fn=read<double>(f,n-1)-beta*read<double>(u,0);
  double alpha=read<double>(b,n-1)-beta*delta[0];

  for(size_t i=1; i <= n-3; i++) {
    double alphainv=read<double>(b,i)-read<double>(a,i)*gamma[i-1];
    if(alphainv == 0.0) dividebyzero();
    alphainv=1.0/alphainv;
    beta *= -gamma[i-1];
    gamma[i]=read<double>(c,i)*alphainv;
    u[i]=(read<double>(f,i)-read<double>(a,i)*read<double>(u,i-1))*alphainv;
    fn -= beta*read<double>(u,i);
    delta[i]=-read<double>(a,i)*delta[i-1]*alphainv;
    alpha -= beta*delta[i];
  }
	
  double alphainv=read<double>(b,n-2)-read<double>(a,n-2)*gamma[n-3];
  if(alphainv == 0.0) dividebyzero();
  alphainv=1.0/alphainv;
  u[n-2]=(read<double>(f,n-2)-read<double>(a,n-2)*read<double>(u,n-3))
    *alphainv;
  beta=read<double>(a,n-1)-beta*gamma[n-3];
  double dnm1=(read<double>(c,n-2)-read<double>(a,n-2)*delta[n-3])*alphainv;
  double temp=alpha-beta*dnm1;
  if(temp == 0.0) dividebyzero();
  u[n-1]=temp=(fn-beta*read<double>(u,n-2))/temp;
  u[n-2]=read<double>(u,n-2)-dnm1*temp;
	
  for(size_t i=n-2; i >= 1; i--)
    u[i-1]=read<double>(u,i-1)-gamma[i-1]*read<double>(u,i)-delta[i-1]*temp;
}
  
// Null operations

void pushNullArray(stack *s)
{
  s->push<array*>(0);
}

void pushNullRecord(stack *s)
{
  s->push<frame*>(0);
}

void pushNullFunction(stack *s)
{
  s->push(nullfunc::instance());
}

// Default operations

// This serves as the object for representing a default argument.
struct default_t {};
default_t def;

// Put the default value token on the stack (in place of an argument when making
// a function call).
void pushDefault(stack *s)
{
  s->push(&def);
}

// Test if the value on the stack is the default value token.
void isDefault(stack *s)
{
  try {
    // This assumes that the item is popped before an exception is thrown.
    s->pop<default_t *>();
    s->push(true);
  }
  catch (bad_item_value&) {
    s->push(false);
  }
}

// Casts

void pairToGuide(stack *s) {
  pair z = pop<pair>(s);
  guide *g = new pairguide(z);
  s->push(g);
}

void pathToGuide(stack *s) {
  path p = pop<path>(s);
  guide *g = new pathguide(p);
  s->push(g);
}

void guideToPath(stack *s) {
  guide *g = pop<guide*>(s);
  path p = g->solve();
  s->push(p);
}

// Pair operations
void pairZero(stack *s)
{
  static pair zero;
  s->push(&zero);
}

void realRealToPair(stack *s)
{
  double y = pop<double>(s);
  double x = pop<double>(s);
  s->push(new pair(x,y));
}

void pairNegate(stack *s)
{
  s->push(-pop<pair>(s));
}

void pairXPart(stack *s)
{
  s->push(pop<pair>(s).getx());
}

void pairYPart(stack *s)
{
  s->push(pop<pair>(s).gety());
}

void pairLength(stack *s)
{
  s->push(pop<pair>(s).length());
}

void pairAngle(stack *s)
{
  s->push(pop<pair>(s).angle());
}

// Return the angle of a pair in degrees in the interval [0,360).
void pairDegrees(stack *s)
{
  double deg=degrees(pop<pair>(s).angle());
  if(deg < 0) deg += 360; 
  s->push(deg);
}

void pairUnit(stack *s)
{
  s->push(unit(pop<pair>(s)));
}

void realDir(stack *s)
{
  s->push(expi(radians(pop<double>(s))));
}

void pairExpi(stack *s)
{
  s->push(expi(pop<double>(s)));
}

void pairConj(stack *s)
{
  s->push(conj(pop<pair>(s)));
}

void pairDot(stack *s)
{
  pair b = pop<pair>(s);
  pair a = pop<pair>(s);
  s->push(a.getx()*b.getx()+a.gety()*b.gety());
}

// Triple operations

void tripleZero(stack *s)
{
  static triple zero;
  s->push(&zero);
}

void realRealRealToTriple(stack *s)
{
  double z = pop<double>(s);
  double y = pop<double>(s);
  double x = pop<double>(s);
  s->push(new triple(x,y,z));
}

void tripleXPart(stack *s)
{
  s->push(pop<triple>(s).getx());
}

void tripleYPart(stack *s)
{
  s->push(pop<triple>(s).gety());
}

void tripleZPart(stack *s)
{
  s->push(pop<triple>(s).getz());
}

void realTripleMult(stack *s)
{
  triple v = pop<triple>(s);
  double x = pop<double>(s);
  s->push(x*v);
}

void tripleRealMult(stack *s)
{
  double x = pop<double>(s);
  triple v = pop<triple>(s);
  s->push(x*v);
}

void tripleRealDivide(stack *s)
{
  double x = pop<double>(s);
  triple v = pop<triple>(s);
  s->push(v/x);
}

void tripleLength(stack *s)
{
  s->push(pop<triple>(s).length());
}

void triplePolar(stack *s)
{
  s->push(pop<triple>(s).polar());
}

void tripleAzimuth(stack *s)
{
  s->push(pop<triple>(s).azimuth());
}

void tripleCoLatitude(stack *s)
{
  s->push(degrees(pop<triple>(s).polar()));
}

void tripleLatitude(stack *s)
{
  s->push(90.0-degrees(pop<triple>(s).polar()));
}

void tripleLongitude(stack *s)
{
  double deg=degrees(pop<triple>(s).azimuth());
  if(deg < 0) deg += 360; 
  s->push(deg);
}

void tripleUnit(stack *s)
{
  s->push(unit(pop<triple>(s)));
}

void tripleDot(stack *s)
{
  triple b = pop<triple>(s);
  triple a = pop<triple>(s);
  s->push(a.getx()*b.getx()+a.gety()*b.gety()+a.getz()*b.getz());
}

void tripleCross(stack *s)
{
  triple b = pop<triple>(s);
  triple a = pop<triple>(s);
  triple c=triple(a.gety()*b.getz()-a.getz()*b.gety(),
		  a.getz()*b.getx()-a.getx()*b.getz(),
		  a.getx()*b.gety()-b.getx()*a.gety());
  s->push(c);
}

void intersectcubics(stack *s)
{
  double fuzz=pop<double>(s);
  
  array *post2=pop<array*>(s);
  array *point2=pop<array*>(s);
  array *pre2=pop<array*>(s);
  
  array *post1=pop<array*>(s);
  array *point1=pop<array*>(s);
  array *pre1=pop<array*>(s);
  
  size_t size1=pre1->size();
  size_t size2=pre2->size();
      
  if(point1->size() != size1 || post1->size() != size1 ||
     point2->size() != size2 || post2->size() != size2)
    error("Mismatched array lengths");
  
  int single1=(size1 == 1);
  int single2=(size2 == 1);
  
  size_t Size1=size1+single1;
  size_t Size2=size2+single2;
  
  node *n1=new node[Size1];
  node *n2=new node[Size2];
      
  for(size_t i=0; i < size1; ++i)
    n1[i]=node(read<triple>(pre1,i),read<triple>(point1,i),
	       read<triple>(post1,i));

  for(size_t i=0; i < size2; ++i)
    n2[i]=node(read<triple>(pre2,i),read<triple>(point2,i),
	       read<triple>(post2,i));

  if(single1) n1[1]=n1[0];
  if(single2) n2[1]=n2[0];
  
  s->push(intersect((int) Size1-1,(int) Size2-1,n1,n2,fuzz));
}
  
// Transforms
  
void transformIdentity(stack *s)
{
  s->push(new transform(identity()));
}

void transformInverse(stack *s)
{
  transform *t = pop<transform*>(s);
  s->push(new transform(inverse(*t)));
}

void transformShift(stack *s)
{
  pair z = pop<pair>(s);
  s->push(new transform(shift(z)));
}

void transformXscale(stack *s)
{
  double x = pop<double>(s);
  s->push(new transform(xscale(x)));
}

void transformYscale(stack *s)
{
  double x = pop<double>(s);
  s->push(new transform(yscale(x)));
}

void transformScale(stack *s)
{
  double x = pop<double>(s);
  s->push(new transform(scale(x)));
}

void transformSlant(stack *s)
{
  double x = pop<double>(s);
  s->push(new transform(slant(x)));
}

void transformRotate(stack *s)
{
  pair z = pop<pair>(s);
  double x = pop<double>(s);
  s->push(new transform(rotatearound(z,radians(x))));
}

void transformReflect(stack *s)
{
  pair w = pop<pair>(s);
  pair z = pop<pair>(s);
  s->push(new transform(reflectabout(z,w)));
}

void transformTransformMult(stack *s)
{
  transform *t2 = pop<transform*>(s);
  transform *t1 = pop<transform*>(s);
  s->push(new transform(*t1 * *t2));
}

void transformPairMult(stack *s)
{
  pair z = pop<pair>(s);
  transform *t = pop<transform*>(s);
  s->push((*t)*z);
}

void transformPathMult(stack *s)
{
  path p = pop<path>(s);
  transform *t = pop<transform*>(s);
  s->push(transformed(*t,p));
}

void transformPenMult(stack *s)
{
  pen *p = pop<pen*>(s);
  transform *t = pop<transform*>(s);
  s->push(new pen(transformed(t,*p)));
}

void transformFrameMult(stack *s)
{
  picture *p = pop<picture*>(s);
  transform *t = pop<transform*>(s);
  s->push(transformed(*t,p));
}

void transformPow(stack *s)
{
  int n = pop<int>(s);
  transform *t = pop<transform*>(s);
  transform *T=new transform(identity());
  bool alloc=false;
  if(n < 0) {
    n=-n;
    t=new transform(inverse(*t));
    alloc=true;
  }
  for(int i=0; i < n; i++) (*T)=(*T) * (*t);
  s->push(T);
  if(alloc) delete t;
}

void transformXPart(stack *s)
{
  s->push(pop<transform>(s).getx());
}

void transformYPart(stack *s)
{
  s->push(pop<transform>(s).gety());
}

void transformXXPart(stack *s)
{
  s->push(pop<transform>(s).getxx());
}

void transformXYPart(stack *s)
{
  s->push(pop<transform>(s).getxy());
}
  
void transformYXPart(stack *s)
{
  s->push(pop<transform>(s).getyx());
}
  
void transformYYPart(stack *s)
{
  s->push(pop<transform>(s).getyy());
}
  
void real6ToTransform(stack *s)
{
  double yy = pop<double>(s);
  double yx = pop<double>(s);
  double xy = pop<double>(s);
  double xx = pop<double>(s);
  double y = pop<double>(s);
  double x = pop<double>(s);
  s->push(new transform(x,y,xx,xy,yx,yy));
}

void boolTransformEq(stack *s)
{
  transform *b = pop<transform*>(s);
  transform *a = pop<transform*>(s);
  s->push((*a) == (*b));
}

void boolTransformNeq(stack *s)
{
  transform *b = pop<transform*>(s);
  transform *a = pop<transform*>(s);
  s->push((*a) != (*b));
}

static string emptystring;
void emptyString(stack *s)
{
  s->push(&emptystring);
}

// returns a string constructed by translating all occurrences of the string
// from in an array of string pairs {from,to} to the string to in string s.
void stringReplace(stack *s)
{
  array *translate=pop<array*>(s);
  string *S=pop<string*>(s);
  checkArray(translate);
  size_t size=translate->size();
  for(size_t i=0; i < size; i++) {
    array *a=read<array*>(translate,i);
    checkArray(a);
  }
  const char *p=S->c_str();
  ostringstream buf;
  while(*p) {
    for(size_t i=0; i < size;) {
      array *a=read<array*>(translate,i);
      string* from=read<string*>(a,0);
      size_t len=from->length();
      if(strncmp(p,from->c_str(),len) != 0) {i++; continue;}
      buf << read<string>(a,1);
      p += len;
      if(*p == 0) {s->push<string>(buf.str()); return;}
      i=0;
    }
    buf << *(p++);
  }
  s->push<string>(buf.str());
}

void stringFormatInt(stack *s) 
{
  int x=pop<int>(s);
  string *format=pop<string*>(s);
  int size=snprintf(NULL,0,format->c_str(),x)+1;
  if(size < 1) size=255; // Workaround for non-C99 compliant systems.
  char *buf=new char[size];
  snprintf(buf,size,format->c_str(),x);
  s->push<string>(buf);
  delete [] buf;
}

void stringFormatReal(stack *s) 
{
  ostringstream out;
  
  double x=pop<double>(s);
  string *format=pop<string*>(s);
  
  const char *phantom="\\phantom{+}";
  const char *p0=format->c_str();
  
  const char *p=p0;
  const char *start=NULL;
  while (*p != 0) {
    if(*p == '%') {
      p++;
      if(*p != '%') {start=p-1; break;}
    }
    out << *(p++);
  }
  
  if(!start) {s->push<string>(out.str()); return;}
  
  // Allow at most 1 argument  
  while (*p != 0) {
    if(*p == '*' || *p == '$') {s->push<string>(out.str()); return;}
    if(isupper(*p) || islower(*p)) {p++; break;}
    p++;
  }
  
  const char *tail=p;
  string f=format->substr(start-p0,tail-start);
  int size=snprintf(NULL,0,f.c_str(),x)+1;
  if(size < 1) size=255; // Workaround for non-C99 compliant systems.
  char *buf=new char[size];
  snprintf(buf,size,f.c_str(),x);

  bool trailingzero=f.find("#") < string::npos;
  bool plus=f.find("+") < string::npos;
  bool space=f.find(" ") < string::npos;
  
  char *q=buf; // beginning of formatted number

  if(*q == ' ') {
    out << phantom;
    q++;
  }
  
  // Remove any spurious sign
  if(*q == '-' || *q == '+') {
    p=q+1;
    bool zero=true;
    while(*p != 0) {
      if(!isdigit(*p) && *p != '.') break;
      if(isdigit(*p) && *p != '0') {zero=false; break;}
      p++;
    }
    if(zero) {
      q++;
      if(plus || space) out << phantom;
    }
  }
  
  const char *r=p=q;
  bool dp=false;
  while(*r != 0 && (isdigit(*r) || *r == '.' || *r == '+' || *r == '-')) {
    if(*r == '.') dp=true;
    r++;
  }
  if(dp) { // Remove trailing zeros and/or decimal point
    r--;
    unsigned int n=0;
    while(r > q && *r == '0') {r--; n++;}
    if(*r == '.') {r--; n++;}
    while(q <= r) out << *(q++);
    if(!trailingzero) q += n;
  }
  
  bool zero=(r == p && *r == '0') && !trailingzero;
  
  // Translate "E+/E-/e+/e-" exponential notation to TeX
  while(*q != 0) {
    if((*q == 'E' || *q == 'e') && (*(q+1) == '+' || *(q+1) == '-')) {
      if(!zero) out << "\\!\\times\\!10^{";
      bool plus=(*(q+1) == '+');
      q++;
      if(plus) q++;
      if(*q == '-') out << *(q++);
      while(*q == '0' && (zero || isdigit(*(q+1)))) q++;
      while(isdigit(*q)) out << *(q++);
      if(!zero) {
	if(plus) out << phantom;
	out << "}";
      }
      break;
    }
    out << *(q++);
  }
  
  while(*tail != 0) 
    out << *(tail++);
  
  delete [] buf;
  s->push<string>(out.str());
}

void stringTime(stack *s)
{
  static const size_t n=256;
  static char Time[n]="";
#ifdef HAVE_STRFTIME
  string *format = pop<string*>(s);
  const time_t bintime=time(NULL);
  strftime(Time,n,format->c_str(),localtime(&bintime));
#else
  pop<string*>(s);
#endif  
  s->push<string>(Time);
}

// Path operations.

void nullPath(stack *s)
{
  static path *nullpath=new path();
  s->push(nullpath);
}

void pathSize(stack *s)
{
  path p = pop<path>(s);
  s->push(p.size());
}

void pathConcat(stack *s)
{
  path y = pop<path>(s);
  path x = pop<path>(s);
  s->push(camp::concat(x, y));
}

void pathMin(stack *s)
{
  path p = pop<path>(s);
  s->push(p.bounds().Min());
}

void pathMax(stack *s)
{
  path p = pop<path>(s);
  s->push(p.bounds().Max());
}
  
// Guide operations.

void nullGuide(stack *s)
{
  s->push<guide *>(new pathguide(path()));
}

void dotsGuide(stack *s)
{
  array *a=pop<array*>(s);

  guidevector v;
  for (size_t i=0; i < a->size(); ++i)
    v.push_back(a->read<guide*>(i));

  s->push((guide *) new multiguide(v));
}

void dashesGuide(stack *s)
{
  static camp::curlSpec curly;
  static specguide curlout(&curly, camp::OUT);
  static specguide curlin(&curly, camp::IN);

  array *a=pop<array*>(s);
  size_t n=a->size();

  // a--b is equivalent to a{curl 1}..{curl 1}b
  guidevector v;
  if (n > 0)
    v.push_back(a->read<guide*>(0));

  if (n==1) {
    v.push_back(&curlout);
    v.push_back(&curlin);
  }
  else
    for (size_t i=1; i<n; ++i) {
      v.push_back(&curlout);
      v.push_back(&curlin);
      v.push_back(a->read<guide*>(i));
    }

  s->push((guide *) new multiguide(v));
}

void cycleGuide(stack *s)
{
  s->push((guide *) new cycletokguide());
}
      

void dirSpec(stack *s)
{
  camp::side d=(camp::side) pop<int>(s);
  camp::dirSpec *sp=new camp::dirSpec(angle(pop<pair>(s)));

  s->push((guide *) new specguide(sp, d));
}

void curlSpec(stack *s)
{
  camp::side d=(camp::side) pop<int>(s);
  camp::curlSpec *sp=new camp::curlSpec(pop<double>(s));

  s->push((guide *) new specguide(sp, d));
}

void realRealTension(stack *s)
{
  bool atleast=pop<bool>(s);
  tension  tin(pop<double>(s), atleast),
          tout(pop<double>(s), atleast);

  s->push((guide *) new tensionguide(tout, tin));
}

void pairPairControls(stack *s)
{
  pair  zin=pop<pair>(s),
       zout=pop<pair>(s);

  s->push((guide *) new controlguide(zout, zin));
}

void relativeDistance(stack *s)
{
  bool atleast=pop<bool>(s);
  tension t(pop<double>(s), atleast);
  double phi=pop<double>(s);
  double theta=pop<double>(s);
  s->push(camp::velocity(theta,phi,t));
}

// Pen operations.

void newPen(stack *s)
{
  s->push(new pen());
}

// Reset the meaning of pen default attributes.
void resetdefaultPen(stack *)
{
  defaultpen=camp::pen::startupdefaultpen();
}

void setDefaultPen(stack *s)
{
  pen *p=pop<pen*>(s);
  defaultpen=pen(resolvepen,*p);
}

void invisiblePen(stack *s)
{
  s->push(new pen(invisiblepen));
}

void grayPen(stack *s)
{
  pen p=*(pop<pen*>(s));
  if(p.rgb()) p.rgbtogrey();
  else if (p.cmyk()) p.cmyktogrey();
  s->push(p);
}

void rgbPen(stack *s)
{
  pen p=*(pop<pen*>(s));
  if(p.grayscale()) p.greytorgb();
  else if (p.cmyk()) p.cmyktorgb();
  s->push(p);
}

void rgb(stack *s)
{
  double b = pop<double>(s);
  double g = pop<double>(s);
  double r = pop<double>(s);
  s->push(new pen(r,g,b));
}

void cmyk(stack *s)
{
  double k = pop<double>(s);
  double y = pop<double>(s);
  double m = pop<double>(s);
  double c = pop<double>(s);
  s->push(new pen(c,m,y,k));  
}

void gray(stack *s)
{
  s->push(new pen(pop<double>(s)));  
}

void colors(stack *s)
{  
  pen *p=pop<pen*>(s);
  int n=ColorComponents[p->colorspace()];
  array *a=new array(n);
  
  switch(n) {
  case 0:
    break;
  case 1: 
    (*a)[0]=p->gray(); 
    break;
  case 3:
    (*a)[0]=p->red(); 
    (*a)[1]=p->green(); 
    (*a)[2]=p->blue(); 
    break;
  case 4:
    (*a)[0]=p->cyan();
    (*a)[1]=p->magenta(); 
    (*a)[2]=p->yellow(); 
    (*a)[3]=p->black();
    break;
  default:
    break;
  }
  s->push(a);
}

void pattern(stack *s)
{
  s->push(new pen(setpattern,pop<string>(s)));  
}

void penPattern(stack *s)
{
  pen *p=pop<pen*>(s);
  s->push(p->fillpattern());  
}

void fillRule(stack *s)
{
  int n = pop<int>(s);
  s->push(new pen(n >= 0 && n < nFill ? (FillRule) n : DEFFILL));
}

void penFillRule(stack *s)
{
  pen *p=pop<pen*>(s);
  s->push(p->Fillrule());  
}

void penBaseLine(stack *s)
{
  pen *p=pop<pen*>(s);
  s->push(p->Baseline());
}

void lineType(stack *s)
{
  bool scale = pop<bool>(s);
  string *t = pop<string*>(s);
  s->push(new pen(LineType(*t,scale))); 
}

void penLineType(stack *s)
{
  pen *p=pop<pen*>(s);
  s->push(p->stroke());  
}

void lineCap(stack *s)
{
  int n = pop<int>(s);
  s->push(new pen(setlinecap,n >= 0 && n < nCap ? n : DEFCAP));
}

void penLineCap(stack *s)
{
  pen *p=pop<pen*>(s);
  s->push(p->cap());  
}

void lineJoin(stack *s)
{
  int n = pop<int>(s);
  s->push(new pen(setlinejoin,n >= 0 && n < nJoin ? n : DEFJOIN));
}

void penLineJoin(stack *s)
{
  pen *p=pop<pen*>(s);
  s->push(p->join());  
}

void lineWidth(stack *s)
{
  double x = pop<double>(s);
  s->push(new pen(setlinewidth,x >= 0.0 ? x : DEFWIDTH));
}

void penLineWidth(stack *s)
{
  pen *p=pop<pen*>(s);
  s->push(p->width());  
}

void font(stack *s)
{
  string *t = pop<string*>(s);
  s->push(new pen(setfont,*t));
}

void penFont(stack *s)
{
  pen *p=pop<pen*>(s);
  s->push(new string(p->Font()));  
}

void fontSize(stack *s)
{
  double skip = pop<double>(s);
  double size = pop<double>(s);
  s->push(new pen(setfontsize,
		  size > 0.0 ? size : 0.0,
	          skip > 0.0 ? skip : 0.0));
}

void penFontSize(stack *s)
{
  pen *p=pop<pen*>(s);
  s->push(p->size());  
}

void penLineSkip(stack *s)
{
  pen *p=pop<pen*>(s);
  s->push(p->Lineskip());  
}

void overWrite(stack *s)
{
  int n = pop<int>(s);
  s->push(new pen(setoverwrite,n >= 0 && n < nOverwrite ? (overwrite_t) n 
		  : DEFWRITE));
}

void penOverWrite(stack *s)
{
  pen *p=pop<pen*>(s);
  s->push(p->Overwrite());  
}

void boolPenEq(stack *s)
{
  pen *b = pop<pen*>(s);
  pen *a = pop<pen*>(s);
  s->push((*a) == (*b));
}

void boolPenNeq(stack *s)
{
  pen *b = pop<pen*>(s);
  pen *a = pop<pen*>(s);
  s->push((*a) != (*b));
}

void penPenPlus(stack *s)
{
  pen *b = pop<pen*>(s);
  pen *a = pop<pen*>(s);
  s->push(new pen((*a) + (*b)));
}

void realPenTimes(stack *s)
{
  pen *b = pop<pen*>(s);
  double a = pop<double>(s);
  s->push(new pen(a * (*b)));
}

void penRealTimes(stack *s)
{
  double b = pop<double>(s);
  pen *a = pop<pen*>(s);
  s->push(new pen(b * (*a)));
}

void penMax(stack *s)
{
  pen *p = pop<pen*>(s);
  s->push(p->bounds().Max());
}

void penMin(stack *s)
{
  pen *p = pop<pen*>(s);
  s->push(p->bounds().Min());
}

// Picture operations.

void newFrame(stack *s)
{
  s->push(new picture());
}

void boolNullFrame(stack *s)
{
  picture *b = pop<picture*>(s);
  s->push(b->null());
}

void frameMax(stack *s)
{
  picture *pic = pop<picture*>(s);
  s->push(pic->bounds().Max());
}

void frameMin(stack *s)
{
  picture *pic = pop<picture*>(s);
  s->push(pic->bounds().Min());
}

void fill(stack *s)
{
  pen *n = pop<pen*>(s);
  array *p=copyArray(s);
  picture *pic = pop<picture*>(s);
  checkArray(p);
  pic->append(new drawFill(p,*n));
}
 
void latticeShade(stack *s)
{
  array *pens=copyArray(s);
  pen *n = pop<pen*>(s);
  array *p=copyArray(s);
  picture *pic = pop<picture*>(s);
  checkArray(p);
  checkArray(pens);
  pic->append(new drawLatticeShade(p,*n,pens));
}
 
void axialShade(stack *s)
{
  pair b = pop<pair>(s);
  pen *penb = pop<pen*>(s);
  pair a = pop<pair>(s);
  pen *pena = pop<pen*>(s);
  array *p=copyArray(s);
  picture *pic = pop<picture*>(s);
  checkArray(p);
  pic->append(new drawAxialShade(p,*pena,a,*penb,b));
}
 
void radialShade(stack *s)
{
  double rb = pop<double>(s);
  pair b = pop<pair>(s);
  pen *penb = pop<pen*>(s);
  double ra = pop<double>(s);
  pair a = pop<pair>(s);
  pen *pena = pop<pen*>(s);
  array *p=copyArray(s);
  picture *pic = pop<picture*>(s);
  checkArray(p);
  pic->append(new drawRadialShade(p,*pena,a,ra,*penb,b,rb));
}
 
void gouraudShade(stack *s)
{
  array *edges=copyArray(s);
  array *vertices=copyArray(s);
  array *pens=copyArray(s);
  pen *n = pop<pen*>(s);
  array *p=copyArray(s);
  picture *pic = pop<picture*>(s);
  checkArray(p);
  checkArrays(pens,vertices);
  checkArrays(vertices,edges);
  pic->append(new drawGouraudShade(p,*n,pens,vertices,edges));
}
 
// Clip a picture to a superpath using the given fill rule.
// Subsequent additions to the picture will not be affected by the clipping.
void clip(stack *s)
{
  pen *n = pop<pen*>(s);
  array *p=copyArray(s);
  picture *pic = pop<picture*>(s);
  pic->prepend(new drawClipBegin(p,*n));
  pic->append(new drawClipEnd());
}
  
void beginClip(stack *s)
{
  pen *n = pop<pen*>(s);
  array *p=copyArray(s);
  picture *pic = pop<picture*>(s);
  pic->append(new drawClipBegin(p,*n,false));
}

void postscript(stack *s)
{
  string *t = pop<string*>(s);
  picture *pic = pop<picture*>(s);
  drawVerbatim *d = new drawVerbatim(PostScript,*t);
  pic->append(d);
}
  
void tex(stack *s)
{
  string *t = pop<string*>(s);
  picture *pic = pop<picture*>(s);
  drawVerbatim *d = new drawVerbatim(TeX,*t);
  pic->append(d);
}
  
void texPreamble(stack *s)
{
  string t = pop<string>(s)+"\n";
  camp::TeXpipepreamble.push_back(t);
  camp::TeXpreamble.push_back(t);
}
  
void layer(stack *s)
{
  picture *pic = pop<picture*>(s);
  drawLayer *d = new drawLayer();
  pic->append(d);
}
  
void image(stack *s)
{
  pair final = pop<pair>(s);
  pair initial = pop<pair>(s);
  array *p=copyArray(s);
  array *a=copyArray2(s);
  picture *pic = pop<picture*>(s);
  drawImage *d = new drawImage(a,p,matrix(initial,final));
  pic->append(d);
}
  
void shipout(stack *s)
{
  array *GUIdelete=pop<array*>(s);
  array *GUItransform=pop<array*>(s);
  bool quiet = pop<bool>(s);
  bool wait = pop<bool>(s);
  string *format = pop<string*>(s);
  const picture *preamble = pop<picture*>(s);
  picture *pic = pop<picture*>(s);
  string prefix = pop<string>(s);
  if(prefix.empty()) prefix=outname;
  
  size_t size=checkArrays(GUItransform,GUIdelete);
  
  if(settings::deconstruct || size) {
    picture *result=new picture;
    unsigned level=0;
    unsigned i=0;
    nodelist::iterator p;
    for(p = pic->nodes.begin(); p != pic->nodes.end(); ++p) {
      bool Delete;
      transform t;
      if(i < size) {
	t=*(read<transform*>(GUItransform,i));
	Delete=read<bool>(GUIdelete,i);
      } else {
	t=identity();
	Delete=false;
      }
      picture *group=new picture;
// Ignore unclosed begingroups but not spurious endgroups.
      const char *nobegin="endgroup without matching begingroup";
      assert(*p);
      if((*p)->endgroup()) error(nobegin);
      if((*p)->begingroup()) {
	++level;
	while(p != pic->nodes.end() && level) {
	  drawElement *e=t.isIdentity() ? *p : (*p)->transformed(t);
	  group->append(e);
	  ++p;
	  if(p == pic->nodes.end()) break;
	  assert(*p);
	  if((*p)->begingroup()) ++level;
	  if((*p)->endgroup()) if(level) --level;
	  else error(nobegin);
	}
      }
      if(p == pic->nodes.end()) break;
      assert(*p);
      drawElement *e=t.isIdentity() ? *p : (*p)->transformed(t);
      group->append(e);
      if(!group->empty()) {
	if(settings::deconstruct) {
	  ostringstream buf;
	  buf << prefix << "_" << i;
	  group->shipout(*preamble,buf.str(),"tgif",false,true,Delete);
	}
	++i;
      }
      if(size && !Delete) result->add(*group);
    }
    if(size) pic=result;
  }

  pic->shipout(*preamble,prefix,*format,wait,quiet);
}

// System commands

static callable *atExitFunction=NULL;

void cleanup()
{
  defaultpen=camp::pen::startupdefaultpen();
  if(!interact::interactive) settings::scrollLines=0;
  
  if(TeXinitialized && TeXcontaminated) {
    camp::TeXpipepreamble.clear();
    camp::TeXpreamble.clear();
    camp::tex.pipeclose();
    TeXinitialized=camp::TeXcontaminated=false;
  }
}

void exitFunction(stack *s)
{
  if(atExitFunction) {
    atExitFunction->call(s);
    atExitFunction=NULL;
  }
  cleanup();
}
  
void atExit(stack *s)
{
  atExitFunction=pop<callable*>(s);
}
  
// Merge output files  
void merge(stack *s)
{
  int ret;
  bool keep = pop<bool>(s);
  string *format = pop<string*>(s);
  string *args = pop<string*>(s);
  
  if(settings::suppressStandard) {s->push(0); return;}
  
  if(!checkFormatString(*format)) return;
  
  ostringstream cmd,remove;
  cmd << Convert << " "+*args;
  
  for(std::list<std::string>::iterator p=outnameStack->begin();
      p != outnameStack->end(); ++p)
    cmd << " " << *p;
  
  string name=buildname(outname,format->c_str());
  cmd << " " << name;
  ret=System(cmd,false,true,"ASYMPTOTE_CONVERT","convert");
  
  if(ret == 0)
    if(settings::verbose > 0) cout << "Wrote " << name << endl;
  
  if(!keep && !settings::keep)
    for(std::list<std::string>::iterator p=outnameStack->begin();
      p != outnameStack->end(); ++p)
      unlink(p->c_str());
    
  if(ret == 0 && settings::view) {
    ostringstream cmd;
    cmd << Animate << " " << name;
    System(cmd,false,false,"ASYMPTOTE_ANIMATE","your animated GIF viewer");
  }
  
  s->push(ret);
}

void execute(stack *s)
{
  string Outname=outname;
  string *str = pop<string*>(s);
  outname = stripext(*str,suffix);

  trans::genv ge;
  ge.autoloads(outname);

  absyntax::file *tree = parser::parseFile(*str);
  trans::record *m = ge.loadModule(symbol::trans(outname),tree);
  if (!em->errors()) {
    lambda *l = ge.bootupModule(m);
    assert(l);
    vm::run(l);
  }
  outname=Outname;
}

void eval(stack *s)
{
  string *str = pop<string*>(s);
  symbol *id = symbol::trans(*str);
  absyntax::file *tree = parser::parseString(*str);
  
  trans::genv ge;
  ge.autoloads("");
  
  trans::record *m = ge.loadModule(id,tree);
  if (!em->errors()) {
    lambda *l = ge.bootupModule(m);
    assert(l);
    vm::run(l);
  }
}

void changeDirectory(stack *s)
{
  string *d=pop<string*>(s);
  int rc=setPath(d->c_str());
  if(rc != 0) {
    ostringstream buf;
    buf << "Cannot change to directory '" << d << "'";
    error(buf.str().c_str());
  }
  char *p=getPath();
  if(p && interact::interactive && !settings::suppressStandard) 
    cout << p << endl;
  s->push<string>(p);
}

void scrollLines(stack *s)
{
  int n=pop<int>(s);
  settings::scrollLines=n;
}

// I/O Operations

void standardOut(stack *s)
{
  file *f=&camp::Stdout;
  s->push(f);
}

void nullFile(stack *s)
{
  file *f=&camp::nullfile;
  s->push(f);
}

void fileOpenIn(stack *s)
{
  string *comment=pop<string*>(s);
  bool check=pop<bool>(s);
  string *filename=pop<string*>(s);
  char c=*comment == "" ? (char) 0 : (*comment)[0];
  file *f=new ifile(*filename,check,c);
  f->open();
  s->push(f);
}

void fileOpenOut(stack *s)
{
  bool append=pop<bool>(s);
  string *filename=pop<string*>(s);
  file *f=new ofile(*filename,append);
  f->open();
  s->push(f);
}

void fileOpenXIn(stack *s)
{
#ifdef HAVE_RPC_RPC_H
  bool check=pop<bool>(s);
  string *filename=pop<string*>(s);
  file *f=new ixfile(*filename,check);
  s->push(f);
#else  
  error("XDR support not enabled");
#endif
}

void fileOpenXOut(stack *s)
{
#ifdef HAVE_RPC_RPC_H
  bool append=pop<bool>(s);
  string *filename=pop<string*>(s);
  file *f=new oxfile(*filename,append);
  s->push(f);
#else  
  error("XDR support not enabled");
#endif
}

void fileEof(stack *s)
{
  file *f = pop<file*>(s);
  s->push(f->eof());
}

void fileEol(stack *s)
{
  file *f = pop<file*>(s);
  s->push(f->eol());
}

void fileError(stack *s)
{
  file *f = pop<file*>(s);
  s->push(f->error());
}

void fileClear(stack *s)
{
  file *f = pop<file*>(s);
  f->clear();
}

void fileClose(stack *s)
{
  file *f = pop<file*>(s);
  f->close();
}

void filePrecision(stack *s) 
{
  int val = pop<int>(s);
  file *f = pop<file*>(s);
  f->precision(val);
}

void fileFlush(stack *s) 
{
   file *f = pop<file*>(s);
   f->flush();
}

void readChar(stack *s)
{
  file *f = pop<file*>(s);
  char c;
  if(f->isOpen()) f->read(c);
  static char str[1];
  str[0]=c;
  s->push<string>(str);
}

// Set file dimensions
void fileDimension1(stack *s) 
{
  int nx = pop<int>(s);
  file *f = pop<file*>(s);
  f->dimension(nx);
  s->push(f);
}

void fileDimension2(stack *s) 
{
  int ny = pop<int>(s);
  int nx = pop<int>(s);
  file *f = pop<file*>(s);
  f->dimension(nx,ny);
  s->push(f);
}

void fileDimension3(stack *s) 
{
  int nz = pop<int>(s);
  int ny = pop<int>(s);
  int nx = pop<int>(s);
  file *f = pop<file*>(s);
  f->dimension(nx,ny,nz);
  s->push(f);
}

// Set file to read comma-separated values
void fileCSVMode(stack *s) 
{
  bool b = pop<bool>(s);
  file *f = pop<file*>(s);
  f->CSVMode(b);
  s->push(f);
}

// Set file to read arrays in line-at-a-time mode
void fileLineMode(stack *s) 
{
  bool b = pop<bool>(s);
  file *f = pop<file*>(s);
  f->LineMode(b);
  s->push(f);
}

// Set file to read/write single-precision XDR values.
void fileSingleMode(stack *s) 
{
  bool b = pop<bool>(s);
  file *f = pop<file*>(s);
  f->SingleMode(b);
  s->push(f);
}

// Set file to read an array1 (1 int size followed by a 1-d array)
void fileArray1(stack *s) 
{
  file *f = pop<file*>(s);
  f->dimension(-2);
  s->push(f);
}

// Set file to read an array2 (2 int sizes followed by a 2-d array)
void fileArray2(stack *s) 
{
  file *f = pop<file*>(s);
  f->dimension(-2,-2);
  s->push(f);
}

// Set file to read an array3 (3 int sizes followed by a 3-d array)
void fileArray3(stack *s) 
{
  file *f = pop<file*>(s);
  f->dimension(-2,-2,-2);
  s->push(f);
}

void boolFileEq(stack *s)
{
  file* b = pop<file*>(s);
  file* a = pop<file*>(s);
  s->push(a == b);
}

void boolFileNeq(stack *s)
{
  file* b = pop<file*>(s);
  file* a = pop<file*>(s);
  s->push(a != b);
}

// Utilities

array *copyArray(stack *s)
{
  array *a=pop<array*>(s);
  checkArray(a);
  size_t size=a->size();
  array *c=new array(size);
  for(size_t i=0; i < size; i++) 
    (*c)[i]=(*a)[i];
  return c;
}

array *copyArray2(stack *s)
{
  array *a=pop<array*>(s);
  checkArray(a);
  size_t size=a->size();
  array *c=new array(size);
  for(size_t i=0; i < size; i++) {
    array *ai=read<array*>(a,i);
    checkArray(ai);
    size_t aisize=ai->size();
    array *ci=new array(aisize);
    (*c)[i]=ci;
    for(size_t j=0; j < aisize; j++) 
      (*ci)[j]=(*ai)[j];
  }
  return c;
}


} // namespace run
