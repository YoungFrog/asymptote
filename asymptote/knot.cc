/*****
 * knot.cc
 * Andy Hammerlindl 2005/02/10
 *
 * Describes a knot, a point and its neighbouring specifiers, used as an
 * intermediate structure in solving paths.
 *****/

#include "knot.h"
#include "util.h"

#include "angle.h"
#include "settings.h"

namespace camp {

/***** Debugging *****/
//bool tracing_solving=false;

template <typename T>
ostream& info(ostream& o, string name, cvector<T>& v)
{
  if (settings::verbose > 3) {
    o << name << ":\n\n";

    for(int i=0; i < (int) v.size(); ++i)
      o << v[i] << std::endl;

    o << std::endl;
  }
  return o;
}

ostream& info(ostream& o, string name, knotlist& l)
{
  if (settings::verbose > 3) {
    o << name << ":\n\n";

    for(int i=0; i < (int) l.size(); ++i)
      o << l[i] << std::endl;

    if (l.cyclic())
      o << "cyclic" << std::endl;

    o << std::endl;
  }
  return o;
}

#define INFO(x) info(std::cerr,#x,x)

/***** Constants *****/

const double VELOCITY_BOUND = 4.00;

/***** Auxillary computation functions *****/

// Computes the relative distance of a control point given the angles.  The name
// is somewhat misleading as the velocity (with respect to the variable that
// parameterizes the path) is relative to the distance between the knots and
// even then, is actually three times this.
// The routine is based on the velocity function in Section 131 of the MetaPost
// code, but differs in that it automatically accounts for the tension and
// bounding with tension atleast.
double velocity(double theta, double phi, tension t)
{
  const double a = 1.41421356237309504880; // sqrt(2)
  const double b = 0.0625;                 // 1/16
  const double c = 1.23606797749978969641; // sqrt(5) - 1
  const double d = 0.76393202250021030359; // 3 - sqrt(5)

  double st = sin(theta), ct = cos(theta),
         sf = sin(phi),   cf = cos(phi);

  // NOTE: Have to deal with degenerate condition theta = phi = -pi

  double r =  (2.0 + a*(st - b*sf)*(sf - b*st)*(ct-cf)) /
              (3.0 * t.val * (1.0 + 0.5*c*ct + 0.5*d*cf));

  //cerr << " velocity(" << theta << "," << phi <<")= " << r << endl;
  if (r >  VELOCITY_BOUND)
    r = VELOCITY_BOUND;

  // Apply boundedness condition for tension atleast cases.
  if (t.atleast)
  {
    double sine = sin(theta + phi);
    if ((st >= 0.0 && sf >= 0.0 && sine > 0.0) ||
        (st <= 0.0 && sf <= 0.0 && sine < 0.0))
    {
      double rmax = sf / sine;
      if (r > rmax)
        r = rmax;
    }
  }

  return r;
}

double niceAngle(pair z)
{
  return z.gety() == 0 ? z.getx() >= 0 ? 0 : PI
                       : angle(z);
}

// Ensures an angle is in the range between -PI and PI.
double reduceAngle(double angle)
{
  return angle >  PI ? angle - 2.0*PI :
         angle < -PI ? angle + 2.0*PI :
                       angle;
}


bool interesting(tension t)
{
  return t.val!=1.0 || t.atleast==true;
}

bool interesting(spec *s)
{
  return !s->open();
}

ostream& operator<<(ostream& out, const knot& k)
{
  if (interesting(k.tin))
    out << k.tin << " ";
  if (interesting(k.in))
    out << *k.in << " ";
  out << k.z;
  if (interesting(k.in))
    out << " " << *k.out;
  if (interesting(k.tin))
    out << " " << k.tout;
  return out;
}


eqn dirSpec::eqnOut(int j, knotlist& l, cvector<double>&, cvector<double>&)
{
  // When choosing the control points, the path will come out the first knot
  // going straight to the next knot rotated by the angle theta.  Therefore, the
  // angle theta we want is the difference between the specified heading given
  // and the heading to the next knot.
  double theta=reduceAngle(given-niceAngle(l[j+1].z-l[j].z));

  // Give a simple linear equation to ensure this theta is picked.
  return eqn(0.0,1.0,0.0,theta);
}

eqn dirSpec::eqnIn(int j, knotlist& l, cvector<double>&, cvector<double>&)
{
  double theta=reduceAngle(given-niceAngle(l[j].z-l[j-1].z));
  return eqn(0.0,1.0,0.0,theta);
}

eqn curlSpec::eqnOut(int j, knotlist& l, cvector<double>&, cvector<double>& psi)
{
  double alpha=l[j].alpha();
  double beta=l[j+1].beta();

  double chi=alpha*alpha*gamma/(beta*beta);

  double C=alpha*chi+3-beta;
  double D=(3.0-alpha)*chi+beta;

  return eqn(0.0,C,D,-D*psi[j+1]);
}

eqn curlSpec::eqnIn(int j, knotlist& l, cvector<double>&, cvector<double>&)
{
  double alpha=l[j-1].alpha();
  double beta=l[j].beta();

  double chi=beta*beta*gamma/(alpha*alpha);

  double A=(3-beta)*chi+alpha;
  double B=beta*chi+3-alpha;

  return eqn(A,B,0.0,0.0);
}

spec *controlSpec::outPartner(pair z)
{
  static curlSpec curl;
  return cz==z ? (spec *)&curl : (spec *)new dirSpec(z-cz);
}

spec *controlSpec::inPartner(pair z)
{
  static curlSpec curl;
  return cz==z ? (spec *)&curl : (spec *)new dirSpec(cz-z);
}

// Compute the displacement between points. The j-th result is the distance
// between knot j and knot j+1.
struct dzprop : public knotprop<pair> {
  dzprop(knotlist& l)
    : knotprop<pair>(l) {}

  pair solo(int) { return pair(0,0); }
  pair start(int j) { return l[j+1].z - l[j].z; }
  pair mid(int j) { return l[j+1].z - l[j].z; }
  pair end(int) { return pair(0,0); }
};

// Compute the distance between points, using the already computed dz.  This
// doesn't use the infomation in the knots, but the knotprop class is useful as
// it takes care of the iteration for us.
struct dprop : public knotprop<double> {
  cvector<pair>& dz;

  dprop(knotlist &l, cvector<pair>& dz)
    : knotprop<double>(l), dz(dz) {}

  double solo(int j) { return length(dz[j]); }
  double start(int j) { return length(dz[j]); }
  double mid(int j) { return length(dz[j]); }
  double end(int j) { return length(dz[j]); }
};

// Compute the turning angles (psi) between points, using the already computed
// dz.
struct psiprop : public knotprop<double> {
  cvector<pair>& dz;

  psiprop(knotlist &l, cvector<pair>& dz)
    : knotprop<double>(l), dz(dz) {}

  double solo(int) { return 0; }

  // We set the starting and ending psi to zero.
  double start(int) { return 0; }
  double end(int) { return 0; }

  double mid(int j) { return niceAngle(dz[j]/dz[j-1]); }
};

struct eqnprop : public knotprop<eqn> {
  cvector<double>& d;
  cvector<double>& psi;

  eqnprop(knotlist &l, cvector<double>& d, cvector<double>& psi)
    : knotprop<eqn>(l), d(d), psi(psi) {}

  eqn solo(int) {
    assert(False);
    return eqn(0.0,1.0,0.0,0.0);
  }

  eqn start(int j) {
    // Defer to the specifier, as it knows the specifics.
    return dynamic_cast<endSpec *>(l[j].out)->eqnOut(j,l,d,psi);
  }

  eqn end(int j) {
    return dynamic_cast<endSpec *>(l[j].in)->eqnIn(j,l,d,psi);
  }

  eqn mid(int j) {
    double lastAlpha = l[j-1].alpha();
    double thisAlpha = l[j].alpha();
    double thisBeta  = l[j].beta();
    double nextBeta  = l[j+1].beta();

    // Values based on the linear approximation of the curvature coming into the
    // knot with respect to theta[j-1] and theta[j].
    double inDenom = thisBeta*thisBeta*d[j-1];
    double A = lastAlpha/inDenom;
    double B = (3.0 - lastAlpha)/inDenom;

    // Values based on the linear approximation of the curvature going out of
    // the knot with respect to theta[j] and theta[j+1].
    double outDenom = thisAlpha*thisAlpha*d[j];
    double C = (3.0 - nextBeta)/outDenom;
    double D = nextBeta/outDenom;

    return eqn(A,B+C,D,-B*psi[j]-D*psi[j+1]);
  }
};

// If the system of equations is homogeneous (ie. we are solving for x in Ax=0),
// then there is no need to solve for theta, we can just use zeros for the
// thetas.  In fact, our general solving method may not work in this case.  A
// common example of this is
//   
//   a{curl 1}..{curl 1}b
//
// which arises when solving a one-length path a..b or in a larger path a
// section a--b.
bool homogeneous(vector<eqn>& e)
{
  for(vector<eqn>::iterator p=e.begin(); p!=e.end(); ++p)
    if (p->aug != 0)
      return false;
  return true;
}

// Checks the equation being solved will be solve as a straight path from the
// first point to the second.
bool straightSection(cvector<eqn>& e)
{
  return e.size()==2 && e.front().aug==0 && e.back().aug==0;
}

struct weqn : public eqn {
  double w;
  weqn(double pre, double piv, double post, double aug, double w=0)
    : eqn(pre,piv,post,aug), w(w) {}

  friend ostream& operator<< (ostream& out, const weqn we)
  {
    return out << (eqn &)we << " + " << we.w << " * theta[0]";
  }
};

weqn scale(weqn q) {
  assert(q.pre == 0 && q.piv != 0);
  return weqn(0,1,q.post/q.piv,q.aug/q.piv,q.w/q.piv);
}

/* Recalculate the equations in the form:
 *   theta[j] + post * theta[j+1] = aug + w * theta[0]
 * 
 * Used as the first step in solve cyclic equations.
 */
cvector<weqn> recalc(cvector<eqn>& e)
{
  int n=(int) e.size();
  cvector<weqn> we;
  weqn lasteqn(0,1,0,0,1);
  we.push_back(lasteqn); // As a placeholder.
  for (int j=1; j < n; j++) {
    // Subtract a factor of the last equation so that the first entry is
    // zero, then procede to scale it.
    eqn& q=e[j];
    lasteqn=scale(weqn(0,q.piv-q.pre*lasteqn.post,q.post,
          q.aug-q.pre*lasteqn.aug,-q.pre*lasteqn.w));
    we.push_back(lasteqn);
  }
  // To keep all of the infomation enocoded in the linear equations, we need
  // to augment the computation to replace our trivial start weqn with a
  // real one.  To do this, we take one more step in the iteration and
  // compute the weqn for j=n, since n=0 (mod n).
  {
    eqn& q=e[0];
    we.front()=scale(weqn(0,q.piv-q.pre*lasteqn.post,q.post,
          q.aug-q.pre*lasteqn.aug,-q.pre*lasteqn.w));
  }
  return we;
}

double solveForTheta0(cvector<weqn>& we)
{
  // Solve for theta[0]=theta[n].
  // How we do this is essentially to write out the first equation as:
  //
  //   theta[n] = aug[0] + w[0]*theta[0] - post[0]*theta[1]
  //
  // and then use the next equation to substitute in for theta[1]:
  //
  //   theta[1] = aug[1] + w[1]*theta[0] - post[1]*theta[2]
  //
  // and so on until we have an equation just in terms of theta[0] and
  // theta[n] (which are the same theta).
  //
  // The loop invariant maintained is that after j iterations, we have
  //   theta[n]= a + b*theta[0] + c*theta[j]
  int n=(int) we.size();
  double a=0,b=0,c=1;
  for (int j=0;j<n;++j) {
    weqn& q=we[j];
    a+=c*q.aug;
    b+=c*q.w;
    c=-c*q.post;
  }

  // After the iteration we have
  // 
  //   theta[n] = a + b*theta[0] + c*theta[n]
  //
  // where theta[n]=theta[0], so
  return a/(1.0-(b+c));
}

cvector<double> backsubCyclic(cvector<weqn>& we, double theta0)
{
  int n=(int) we.size();
  cvector<double> thetas;
  double lastTheta=theta0;
  for (int j=1;j<=n;++j)
  {
    weqn& q=we[n-j];
    assert(q.pre == 0 && q.piv == 1);
    double theta=-q.post*lastTheta+q.aug+q.w*theta0;
    thetas.push_back(theta);
    lastTheta=theta;
  }
  reverse(thetas.begin(),thetas.end());
  return thetas;
}

// For the non-cyclic equations, do row operation to put the matrix into
// reduced echelon form, ie. calculates equivalent equations but with pre=0 and
// piv=1 for each eqn.
struct ref : public knotprop<eqn> {
  cvector<eqn>& e;
  eqn lasteqn;

  ref(knotlist& l, cvector<eqn>& e)
    : knotprop<eqn>(l), e(e), lasteqn(0,1,0,0) {}

  // Scale the equation so that the pivot (diagonal) entry is one, and save
  // the new equation as lasteqn.
  eqn scale(eqn q) {
    assert(q.pre == 0 && q.piv != 0);
    return lasteqn = eqn(0,1,q.post/q.piv,q.aug/q.piv);
  }

  eqn start(int j) {
    return scale(e[j]);
  }
  eqn mid(int j) {
    // Subtract a factor of the last equation so that the first entry is
    // zero, then procede to scale it.
    eqn& q=e[j];
    return scale(eqn(0,q.piv-q.pre*lasteqn.post,q.post,
          q.aug-q.pre*lasteqn.aug));
  }
  // The end case is the same as the middle case.
};

// Once the matrix is in reduced echelon form, we can solve for the values by
// back-substitution.  This algorithm works from the bottom-up, so backCompute
// must be used to get the answer.
struct backsub : public knotprop<double> {
  cvector<eqn>& e;
  double lastTheta;

  backsub(knotlist& l, cvector<eqn>& e)
    : knotprop<double>(l), e(e) {}

  double end(int j) {
    eqn& q=e[j];
    assert(q.pre == 0 && q.piv == 1 && q.post == 0);
    double theta=q.aug;
    lastTheta=theta;
    return theta;
  }

  double mid(int j) {
    eqn& q=e[j];
    assert(q.pre == 0 && q.piv == 1);
    double theta=-q.post*lastTheta+q.aug;
    lastTheta=theta;
    return theta;
  }

  // start is the same as mid.
};

// Once the equations have been determined, solve for the thetas.
cvector<double> solveThetas(knotlist& l, cvector<eqn>& e)
{
  if (homogeneous(e))
    // We are solving Ax=0, so a solution is zero for every theta.
    return cvector<double>(e.size(),0);
  else if (l.cyclic()) {
    // The knotprop template is unusually unhelpful in this case, so I won't use
    // it here. The algorithm breaks into three passes on the object.  The old
    // Asymptote code used a two-pass method, but I implemented this to stay
    // closer to the MetaPost source code.  This might be something to look at
    // for optimization.
    cvector<weqn> we=recalc(e);
    INFO(we);
    double theta0=solveForTheta0(we);
    return backsubCyclic(we, theta0);
  }
  else { /* Non-cyclic case. */
    /* First do row operations to get it into reduced echelon form. */
    cvector<eqn> el=ref(l,e).compute();

    /* Then, do back substitution. */
    return backsub(l,el).backCompute();
  }
}

// Once thetas have been solved, determine the first control point of every
// join.
struct postcontrolprop : public knotprop<pair> {
  cvector<pair>& dz;
  cvector<double>& psi;
  cvector<double>& theta;

  postcontrolprop(knotlist& l, cvector<pair>& dz,
                  cvector<double>& psi, cvector<double>& theta)
    : knotprop<pair>(l), dz(dz), psi(psi), theta(theta) {}

  double phi(int j) {
    /* The third angle: psi + theta + phi = 0 */
    return -psi[j] - theta[j];
  }

  double vel(int j) {
    /* Use the standard velocity function. */
    return velocity(theta[j],phi(j+1),l[j].tout);
  }

  // start is the same as mid.

  pair mid(int j) {
    // Put a control point at the relative distance determined by the velocity,
    // and at an angle determined by theta.
    return l[j].z + vel(j)*expi(theta[j])*dz[j];
  }

  // The end postcontrol is the same as the last knot.
  pair end(int j) {
    return l[j].z;
  }
};

// Determine the first control point of every join.
struct precontrolprop : public knotprop<pair> {
  cvector<pair>& dz;
  cvector<double>& psi;
  cvector<double>& theta;

  precontrolprop(knotlist& l, cvector<pair>& dz,
                  cvector<double>& psi, cvector<double>& theta)
    : knotprop<pair>(l), dz(dz), psi(psi), theta(theta) {}

  double phi(int j) {
    return -psi[j] - theta[j];
  }

  double vel(int j) {
    return velocity(phi(j),theta[j-1],l[j].tin);
  }

  // The start precontrol is the same as the first knot.
  pair start(int j) {
    return l[j].z;
  }
  pair mid(int j) {
    return l[j].z - vel(j)*expi(-phi(j))*dz[j-1];
  }

  // end is the same as mid.
};

// Puts solved controls into a protopath starting at the given index.
// By convention, the first knot is not coded, as it is assumed to be coded by
// the previous section (or it is the first breakpoint and encoded as a special
// case).
struct encodeControls : public knoteffect {
  protopath& p;
  int k;
  cvector<pair>& pre;
  cvector<pair>& post;

  encodeControls(protopath& p, int k,
                 cvector<pair>& pre, knotlist& l, cvector<pair>& post)
    : knoteffect(l), p(p), k(k), pre(pre), post(post) {}

  void encodePre(int j) {
    p.pre(k+j)=pre[j];
  }
  void encodePoint(int j) {
    p.point(k+j)=l[j].z;
  }
  void encodePost(int j) {
    p.post(k+j)=post[j];
  }

  void solo(int) {
#if 0
    encodePoint(j);
#endif
  }
  void start(int j) {
#if 0
    encodePoint(j);
#endif
    encodePost(j);
  }
  void mid(int j) {
    encodePre(j);
    encodePoint(j);
    encodePost(j);
  }
  void end(int j) {
    encodePre(j);
    encodePoint(j);
  }
};

void encodeStraight(protopath& p, int k, knotlist& l)
{
  pair a=l.front().z;
  pair b=l.back().z;
  pair step=(b-a)/3.0;
  
  p.straight(k)=true;
  p.post(k)=a+step;
  p.pre(k+1)=b-step;
  p.point(k+1)=b;
}

void solveSection(protopath& p, int k, knotlist& l)
{
  if (l.length()>0) {
    info(std::cerr, "solving section", l);

    // Calculate useful properties.
    cvector<pair>   dz  =  dzprop(l)   .compute();
    cvector<double> d   =   dprop(l,dz).compute();
    cvector<double> psi = psiprop(l,dz).compute();

    INFO(dz); INFO(d); INFO(psi);

    // Build and solve the linear equations for theta.
    cvector<eqn>        e = eqnprop(l,d,psi).compute();
    INFO(e);

    if (straightSection(e))
      // Handle striaght section as special case.
      encodeStraight(p,k,l);
    else {
      cvector<double> theta = solveThetas(l,e);
      INFO(theta);

      // Calculate the control points.
      cvector<pair> post = postcontrolprop(l,dz,psi,theta).compute();
      cvector<pair> pre  =  precontrolprop(l,dz,psi,theta).compute();

      // Encode the results into the protopath.
      encodeControls(p,k,pre,l,post).exec();
    }
  }
}

// Find the first breakpoint in the knotlist, ie. where we can start solving a
// non-cyclic section.  If the knotlist is fully cyclic, then this returns
// NOBREAK.
// This must be called with a knot that has all of its implicit specifiers in
// place.
const int NOBREAK=-1;
int firstBreakpoint(knotlist& l)
{
  for (int j=0;j<l.length();++j)
    if (!l[j].out->open())
      return j;
  return NOBREAK;
}

// Once a breakpoint, a, is found, find where the next breakpoint after it is.
// This must be called with a knot that has all of its implicit specifiers in
// place, so that breakpoint can be identified by either an in or out specifier
// that is not open.
int nextBreakpoint(knotlist& l, int a)
{
  // This is guaranteed to terminate if a is the index of a breakpoint.  If the
  // path is non-cyclic it will stop at or before the last knot which must be a
  // breakpoint.  If the path is cyclic, it will stop at or before looping back
  // around to a which is a breakpoint.
  int j=a+1;
  while (l[j].in->open())
    ++j;
  return j;
}

// Write out the controls for section of the form
//   a.. control b and c ..d
void writeControls(protopath& p, int a, knotlist& l)
{
  // By convention, the first point will already be encoded.
  p.post(a)=dynamic_cast<controlSpec *>(l[a].out)->control();
  p.pre(a+1)=dynamic_cast<controlSpec *>(l[a+1].in)->control();
  p.point(a+1)=l[a+1].z;
}

// Solves a path that has all of its specifiers laid out explicitly.
path solveSpecified(knotlist& l)
{
  protopath p(l.size(),l.cyclic());

  int first=firstBreakpoint(l);
  if (first==NOBREAK)
    /* We are solving a fully cyclic path, so do it in one swoop. */
    solveSection(p,0,l);
  else {
    // Encode the first point.
    p.point(first)=l[first].z;

    /* If the path is cyclic, we should stop where we started (modulo the length
     * of the path), otherwise, just stop at the end.
     */
    int last=l.cyclic() ? first+l.length()
                        : l.length();
    int a=first;
    while (a!=last) {
      if (l[a].out->controlled()) {
        // Controls are already picked, just write them out.
        writeControls(p,a,l);
        ++a;
      }
      else {
        // Find the section a to b and solve it, putting the result (starting
        // from index a into our protopath.
        int b=nextBreakpoint(l,a);
        subknotlist section(l,a,b);
        solveSection(p,a,section);
        a=b;
      }
    }

    // For a non-cyclic path, the end control points need to be set.
    p.controlEnds();
  }

  return p.fix();
}

/* If a knot is open on one side and restricted on the other, this replaces the
 * open side with a restriction determined by the restriction on the other side.
 * After this, any knot will either have two open specs or two restrictions.
 */
struct partnerUp : public knoteffect {
  partnerUp(knotlist& l)
    : knoteffect(l) {}

  void mid(int j) {
    knot& k=l[j];
    if (k.in->open() && !k.out->open())
      k.in=k.out->inPartner(k.z);
    else if (!k.in->open() && k.out->open())
      k.out=k.in->outPartner(k.z);
  }
};

/* Ensures a non-cyclic path has direction specifiers at the ends, adding curls
 * if there are none.
 */
void curlEnds(knotlist& l)
{
  static curlSpec endSpec;

  if (!l.cyclic()) {
    if (l.front().in->open())
      l.front().in=&endSpec;
    if (l.back().out->open())
      l.back().out=&endSpec;
  }
}

/* If a point occurs twice in a row in a knotlist, write in controls between the
 * two knots at that point (unless it already has controls).
 */
struct controlDuplicates : public knoteffect {
  controlDuplicates(knotlist& l)
    : knoteffect(l) {}

  void solo(int) { /* One point ==> no duplicates */ }
  // start is the same as mid.
  void mid(int j) {
    knot &k1=l[j];
    knot &k2=l[j+1];
    if (!k1.out->controlled() && k1.z==k2.z)
      k1.out=k2.in=new controlSpec(k1.z);
  }
  void end(int) { /* No next point to compare with. */ }
};

path solve(knotlist& l)
{
  info(std::cerr, "input knotlist", l);
  curlEnds(l);
  controlDuplicates(l).exec();
  partnerUp(l).exec();
  info(std::cerr, "specified knotlist", l);
  return solveSpecified(l);
}

// Code for Testing
#if 0
path solveSimple(cvector<pair>& z)
{
  // The two specifiers used: an open spec and a curl spec for the ends.
  spec open;
  
//  curlSpec curl;
//  curlSpec curly(2.0);
//  dirSpec E(0);
//  dirSpec N(PI/2.0);

  controlSpec here(pair(150,150));

  // Encode the knots as open in the knotlist.
  cvector<knot> nodes;
  for (cvector<pair>::iterator p=z.begin(); p!=z.end(); ++p) {
    knot k;
    k.z=*p;
    k.in=k.out=&open;

    nodes.push_back(k);
  }

  // Substitute in a curl spec for the ends.
  //nodes.front().out=nodes.back().in=&curl;

  // Test direction specifiers.
  //nodes.front().tout=2;
  //nodes.front().out=nodes.back().in=&curly;

  //nodes[0].out=nodes[0].in=&E;
  nodes[1].out=nodes[2].in=&here;

  simpleknotlist l(nodes,false);
  return solve(l);
}
#endif

} // namespace camp
