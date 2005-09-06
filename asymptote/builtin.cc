/*****
 * builtin.cc
 * Tom Prince 2004/08/25
 *
 * Initialize builtins.
 *****/

#include <cmath>

#ifdef HAVE_CONFIG_H
#include "config.h"
#endif

#include "builtin.h"
#include "entry.h"
#include "import.h"
#include "runtime.h"
#include "types.h"
#include "pair.h"
#include "triple.h"

#include "castop.h"
#include "mathop.h"
#include "arrayop.h"
#include "pow.h"
#include "genrun.h"
#include "vm.h"

using namespace types;
using namespace camp;

namespace trans {
using camp::pair;
using camp::triple;
using camp::transform;
using vm::bltin;
using run::divide;
using mem::string;

// The base environments for built-in types and functions
void base_tenv(tenv &ret)
{
  ret.enter(symbol::trans("void"), primVoid());
  ret.enter(symbol::trans("bool"), primBoolean());
  ret.enter(symbol::trans("int"), primInt());
  ret.enter(symbol::trans("real"), primReal());
  ret.enter(symbol::trans("string"), primString());
  
  ret.enter(symbol::trans("pair"), primPair());
  ret.enter(symbol::trans("triple"), primTriple());
  ret.enter(symbol::trans("transform"), primTransform());
  ret.enter(symbol::trans("guide"), primGuide());
  ret.enter(symbol::trans("path"), primPath());
  ret.enter(symbol::trans("pen"), primPen());
  ret.enter(symbol::trans("frame"), primPicture());

  ret.enter(symbol::trans("file"), primFile());
}

// Macro to make a function.
inline void addFunc(venv &ve, access *a, ty *result, symbol *name,
		    ty *t1 = 0, ty *t2 = 0, ty *t3 = 0, ty* t4 = 0,
		    ty *t5 = 0, ty *t6 = 0, ty *t7 = 0, ty *t8 = 0)
{
  function *fun = new function(result);

  if (t1) fun->add(t1);
  if (t2) fun->add(t2);
  if (t3) fun->add(t3);
  if (t4) fun->add(t4);
  if (t5) fun->add(t5);
  if (t6) fun->add(t6);
  if (t7) fun->add(t7);
  if (t8) fun->add(t8);

  varEntry *ent = new varEntry(fun, a);

  ve.enter(name, ent);
}

inline void addFunc(venv &ve, access *a, ty *result, const char *name, 
		    ty *t1 = 0, ty *t2 = 0, ty *t3 = 0, ty* t4 = 0,
		    ty *t5 = 0, ty *t6 = 0, ty *t7 = 0, ty *t8 = 0)
{
  addFunc(ve, a, result, symbol::trans(name), t1, t2, t3, t4, t5, t6, t7, t8);
}

void addFunc(venv &ve, bltin f, ty *result, const char *name, 
             ty *t1, ty *t2, ty *t3, ty* t4,
             ty *t5, ty *t6, ty *t7, ty *t8)
{
  access *a = new bltinAccess(f);
  addFunc(ve, a, result, name, t1, t2, t3, t4, t5, t6, t7, t8);
}
  
inline void addRestFunc(venv &ve, access *a, ty *result, symbol *name,
		        ty *trest) {
  function *fun = new function(result);

  if (trest) fun->addRest(trest);

  varEntry *ent = new varEntry(fun, a);

  ve.enter(name, ent);
}

inline void addRestFunc(venv &ve, bltin f, ty *result, const char *name,
		        ty *trest) {
  access *a = new bltinAccess(f);
  addRestFunc(ve, a, result, symbol::trans(name), trest);
}

void addRealFunc0(venv &ve, bltin fcn, const char *name)
{
  addFunc(ve, fcn, primReal(), name);
}

template<double (*fcn)(double)>
void addRealFunc(venv &ve, const char* name)
{
  addFunc(ve, run::realReal<fcn>, primReal(), name, primReal());
  addFunc(ve, run::realArrayFunc<fcn>, realArray(), name, realArray());
}

#define addRealFunc(fcn) addRealFunc<fcn>(ve, #fcn);

void addRealFunc2(venv &ve, bltin fcn, const char *name)
{
  addFunc(ve, fcn, primReal(), name, primReal(), primReal());
}

void addInitializer(venv &ve, ty *t, access *a)
{
  addFunc(ve, a, t, symbol::initsym);
}

void addInitializer(venv &ve, ty *t, bltin f)
{
  access *a = new bltinAccess(f);
  addInitializer(ve, t, a);
}

// Specifies that source may be cast to target, but only if an explicit
// cast expression is used.
void addExplicitCast(venv &ve, ty *target, ty *source, access *a) {
  addFunc(ve, a, target, symbol::ecastsym, source);
}

// Specifies that source may be implicitly cast to target by the
// function or instruction stores at a.
void addCast(venv &ve, ty *target, ty *source, access *a) {
  //addExplicitCast(target,source,a);
  addFunc(ve, a, target, symbol::castsym, source);
}

void addExplicitCast(venv &ve, ty *target, ty *source, bltin f) {
  addExplicitCast(ve, target, source, new bltinAccess(f));
}

void addCast(venv &ve, ty *target, ty *source, bltin f) {
  addCast(ve, target, source, new bltinAccess(f));
}

// The identity access, i.e. no instructions are encoded for a cast or
// operation, and no functions are called.
identAccess id;

void addInitializers(venv &ve)
{
  addInitializer(ve, primBoolean(), run::boolFalse);
  addInitializer(ve, primInt(), run::intZero);
  addInitializer(ve, primReal(), run::realZero);

  addInitializer(ve, primString(), run::emptyString);
  addInitializer(ve, primPair(), run::pairZero);
  addInitializer(ve, primTriple(), run::tripleZero);
  addInitializer(ve, primTransform(), run::transformIdentity);
  addInitializer(ve, primGuide(), run::nullGuide);
  addInitializer(ve, primPath(), run::nullPath);
  addInitializer(ve, primPen(), run::newPen);
  addInitializer(ve, primPicture(), run::newFrame);
  addInitializer(ve, primFile(), run::newFile);
}

void addCasts(venv &ve)
{
  addExplicitCast(ve, primString(), primInt(), run::stringCast<int>);
  addExplicitCast(ve, primString(), primReal(), run::stringCast<double>);
  addExplicitCast(ve, primString(), primPair(), run::stringCast<pair>);
  addExplicitCast(ve, primString(), primTriple(), run::stringCast<triple>);
  addExplicitCast(ve, primInt(), primString(), run::castString<int>);
  addExplicitCast(ve, primReal(), primString(), run::castString<double>);
  addExplicitCast(ve, primPair(), primString(), run::castString<pair>);
  addExplicitCast(ve, primTriple(), primString(), run::castString<triple>);

  addExplicitCast(ve, primInt(), primReal(), run::cast<double,int>);

  addCast(ve, primReal(), primInt(), run::cast<int,double>);
  addCast(ve, primPair(), primInt(), run::cast<int,pair>);
  addCast(ve, primPair(), primReal(), run::cast<double,pair>);
  
  addCast(ve, primPath(), primPair(), run::cast<pair,path>);
  addCast(ve, primGuide(), primPair(), run::pairToGuide);
  addCast(ve, primGuide(), primPath(), run::pathToGuide);
  addCast(ve, primPath(), primGuide(), run::guideToPath);

  addCast(ve, primPen(), primReal(), run::lineWidth);
  
  addCast(ve, primBoolean(), primFile(), run::read<bool>);
  addCast(ve, primInt(), primFile(), run::read<int>);
  addCast(ve, primReal(), primFile(), run::read<double>);
  addCast(ve, primPair(), primFile(), run::read<pair>);
  addCast(ve, primTriple(), primFile(), run::read<triple>);
  addCast(ve, primString(), primFile(), run::read<string>);

  // Vectorized casts.
  addExplicitCast(ve, intArray(), realArray(), run::arrayToArray<double,int>);
  
  addCast(ve, realArray(), intArray(), run::arrayToArray<int,double>);
  addCast(ve, pairArray(), intArray(), run::arrayToArray<int,pair>);
  addCast(ve, pairArray(), realArray(), run::arrayToArray<double,pair>);
  
  addCast(ve, boolArray(), primFile(), run::readArray<bool>);
  addCast(ve, intArray(), primFile(), run::readArray<int>);
  addCast(ve, realArray(), primFile(), run::readArray<double>);
  addCast(ve, pairArray(), primFile(), run::readArray<pair>);
  addCast(ve, tripleArray(), primFile(), run::readArray<triple>);
  addCast(ve, stringArray(), primFile(), run::readArray<string>);
  
  addCast(ve, boolArray2(), primFile(), run::readArray<bool>);
  addCast(ve, intArray2(), primFile(), run::readArray<int>);
  addCast(ve, realArray2(), primFile(), run::readArray<double>);
  addCast(ve, pairArray2(), primFile(), run::readArray<pair>);
  addCast(ve, tripleArray2(), primFile(), run::readArray<triple>);
  addCast(ve, stringArray2(), primFile(), run::readArray<string>);
  
  addCast(ve, boolArray3(), primFile(), run::readArray<bool>);
  addCast(ve, intArray3(), primFile(), run::readArray<int>);
  addCast(ve, realArray3(), primFile(), run::readArray<double>);
  addCast(ve, pairArray3(), primFile(), run::readArray<pair>);
  addCast(ve, tripleArray3(), primFile(), run::readArray<triple>);
  addCast(ve, stringArray3(), primFile(), run::readArray<string>);
}

void addGuideOperators(venv &ve)
{
  // The guide operators .. and -- take an array of guides, and turn them into a
  // single guide.
  addRestFunc(ve, run::dotsGuide, primGuide(), "..", guideArray());
  addRestFunc(ve, run::dashesGuide, primGuide(), "--", guideArray());

  addFunc(ve, run::cycleGuide, primGuide(), "operator cycle");
  addFunc(ve, run::dirSpec, primGuide(), "operator spec",
          primPair(), primInt());
  addFunc(ve, run::curlSpec, primGuide(), "operator curl",
          primReal(), primInt());
  addFunc(ve, run::realRealTension, primGuide(), "operator tension",
          primReal(), primReal(), primBoolean());
  addFunc(ve, run::pairPairControls, primGuide(), "operator controls",
          primPair(), primPair());
  addFunc(ve, run::relativeDistance, primReal(), "relativedistance",
          primReal(), primReal(), primReal(), primBoolean());
}

/* To avoid typing the same type three times. */
void addSimpleOperator(venv &ve, access *a, ty *t, const char *name)
{
  addFunc(ve, a, t, name, t, t);
}
void addSimpleOperator(venv &ve, bltin f, ty *t, const char *name)
{
  addFunc(ve, f, t, name, t, t);
}
void addBooleanOperator(venv &ve, access *a, ty *t, const char *name)
{
  addFunc(ve, a, primBoolean(), name, t, t);
}
void addBooleanOperator(venv &ve, bltin f, ty *t, const char *name)
{
  addFunc(ve, f, primBoolean(), name, t, t);
}

template<class T, template <class S> class op>
inline void addOps(venv &ve, ty *t1, const char *name, ty *t2)
{
  addSimpleOperator(ve,run::binaryOp<T,op>,t2,name);
  addFunc(ve,run::arrayOp<T,op>,t1,name,t1,t2);
  addFunc(ve,run::opArray<T,op>,t1,name,t2,t1);
  addSimpleOperator(ve,run::arrayArrayOp<T,op>,t1,name);
}

template<class T, template <class S> class op>
inline void addBooleanOps(venv &ve, ty *t1, const char *name, ty *t2)
{
  addBooleanOperator(ve,run::binaryOp<T,op>,t2,name);
  addFunc(ve,run::arrayOp<T,op>,boolArray(),name,t1,t2);
  addFunc(ve,run::opArray<T,op>,boolArray(),name,t2,t1);
  addFunc(ve,run::arrayArrayOp<T,op>,boolArray(),name,t1,t1);
}

template<class T>
inline void addUnorderedOps(venv &ve, ty *t1, ty *t2, ty *t3, ty *t4)
{
  addBooleanOps<T,run::equals>(ve,t1,"==",t2);
  addBooleanOps<T,run::notequals>(ve,t1,"!=",t2);
  
  addFunc(ve,run::writen<T>,primVoid(),"write",t2);
  addFunc(ve,run::write2<T>,primVoid(),"write",t2,t2);
  addFunc(ve,run::write3<T>,primVoid(),"write",t2,t2,t2);
  addFunc(ve,run::showArray<T>,primVoid(),"write",t1);
  addFunc(ve,run::showArray2<T>,primVoid(),"write",t3);
  addFunc(ve,run::showArray3<T>,primVoid(),"write",t4);
  
  addFunc(ve,run::write<T>,primVoid(),"write",primFile(),t2);
  addFunc(ve,run::writeArray<T>,primVoid(),"write",primFile(),t1);
  addFunc(ve,run::writeArray2<T>,primVoid(),"write",primFile(),t3);
  addFunc(ve,run::writeArray3<T>,primVoid(),"write",primFile(),t4);
}

template<class T>
inline void addOrderedOps(venv &ve, ty *t1, ty *t2, ty *t3)
{
  addBooleanOps<T,run::less>(ve,t1,"<",t2);
  addBooleanOps<T,run::lessequals>(ve,t1,"<=",t2);
  addBooleanOps<T,run::greaterequals>(ve,t1,">=",t2);
  addBooleanOps<T,run::greater>(ve,t1,">",t2);
  
  addFunc(ve,run::minArray<T>,t2,"min",t1);
  addFunc(ve,run::maxArray<T>,t2,"max",t1);
  addFunc(ve,run::sortArray<T>,t1,"sort",t1);
  addFunc(ve,run::sortArray2<T>,t3,"sort",t3);
  addFunc(ve,run::searchArray<T>,primInt(),"search",t1,t2);
  
  addOps<T,run::min>(ve,t1,"min",t2);
  addOps<T,run::max>(ve,t1,"max",t2);
}

template<class T>
inline void addBasicOps(venv &ve, ty *t1, ty *t2, ty *t3, ty *t4)
{
  addOps<T,run::plus>(ve,t1,"+",t2);
  addOps<T,run::minus>(ve,t1,"-",t2);
  
  addFunc(ve,&id,t1,"+",t1);
  addFunc(ve,&id,t2,"+",t2);
  addFunc(ve,run::arrayNegate<T>,t1,"-",t1);
  addFunc(ve,run::Negate<T>,t2,"-",t2);
  
  addFunc(ve,run::sumArray<T>,t2,"sum",t1);
  addUnorderedOps<T>(ve,t1,t2,t3,t4);
}

template<class T>
inline void addOps(venv &ve, ty *t1, ty *t2, ty *t3, ty *t4, bool divide=true)
{
  addBasicOps<T>(ve,t1,t2,t3,t4);
  addOps<T,run::times>(ve,t1,"*",t2);
  if(divide) addOps<T,run::divide>(ve,t1,"/",t2);
  addOps<T,run::power>(ve,t1,"^",t2);
}

function *voidFunction()
{
  function *ft = new function(primVoid());
  return ft;
}

function *intRealFunction()
{
  function *ft = new function(primInt());
  ft->add(primReal());

  return ft;
}

function *realPairFunction()
{
  function *ft = new function(primReal());
  ft->add(primPair());

  return ft;
}

void addOperators(venv &ve) 
{
  addFunc(ve,run::realIntPow,primReal(),"^",primReal(),primInt());

  addFunc(ve,run::boolNot,primBoolean(),"!",primBoolean());
  addBooleanOperator(ve,run::boolXor,primBoolean(),"^");

  addBooleanOperator(ve,run::boolTrue,primNull(),"==");
  addBooleanOperator(ve,run::intZero,primNull(),"!=");

  addSimpleOperator(ve,run::binaryOp<string,run::plus>,primString(),"+");
  
  addSimpleOperator(ve,run::transformTransformMult,primTransform(),"*");
  addFunc(ve,run::transformPairMult,primPair(),"*",primTransform(),
	  primPair());
  addFunc(ve,run::transformPathMult,primPath(),"*",primTransform(),
	  primPath());
  addFunc(ve,run::transformPenMult,primPen(),"*",primTransform(),
	  primPen());
  addFunc(ve,run::transformFrameMult,primPicture(),"*",primTransform(),
	  primPicture());
  addFunc(ve,run::transformPow,primTransform(),"^",primTransform(),
	  primInt());
  addFunc(ve,run::boolNullFrame,primBoolean(),"empty",primPicture());

  addSimpleOperator(ve,run::penPenPlus,primPen(),"+");
  addFunc(ve,run::realPenTimes,primPen(),"*",primReal(),primPen());
  addFunc(ve,run::penRealTimes,primPen(),"*",primPen(),primReal());
  addBooleanOperator(ve,run::boolPenEq,primPen(),"==");
  addBooleanOperator(ve,run::boolPenNeq,primPen(),"!=");

  addFunc(ve,run::arrayBoolNegate,boolArray(),"!",boolArray());
  addBooleanOps<bool,run::And>(ve,boolArray(),"&&",primBoolean());
  addBooleanOps<bool,run::Or>(ve,boolArray(),"||",primBoolean());
  addBooleanOps<bool,run::Xor>(ve,boolArray(),"^",primBoolean());
  
  addUnorderedOps<bool>(ve,boolArray(),primBoolean(),boolArray2(),
			boolArray3());
  addOps<int>(ve,intArray(),primInt(),intArray2(),intArray3(),false);
  addOps<double>(ve,realArray(),primReal(),realArray2(),realArray3());
  addOps<pair>(ve,pairArray(),primPair(),pairArray2(),pairArray3());
  addBasicOps<triple>(ve,tripleArray(),primTriple(),tripleArray2(),
		      tripleArray3());
  addUnorderedOps<string>(ve,stringArray(),primString(),stringArray2(),
			  stringArray3());
  
  addFunc(ve,run::binaryOp<int,divide>,primReal(),"/",primInt(),primInt());
  addFunc(ve,run::arrayOp<int,divide>,realArray(),"/",intArray(),primInt());
  addFunc(ve,run::opArray<int,divide>,realArray(),"/",primInt(),intArray());
  addFunc(ve,run::arrayArrayOp<int,divide>,realArray(),"/",intArray(),
	  intArray());
  
  addOrderedOps<int>(ve,intArray(),primInt(),intArray2());
  addOrderedOps<double>(ve,realArray(),primReal(),realArray2());
  addOrderedOps<string>(ve,stringArray(),primString(),stringArray2());
  
  addOps<int,run::mod>(ve,intArray(),"%",primInt());
  addOps<double,run::mod>(ve,realArray(),"%",primReal());
  
  addFunc(ve,run::realTripleMult,primTriple(),"*",primReal(),primTriple());
  addFunc(ve,run::tripleRealMult,primTriple(),"*",primTriple(),primReal());
  addFunc(ve,run::tripleRealDivide,primTriple(),"/",primTriple(),primReal());
}

double identity(double x) {return x;}
double pow10(double x) {return pow(10.0,x);}

// NOTE: We should move all of these into a "builtin" module.
void base_venv(venv &ve)
{
  addInitializers(ve);
  addCasts(ve);
  addOperators(ve);
  addGuideOperators(ve);

  addFunc(ve,run::fill,primVoid(),"fill",primPicture(),pathArray(),
	  primPen());
  addFunc(ve,run::latticeShade,primVoid(),"fill",primPicture(),pathArray(),
	  primPen(),penArray2());
  addFunc(ve,run::axialShade,primVoid(),"fill",primPicture(),pathArray(),
	  primPen(),primPair(),primPen(),primPair());
  addFunc(ve,run::radialShade,primVoid(),"fill",primPicture(),pathArray(),
	  primPen(),primPair(),primReal(),primPen(),primPair(),primReal());
  addFunc(ve,run::gouraudShade,primVoid(),"fill",primPicture(),pathArray(),
	  primPen(), penArray(),pairArray(),intArray());
  addFunc(ve,run::clip,primVoid(),"clip",primPicture(),pathArray(),
	  primPen());
  addFunc(ve,run::beginClip,primVoid(),"beginclip",primPicture(),
	  pathArray(),primPen());
  addFunc(ve,run::image,primVoid(),"image",primPicture(),realArray2(),
	  penArray(),primPair(),primPair());
  
  addFunc(ve,run::shipout,primVoid(),"shipout",primString(),primPicture(),
	  primPicture(),primString(),primBoolean(),transformArray(),
	  boolArray());
  
  addFunc(ve,run::postscript,primVoid(),"postscript",primPicture(),
	  primString());
  addFunc(ve,run::tex,primVoid(),"tex",primPicture(),primString());
  addFunc(ve,run::texPreamble,primVoid(),"texpreamble",primString());
  addFunc(ve,run::layer,primVoid(),"layer",primPicture());
  
  addFunc(ve,run::intIntMax,primInt(),"intMax");
  addRealFunc0(ve,run::realPi,"pi");
  addRealFunc0(ve,run::realInfinity,"Infinity");
  addRealFunc0(ve,run::realRealMax,"realMax");
  addRealFunc0(ve,run::realRealMin,"realMin");
  addRealFunc0(ve,run::realRealEpsilon,"realEpsilon");

  addRealFunc(sin);
  addRealFunc(cos);
  addRealFunc(tan);
  addRealFunc(asin);
  addRealFunc(acos);
  addRealFunc(atan);
  addRealFunc(exp);
  addRealFunc(log);
  addRealFunc(log10);
  addRealFunc(sinh);
  addRealFunc(cosh);
  addRealFunc(tanh);
  addRealFunc(asinh);
  addRealFunc(acosh);
  addRealFunc(atanh);
  addRealFunc(sqrt);
  addRealFunc(cbrt);
  addRealFunc(fabs);
  addRealFunc<fabs>(ve,"abs");

  addRealFunc(pow10);
  addRealFunc(identity);
  
  addFunc(ve,run::realJ,primReal(),"J",primInt(),primReal());
  addFunc(ve,run::realY,primReal(),"Y",primInt(),primReal());
  
  addRealFunc2(ve,run::realAtan2,"atan2");
  addRealFunc2(ve,run::realHypot,"hypot");
  addRealFunc2(ve,run::realFmod,"fmod");
  addRealFunc2(ve,run::realRemainder,"remainder");
  
  addFunc(ve,run::intQuotient,primInt(),"quotient",primInt(),primInt());
  addFunc(ve,run::intAbs,primInt(),"abs",primInt());
  addFunc(ve,run::intCeil,primInt(),"ceil",primReal());
  addFunc(ve,run::intFloor,primInt(),"floor",primReal());
  addFunc(ve,run::intSgn,primInt(),"sgn",primReal());
  addFunc(ve,run::intRound,primInt(),"round",primReal());
  
  addFunc(ve,run::intRand,primInt(),"rand");
  addFunc(ve,run::intSrand,primVoid(),"srand",primInt());
  addFunc(ve,run::intRandMax,primInt(),"randMax");
  
  addFunc(ve,run::pairXPart,primReal(),"xpart",primPair());
  addFunc(ve,run::pairYPart,primReal(),"ypart",primPair());
  addFunc(ve,run::pairLength,primReal(),"length",primPair());
  addFunc(ve,run::pairLength,primReal(),"abs",primPair());
  addFunc(ve,run::pairAngle,primReal(),"angle",primPair());
  addFunc(ve,run::pairDegrees,primReal(),"degrees",primPair());
  addFunc(ve,run::pairUnit,primPair(),"unit",primPair());
  addFunc(ve,run::realDir,primPair(),"dir",primReal());
  addFunc(ve,run::pairExpi,primPair(),"expi",primReal());
  addFunc(ve,run::pairConj,primPair(),"conj",primPair());
  addFunc(ve,run::pairDot,primReal(),"dot",primPair(),primPair());

  addFunc(ve,run::tripleXPart,primReal(),"xpart",primTriple());
  addFunc(ve,run::tripleYPart,primReal(),"ypart",primTriple());
  addFunc(ve,run::tripleZPart,primReal(),"zpart",primTriple());
  addFunc(ve,run::tripleLength,primReal(),"length",primTriple());
  addFunc(ve,run::tripleLength,primReal(),"abs",primTriple());
  addFunc(ve,run::triplePolar,primReal(),"polar",primTriple());
  addFunc(ve,run::tripleAzimuth,primReal(),"azimuth",primTriple());
  addFunc(ve,run::tripleCoLatitude,primReal(),"colatitude",primTriple());
  addFunc(ve,run::tripleLatitude,primReal(),"latitude",primTriple());
  addFunc(ve,run::tripleLongitude,primReal(),"longitude",primTriple());
  addFunc(ve,run::tripleUnit,primTriple(),"unit",primTriple());
  addFunc(ve,run::tripleDir,primTriple(),"dir",primReal(),primReal());
  addFunc(ve,run::tripleDot,primReal(),"dot",primTriple(),primTriple());
  addFunc(ve,run::tripleCross,primTriple(),"cross",primTriple(),primTriple());
  
  addFunc(ve,run::tridiagonal,realArray(),"tridiagonal",
	  realArray(),realArray(),realArray(),realArray());
  
  addFunc(ve,run::stringReplace,primString(),"replace",primString(),
	  stringArray2());
  addFunc(ve,run::stringFormatReal,primString(),"format",primString(),
	  primReal());
  addFunc(ve,run::stringFormatInt,primString(),"format",primString(),
	  primInt());
  addFunc(ve,run::stringTime,primString(),"time",primString());
  
  addFunc(ve,run::atExit,primVoid(),"atexit",voidFunction());
  addFunc(ve,run::exitFunction,primVoid(),"exitfunction");
  addFunc(ve,run::execute,primVoid(),"execute",primString());
  addFunc(ve,run::eval,primVoid(),"eval",primString());
  addFunc(ve,run::merge,primInt(),"merge",primString(),primString(),
	  primBoolean());
  addFunc(ve,run::changeDirectory,primString(),"cd",primString());
  addFunc(ve,run::scrollLines,primVoid(),"scroll",primInt());
  addFunc(ve,run::boolDeconstruct,primBoolean(),"deconstruct");
  
  addFunc(ve,run::pathSize,primInt(),"size",primPath());
  addFunc(ve,run::pathMax,primPair(),"max",primPath());
  addFunc(ve,run::pathMin,primPair(),"min",primPath());
  
  addFunc(ve,run::frameMax,primPair(),"max",primPicture());
  addFunc(ve,run::frameMin,primPair(),"min",primPicture());
  
  addFunc(ve,run::lineType,primPen(),"linetype",primString(),primBoolean());
  addFunc(ve,run::grayPen,primPen(),"gray",primPen());
  addFunc(ve,run::rgbPen,primPen(),"rgb",primPen());
  addFunc(ve,run::rgb,primPen(),"rgb",primReal(),primReal(),primReal());
  addFunc(ve,run::cmyk,primPen(),"cmyk",primReal(),primReal(),primReal(),
	  primReal());
  addFunc(ve,run::gray,primPen(),"gray",primReal());
  addFunc(ve,run::colors,realArray(),"colors",primPen());
  addFunc(ve,run::pattern,primPen(),"pattern",primString());
  addFunc(ve,run::penPattern,primString(),"pattern",primPen());
  addFunc(ve,run::fillRule,primPen(),"fillrule",primInt());
  addFunc(ve,run::penFillRule,primInt(),"fillrule",primPen());
  addFunc(ve,run::penBaseLine,primInt(),"basealign",primPen());
  addFunc(ve,run::resetdefaultPen,primVoid(),"defaultpen");
  addFunc(ve,run::setDefaultPen,primVoid(),"defaultpen",primPen());
  addFunc(ve,run::invisiblePen,primPen(),"invisible");
  addFunc(ve,run::lineCap,primPen(),"linecap",primInt());
  addFunc(ve,run::penLineCap,primInt(),"linecap",primPen());
  addFunc(ve,run::lineJoin,primPen(),"linejoin",primInt());
  addFunc(ve,run::penLineJoin,primInt(),"linejoin",primPen());
  addFunc(ve,run::lineWidth,primPen(),"linewidth",primReal());
  addFunc(ve,run::penLineWidth,primReal(),"linewidth",primPen());
  addFunc(ve,run::font,primPen(),"fontcommand",primString());
  addFunc(ve,run::penFont,primString(),"font",primPen());
  addFunc(ve,run::fontSize,primPen(),"fontsize",primReal(),primReal());
  addFunc(ve,run::penFontSize,primReal(),"fontsize",primPen());
  addFunc(ve,run::penLineSkip,primReal(),"lineskip",primPen());
  addFunc(ve,run::overWrite,primPen(),"overwrite",primInt());
  addFunc(ve,run::penOverWrite,primInt(),"overwrite",primPen());
  addFunc(ve,run::penMax,primPair(),"max",primPen());
  addFunc(ve,run::penMin,primPair(),"min",primPen());
  
  // Transform creation
  
  addFunc(ve,run::transformIdentity,primTransform(),"identity");
  addFunc(ve,run::transformInverse,primTransform(),"inverse",primTransform());
  addFunc(ve,run::transformShift,primTransform(),"shift",primPair());
  addFunc(ve,run::transformXscale,primTransform(),"xscale",primReal());
  addFunc(ve,run::transformYscale,primTransform(),"yscale",primReal());
  addFunc(ve,run::transformScale,primTransform(),"scale",primReal());
  addFunc(ve,run::transformScaleInt,primTransform(),"scale",primInt());
  addFunc(ve,run::transformScalePair,primTransform(),"scale",primPair());
  addFunc(ve,run::transformSlant,primTransform(),"slant",primReal());
  addFunc(ve,run::transformRotate,primTransform(),"rotate",primReal(),
	  primPair());
  addFunc(ve,run::transformReflect,primTransform(),"reflect",primPair(),
	  primPair());
  addBooleanOperator(ve,run::boolTransformEq,primTransform(),"==");
  addBooleanOperator(ve,run::boolTransformNeq,primTransform(),"!=");
  
  // I/O functions

  addFunc(ve,run::fileOpenOut,primFile(),"output",primString(),primBoolean());
  addFunc(ve,run::fileOpenIn,primFile(),"input",primString(),primBoolean());
  addFunc(ve,run::fileOpenXOut,primFile(),"xoutput",primString(),
	  primBoolean());
  addFunc(ve,run::fileOpenXIn,primFile(),"xinput",primString(),primBoolean());

  addFunc(ve,run::fileEol,primBoolean(),"eol",primFile());
  addFunc(ve,run::fileEof,primBoolean(),"eof",primFile());
  addFunc(ve,run::fileError,primBoolean(),"error",primFile());
  addFunc(ve,run::fileClear,primVoid(),"clear",primFile());
  addFunc(ve,run::fileClose,primVoid(),"close",primFile());
  addFunc(ve,run::filePrecision,primVoid(),"precision",primFile(),primInt());
  addFunc(ve,run::fileFlush,primVoid(),"flush",primFile());

  addFunc(ve,run::fileDimension1,primFile(),"dimension",primFile(),primInt());
  addFunc(ve,run::fileDimension2,primFile(),"dimension",primFile(),primInt(),
	  primInt());
  addFunc(ve,run::fileDimension3,primFile(),"dimension",primFile(),primInt(),
	  primInt(),primInt());
  addFunc(ve,run::fileCSVMode,primFile(),"csv",primFile(),primBoolean());
  addFunc(ve,run::fileLineMode,primFile(),"line",primFile(),primBoolean());
  addFunc(ve,run::fileSingleMode,primFile(),"single",primFile(),primBoolean());
  addFunc(ve,run::fileArray1,primFile(),"read1",primFile());
  addFunc(ve,run::fileArray2,primFile(),"read2",primFile());
  addFunc(ve,run::fileArray3,primFile(),"read3",primFile());
  addFunc(ve,run::readChar,primString(),"getc",primFile());

  addFunc(ve,run::writen<pen>,primVoid(),"write",primPen());
  addFunc(ve,run::write<pen>,primVoid(),"write",primFile(),primPen());
  addFunc(ve,run::writen<transform>,primVoid(),"write",primTransform());
  addFunc(ve,run::write<transform>,primVoid(),"write",primFile(),
	  primTransform());
  addFunc(ve,run::writenP<guide>,primVoid(),"write",primGuide());
  addFunc(ve,run::writeP<guide>,primVoid(),"write",primFile(),primGuide());
  
  // Array functions
  
  addFunc(ve,run::arrayFunction,realArray(),"map",realPairFunction(),
	  pairArray());
  addFunc(ve,run::arrayFunction,intArray(),"map",intRealFunction(),
	  realArray());
  
  addFunc(ve,run::arrayAll,primBoolean(),"all",boolArray());
  addFunc(ve,run::arrayBoolSum,primInt(),"sum",boolArray());
  
  addFunc(ve,run::intSequence,intArray(),"sequence",primInt());
  addFunc(ve,run::arrayFind,primInt(),"find",boolArray(),primInt());
#ifdef HAVE_LIBFFTW3
  addFunc(ve,run::pairArrayFFT,pairArray(),"fft",pairArray(),primInt());
#endif

  gen_base_venv(ve);
}

void base_menv(menv&)
{
}

} //namespace trans
