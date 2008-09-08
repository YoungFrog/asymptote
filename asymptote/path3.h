/*****
 * path.h
 * John Bowman
 *
 * Stores a 3D piecewise cubic spline with known control points.
 *
 *****/

#ifndef PATH3_H
#define PATH3_H

#include <cfloat>

#include "mod.h"
#include "triple.h"
#include "bbox3.h"
#include "path.h"
#include "arrayop.h"

namespace camp {
  
void checkEmpty3(Int n);

// Used in the storage of solved path3 knots.
struct solvedKnot3 : public gc {
  triple pre;
  triple point;
  triple post;
  bool straight;
  solvedKnot3() : straight(false) {}
  
  friend bool operator== (const solvedKnot3& p, const solvedKnot3& q)
  {
    return p.pre == q.pre && p.point == q.point && p.post == q.post;
  }
};

extern const double BigFuzz;
extern const double Fuzz;
extern const double Fuzz2;
extern const double sqrtFuzz;
  
class path3 : public gc {
  bool cycles;  // If the path3 is closed in a loop

  Int n; // The number of knots

  mem::vector<solvedKnot3> nodes;
  mutable double cached_length; // Cache length since path3 is immutable.
  
  mutable bbox3 box;
  mutable bbox3 times; // Times where minimum and maximum extents are attained.

public:
  path3()
    : cycles(false), n(0), nodes(), cached_length(-1) {}

  // Create a path3 of a single point
  path3(triple z, bool = false)
    : cycles(false), n(1), nodes(1), cached_length(-1)
  {
    nodes[0].pre = nodes[0].point = nodes[0].post = z;
    nodes[0].straight = false;
  }  

  // Creates path3 from a list of knots.  This will be used by camp
  // methods such as the guide solver, but should probably not be used by a
  // user of the system unless he knows what he is doing.
  path3(mem::vector<solvedKnot3>& nodes, Int n, bool cycles = false)
    : cycles(cycles), n(n), nodes(nodes), cached_length(-1)
  {
  }

  friend bool operator== (const path3& p, const path3& q)
  {
    return p.cycles == q.cycles && p.nodes == q.nodes;
  }

public:
  path3(solvedKnot3 n1, solvedKnot3 n2)
    : cycles(false), n(2), nodes(2), cached_length(-1)
  {
    nodes[0] = n1;
    nodes[1] = n2;
    nodes[0].pre = nodes[0].point;
    nodes[1].post = nodes[1].point;
  }
  
  // Copy constructor
  path3(const path3& p)
    : cycles(p.cycles), n(p.n), nodes(p.nodes), cached_length(p.cached_length),
      box(p.box)
  {}

  virtual ~path3()
  {
  }

  // Getting control points
  Int size() const
  {
    return n;
  }

  bool empty() const
  {
    return n == 0;
  }

  Int length() const
  {
    return cycles ? n : n-1;
  }

  bool cyclic() const
  {
    return cycles;
  }
  
  mem::vector<solvedKnot3>& Nodes() {
    return nodes;
  }
  
  bool straight(Int t) const
  {
    if (cycles) return nodes[imod(t,n)].straight;
    return (t >= 0 && t < n) ? nodes[t].straight : false;
  }
  
  bool piecewisestraight() const
  {
    Int L=length();
    for(Int i=0; i < L; ++i)
      if(!straight(i)) return false;
    return true;
  }
  
  triple point(Int t) const
  {
    return nodes[adjustedIndex(t,n,cycles)].point;
  }

  triple point(double t) const;
  
  triple precontrol(Int t) const
  {
    return nodes[adjustedIndex(t,n,cycles)].pre;
  }

  triple precontrol(double t) const;
  
  triple postcontrol(Int t) const
  {
    return nodes[adjustedIndex(t,n,cycles)].post;
  }

  triple postcontrol(double t) const;
  
  triple predir(Int t) const {
    if(!cycles && t <= 0) return triple(0,0,0);
    triple z0=point(t-1);
    triple z1=point(t);
    triple c1=precontrol(t);
    triple dir=z1-c1;
    double epsilon=Fuzz2*(z0-z1).abs2();
    if(dir.abs2() > epsilon) return unit(dir);
    triple c0=postcontrol(t-1);
    dir=2*c1-c0-z1;
    if(dir.abs2() > epsilon) return unit(dir);
    return unit(z1-z0+3*(c0-c1));
  }

  triple predir(double t) const {
    if(!cycles) {
      if(t <= 0) return triple(0,0,0);
      if(t >= n-1) return predir(n-1);
    }
    Int a=Floor(t);
    return (t-a < sqrtFuzz) ? predir(a) : subpath((double) a,t).predir((Int) 1);
  }

  triple postdir(Int t) const {
    if(!cycles && t >= n-1) return triple(0,0,0);
    triple z0=point(t);
    triple z1=point(t+1);
    triple c0=postcontrol(t);
    triple dir=c0-z0;
    double epsilon=Fuzz2*(z0-z1).abs2();
    if(dir.abs2() > epsilon) return unit(dir);
    triple c1=precontrol(t+1);
    dir=z0-2*c0+c1;
    if(dir.abs2() > epsilon) return unit(dir);
    return unit(z1-z0+3*(c0-c1));
  }

  triple postdir(double t) const {
    if(!cycles) {
      if(t >= n-1) return triple(0,0,0);
      if(t <= 0) return postdir((Int) 0);
    }
    Int b=Ceil(t);
    return (b-t < sqrtFuzz) ? postdir(b) : 
      subpath(t,(double) b).postdir((Int) 0);
  }

  triple dir(double t) const {
    return unit(predir(t)+postdir(t));
  }

  triple dir(Int t, Int sign) const {
    if(sign == 0) return unit(predir(t)+postdir(t));
    else if(sign > 0) return postdir(t);
    else return predir(t);
  }

  triple postaccel(Int t) const {
    if(!cycles && t >= n-1) return triple(0,0,0);
    triple z0=point(t);
    triple c0=postcontrol(t);
    triple c1=precontrol(t+1);
    return 6.0*(z0+c1)-12.0*c0;
  }

  triple preaccel(Int t) const {
    if(!cycles && t <= 0) return triple(0,0,0);
    triple z0=point(t-1);
    triple c0=postcontrol(t-1);
    triple c1=precontrol(t);
    triple z1=point(t);
    return 6.0*(z1-z0)+18.0*(c0-c1);
  }
  
  triple preaccel(double t) const {
    if(!cycles) {
      if(t <= 0) return triple(0,0,0);
      if(t >= n-1) return preaccel(n-1);
    }
    Int a=Floor(t);
    return (t-a < sqrtFuzz) ? preaccel(a) : 
      subpath((double) a,t).preaccel((Int) 1);
  }

  triple postaccel(double t) const {
    if(!cycles) {
      if(t >= n-1) return triple(0,0,0);
      if(t <= 0) return postaccel((Int) 0);
    }
    Int b=Ceil(t);
    return (b-t < sqrtFuzz) ? postaccel(b) : 
      subpath(t,(double) b).postaccel((Int) 0);
  }

  triple accel(double t) const {
    return preaccel(t)+postaccel(t);
  }

  triple accel(Int t, Int sign) const {
    if(sign == 0) return preaccel(t)+postaccel(t);
    else if(sign > 0) return postaccel(t);
    else return preaccel(t);
  }

  // Returns the path3 traced out in reverse.
  path3 reverse() const;

  // Generates a path3 that is a section of the old path3, using the time
  // interval given.
  path3 subpath(Int start, Int end) const;
  path3 subpath(double start, double end) const;

  // Special case of subpath used by intersect.
  void halve(path3 &first, path3 &second) const;
  
  // Used by picture to determine bounding box.
  bbox3 bounds() const;
  
  triple mintimes() const {
    checkEmpty3(n);
    bounds();
    return camp::triple(times.left,times.bottom,times.lower);
  }
  
  triple maxtimes() const {
    checkEmpty3(n);
    bounds();
    return camp::triple(times.right,times.top,times.upper);
  }
  
  template<class T>
  void addpoint(bbox3& box, T i) const {
    box.addnonempty(point(i),times,(double) i);
  }

  double arclength () const;
  double arctime (double l) const;
 
  triple max() const {
    checkEmpty3(n);
    return bounds().Max();
  }

  triple min() const {
    checkEmpty3(n);
    return bounds().Min();
  }
  
// Increment count if the path3 has a vertical component at t.
  bool Count(Int& count, double t) const;
  
// Count if t is in (begin,end] and z lies to the left of point(i+t).
  void countleft(Int& count, double x, Int i, double t,
		 double begin, double end, double& mint, double& maxt) const;

// Return the winding number of the region bounded by the (cyclic) path3
// relative to the point z.
  Int windingnumber(const triple& z) const;

};

path3 transformed(vm::array *t, const path3& p);
  
extern path3 nullpath3;
extern const unsigned maxdepth;
 
bool intersect(double& S, double& T, path3& p, path3& q, double fuzz,
	       unsigned depth=maxdepth);
bool intersections(double& s, double& t, std::vector<double>& S,
		   std::vector<double>& T, path3& p, path3& q,
		   double fuzz, bool single, unsigned depth=maxdepth);
void intersections(std::vector<double>& S, path3& g,
		   const triple& p, const triple& q, double fuzz);

// Concatenates two path3s into a new one.
path3 concat(const path3& p1, const path3& p2);

// estimate the viewport fraction associated with the displacement d
inline double fraction(const triple& d, const triple& size)
{
  double s=fabs(d.getx()*size.getx())+fabs(d.gety()*size.gety())+
    fabs(d.getz()*size.getz());
  return s != 0.0 ? min((d.abs2()/s),1.0) : 0.0;
}

// return the perpendicular displacement of a point z from the line through 
// points p and q.
inline triple displacement(const triple& z, const triple& p, const triple& q)
{
  triple Z=z-p;
  triple Q=unit(q-p);
  return Z-dot(Z,Q)*Q;
}
  
struct Split3 {
  triple m0,m1,m2,m3,m4,m5;
  Split3(triple z0, triple c0, triple c1, triple z1) {
    m0=0.5*(z0+c0);
    m1=0.5*(c0+c1);
    m2=0.5*(c1+z1);
    m3=0.5*(m0+m1);
    m4=0.5*(m1+m2);
    m5=0.5*(m3+m4);
  }
};
  
double bound(double *p, double (*m)(double, double), double b,
	     int depth=maxdepth);
double bound(triple *p, double (*m)(double, double), double (*f)(triple),
	     double b, int depth=maxdepth);
}

// Delete the following line to work around problems with old broken compilers.
GC_DECLARE_PTRFREE(camp::solvedKnot3);

#endif
