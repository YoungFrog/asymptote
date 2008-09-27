private import math;

if(prc0()) {
  access embed;
  plain.embed=embed.embed;
  plain.link=embed.link;
}

real defaultshininess=0.25;
real defaultgranularity=0;
real linegranularity=0.01;
real dotgranularity=0.0001;
real anglefactor=1.08;       // Factor used to expand PRC viewing angle.
real fovfactor=0.6;          // PRC field of view factor.

string defaultembed3Doptions="3Drender=Solid,toolbar=true,";
string defaultembed3Dscript="";

triple O=(0,0,0);
triple X=(1,0,0), Y=(0,1,0), Z=(0,0,1);

// A translation in 3D space.
transform3 shift(triple v)
{
  transform3 t=identity(4);
  t[0][3]=v.x;
  t[1][3]=v.y;
  t[2][3]=v.z;
  return t;
}

// Avoid two parentheses.
transform3 shift(real x, real y, real z)
{
  return shift((x,y,z));
}

transform3 shift(transform3 t)
{
  transform3 T=identity(4);
  T[0][3]=t[0][3];
  T[1][3]=t[1][3];
  T[2][3]=t[2][3];
  return T;
}

// A 3D scaling in the x direction.
transform3 xscale3(real x)
{
  transform3 t=identity(4);
  t[0][0]=x;
  return t;
}

// A 3D scaling in the y direction.
transform3 yscale3(real y)
{
  transform3 t=identity(4);
  t[1][1]=y;
  return t;
}

// A 3D scaling in the z direction.
transform3 zscale3(real z)
{
  transform3 t=identity(4);
  t[2][2]=z;
  return t;
}

// A 3D scaling by s in the v direction.
transform3 scale(triple v, real s)
{
  v=unit(v);
  s -= 1;
  return new real[][] {
    {1+s*v.x^2, s*v.x*v.y, s*v.x*v.z, 0}, 
      {s*v.x*v.y, 1+s*v.y^2, s*v.y*v.z, 0}, 
        {s*v.x*v.z, s*v.y*v.z, 1+s*v.z^2, 0},
          {0, 0, 0, 1}};
}

// A transformation representing rotation by an angle in degrees about
// an axis v through the origin (in the right-handed direction).
transform3 rotate(real angle, triple v)
{
  if(v == O) abort("cannot rotate about the zero vector");
  v=unit(v);
  real x=v.x, y=v.y, z=v.z;
  real s=Sin(angle), c=Cos(angle), t=1-c;

  return new real[][] {
    {t*x^2+c,   t*x*y-s*z, t*x*z+s*y, 0},
      {t*x*y+s*z, t*y^2+c,   t*y*z-s*x, 0},
        {t*x*z-s*y, t*y*z+s*x, t*z^2+c,   0},
          {0,         0,         0,         1}};
}

// A transformation representing rotation by an angle in degrees about
// the line u--v (in the right-handed direction).
transform3 rotate(real angle, triple u, triple v)
{
  return shift(u)*rotate(angle,v-u)*shift(-u);
}

// Reflects about the plane through u, v, and w.
transform3 reflect(triple u, triple v, triple w)
{
  triple n=unit(cross(v-u,w-u));
  if(n == O)
    abort("points determining reflection plane cannot be colinear");

  return new real[][] {
    {1-2*n.x^2, -2*n.x*n.y, -2*n.x*n.z, u.x},
      {-2*n.x*n.y, 1-2*n.y^2, -2*n.y*n.z, u.y},
        {-2*n.x*n.z, -2*n.y*n.z, 1-2*n.z^2, u.z},
          {0, 0, 0, 1}
  }*shift(-u);
}

bool operator != (real[][] a, real[][] b) {
  return !(a == b);
}

// Project u onto v.
triple project(triple u, triple v)
{
  v=unit(v);
  return dot(u,v)*v;
}

// Return the transformation corresponding to moving the camera from the target
// (looking in the negative z direction) to the point 'eye' (looking at target),
// orienting the camera so that direction 'up' points upwards.
// Since, in actuality, we are transforming the points instead of the camera,
// we calculate the inverse matrix.
// Based on the gluLookAt implementation in the OpenGL manual.
transform3 look(triple eye, triple up=Z, triple target=O)
{
  triple f=unit(target-eye);
  if(f == O)
    f=-Z; // The eye is already at the origin: look down.

  triple side=cross(f,up);
  if(side == O) {
    // The eye is pointing either directly up or down, so there is no
    // preferred "up" direction to rotate it.  Pick one arbitrarily.
    side=cross(f,Y);
    if(side == O) side=cross(f,Z);
  }
  triple s=unit(side);

  triple u=cross(s,f);

  transform3 M={{ s.x,  s.y,  s.z, 0},
                { u.x,  u.y,  u.z, 0},
                {-f.x, -f.y, -f.z, 0},
                {   0,    0,    0, 1}};

  return M*shift(-eye);
}

// Return a matrix to do perspective distortion based on a triple v.
transform3 distort(triple v) 
{
  transform3 t=identity(4);
  real d=length(v);
  if(d == 0) return t;
  t[3][2]=-1/d;
  t[3][3]=0;
  return t;
}

projection operator * (transform3 t, projection P)
{
  projection P=P.copy();
  if(!P.absolute) {
    P.camera=t*P.camera;
    P.target=t*P.target;
    P.calculate();
  }
  return P;
}

// With this, save() and restore() in plain also save and restore the
// currentprojection.
addSaveFunction(new restoreThunk() {
    projection P=currentprojection.copy();
    return new void() {
      currentprojection=P;
    };
  });

pair project(triple v, projection P=currentprojection)
{
  return project(v,P.t);
}

// Uses the homogenous coordinate to perform perspective distortion.
// When combined with a projection to the XY plane, this effectively maps
// points in three space to a plane through target and
// perpendicular to the vector camera-target.
projection perspective(triple camera, triple up=Z, triple target=O)
{
  return projection(camera,target,up,
                    new transformation(triple camera, triple up, triple target)
                    {   return transformation(look(camera,up,target),
                                              distort(camera-target));});
}

projection perspective(real x, real y, real z, triple up=Z, triple target=O)
{
  return perspective((x,y,z),up,target);
}

projection orthographic(triple camera, triple up=Z, triple target=O)
{
  return projection(camera,target,up,
                    new transformation(triple camera, triple up,
                                       triple target) {
                      return transformation(look(camera,up,target));});
}

projection orthographic(real x, real y, real z, triple up=Z)
{
  return orthographic((x,y,z),up);
}

projection oblique(real angle=45)
{
  transform3 t=identity(4);
  real c2=Cos(angle)^2;
  real s2=1-c2;
  t[0][2]=-c2;
  t[1][2]=-s2;
  t[2][2]=1;
  return projection((0,0,1),up=Y,
                    new transformation(triple,triple,triple) {
                      return transformation(t,oblique=true);});
}

projection obliqueZ(real angle=45) {return oblique(angle);}

projection obliqueX(real angle=45)
{
  transform3 t=identity(4);
  real c2=Cos(angle)^2;
  real s2=1-c2;
  t[0][0]=-c2;
  t[1][0]=-s2;
  t[1][1]=0;
  t[0][1]=1;
  t[1][2]=1;
  t[2][2]=0;
  t[2][0]=1;
  return projection((1,0,0),
                    new transformation(triple,triple,triple) {
                      return transformation(t,oblique=true);});
}

projection obliqueY(real angle=45)
{
  transform3 t=identity(4);
  real c2=Cos(angle)^2;
  real s2=1-c2;
  t[0][1]=c2;
  t[1][1]=s2;
  t[1][2]=1;
  t[2][1]=-1;
  t[2][2]=0;
  return projection((0,-1,0),
                    new transformation(triple,triple,triple) {
                      return transformation(t,oblique=true);});
}

projection oblique=oblique();
projection obliqueX=obliqueX(), obliqueY=obliqueY(), obliqueZ=obliqueZ();

currentprojection=perspective(5,4,2);

// Map pair z onto a triple by inverting the projection P onto the 
// plane perpendicular to normal and passing through point.
triple invert(pair z, triple normal, triple point,
              projection P=currentprojection)
{
  transform3 t=P.t;
  real[][] A={{t[0][0]-z.x*t[3][0],t[0][1]-z.x*t[3][1],t[0][2]-z.x*t[3][2]},
              {t[1][0]-z.y*t[3][0],t[1][1]-z.y*t[3][1],t[1][2]-z.y*t[3][2]},
              {normal.x,normal.y,normal.z}};
  real[] b={z.x*t[3][3]-t[0][3],z.y*t[3][3]-t[1][3],dot(normal,point)};
  real[] x=solve(A,b,warn=false);
  return x.length > 0 ? (x[0],x[1],x[2]) : P.camera;
}

pair xypart(triple v)
{
  return (v.x,v.y);
}

struct control {
  triple post,pre;
  bool active=false;
  void init(triple post, triple pre) {
    this.post=post;
    this.pre=pre;
    active=true;
  }
}

control nocontrol;
  
control operator * (transform3 t, control c) 
{
  control C;
  C.post=t*c.post;
  C.pre=t*c.pre;
  C.active=c.active;
  return C;
}

void write(file file, control c)
{
  write(file,".. controls ");
  write(file,c.post);
  write(file," and ");
  write(file,c.pre);
}
  
struct Tension {
  real out,in;
  bool atLeast;
  bool active;
  void init(real out=1, real in=1, bool atLeast=false, bool active=true) {
    real check(real val) {
      if(val < 0.75) abort("tension cannot be less than 3/4");
      return val;
    }
    this.out=check(out);
    this.in=check(in);
    this.atLeast=atLeast;
    this.active=active;
  }
}

Tension operator init()
{
  Tension t=new Tension;
  t.init(false);
  return t;
}

Tension noTension;
noTension.active=false;
  
void write(file file, Tension t)
{
  write(file,"..tension ");
  if(t.atLeast) write(file,"atleast ");
  write(file,t.out);
  write(file," and ");
  write(file,t.in);
}
  
struct dir {
  triple dir;
  real gamma=1; // endpoint curl
  bool Curl;    // curl specified
  bool active() {
    return dir != O || Curl;
  }
  void init(triple v) {
    this.dir=v;
  }
  void init(real gamma) {
    if(gamma < 0) abort("curl cannot be less than 0");
    this.gamma=gamma;
    this.Curl=true;
  }
  void init(dir d) {
    dir=d.dir;
    gamma=d.gamma;
    Curl=d.Curl;
  }
  void default(triple v) {
    if(!active()) init(v);
  }
  void default(dir d) {
    if(!active()) init(d);
  }
  dir copy() {
    dir d=new dir;
    d.init(this);
    return d;
  }
}

void write(file file, dir d)
{
  if(d.dir != O) {
    write(file,"{"); write(file,unit(d.dir)); write(file,"}");
  } else if(d.Curl) {
    write(file,"{curl "); write(file,d.gamma); write(file,"}");
  }
}
  
dir operator * (transform3 t, dir d) 
{
  dir D=d.copy();
  D.init(unit(shiftless(t)*d.dir));
  return D;
}

void checkEmpty(int n) {
  if(n == 0)
    abort("nullpath3 has no points");
}

int adjustedIndex(int i, int n, bool cycles)
{
  checkEmpty(n);
  if(cycles)
    return i % n;
  else if(i < 0)
    return 0;
  else if(i >= n)
    return n-1;
  else
    return i;
}

struct flatguide3 {
  triple[] nodes;
  bool[] cyclic;     // true if node is really a cycle
  control[] control; // control points for segment starting at node
  Tension[] Tension; // Tension parameters for segment starting at node
  dir[] in,out;      // in and out directions for segment starting at node

  bool cyclic() {return cyclic[cyclic.length-1];}
  
  int size() {
    return cyclic() ? nodes.length-1 : nodes.length;
  }
  
  void node(triple v, bool b=false) {
    nodes.push(v);
    control.push(nocontrol);
    Tension.push(noTension);
    in.push(new dir);
    out.push(new dir);
    cyclic.push(b);
  }

  void control(triple post, triple pre) {
    if(control.length > 0) {
      control c;
      c.init(post,pre);
      control[control.length-1]=c;
    }
  }

  void Tension(real out, real in, bool atLeast) {
    if(Tension.length > 0) {
      Tension t;
      t.init(out,in,atLeast);
      Tension[Tension.length-1]=t;
    }
  }

  void in(triple v) {
    if(in.length > 0) {
      in[in.length-1].init(v);
    }
  }

  void out(triple v) {
    if(out.length > 0) {
      out[out.length-1].init(v);
    }
  }

  void in(real gamma) {
    if(in.length > 0) {
      in[in.length-1].init(gamma);
    }
  }

  void out(real gamma) {
    if(out.length > 0) {
      out[out.length-1].init(gamma);
    }
  }

  void cycleToken() {
    if(nodes.length > 0)
      node(nodes[0],true);
  }
  
  // Return true if outgoing direction at node i is known.
  bool solved(int i) {
    return out[i].active() || control[i].active;
  }
}

void write(file file, string s="", explicit flatguide3 x, suffix suffix=none)
{
  write(file,s);
  if(x.size() == 0) write(file,"<nullpath3>");
  else for(int i=0; i < x.nodes.length; ++i) {
      if(i > 0) write(file,endl);
      if(x.cyclic[i]) write(file,"cycle");
      else write(file,x.nodes[i]);
      if(i < x.nodes.length-1) {
        // Explicit control points trump other specifiers
        if(x.control[i].active)
          write(file,x.control[i]);
        else {
          write(file,x.out[i]);
          if(x.Tension[i].active) write(file,x.Tension[i]);
        }
        write(file,"..");
        if(!x.control[i].active) write(file,x.in[i]);
      }
    }
  write(file,suffix);
}

void write(string s="", flatguide3 x, suffix suffix=endl)
{
  write(stdout,s,x,suffix);
}

// A guide3 is most easily represented as something that modifies a flatguide3.
typedef void guide3(flatguide3);

restricted void nullpath3(flatguide3) {};

guide3 operator init() {return nullpath3;}

guide3 operator cast(triple v)
{
  return new void(flatguide3 f) {
    f.node(v);
  };
}

guide3 operator cast(cycleToken) {
  return new void(flatguide3 f) {
    f.cycleToken();
  };
}

guide3 operator controls(triple post, triple pre) 
{
  return new void(flatguide3 f) {
    f.control(post,pre);
  };
};
  
guide3 operator controls(triple v)
{
  return operator controls(v,v);
}

guide3 operator cast(tensionSpecifier t)
{
  return new void(flatguide3 f) {
    f.Tension(t.out, t.in, t.atLeast);
  };
}

guide3 operator cast(curlSpecifier spec)
{
  return new void(flatguide3 f) {
    if(spec.side == JOIN_OUT) f.out(spec.value);
    else if(spec.side == JOIN_IN) f.in(spec.value);
    else
      abort("invalid curl specifier");
  };
}

guide3 operator spec(triple v, int side)
{
  return new void(flatguide3 f) {
    if(side == JOIN_OUT) f.out(v);
    else if(side == JOIN_IN) f.in(v);
    else
      abort("invalid direction specifier");
  };
}
  
guide3 operator -- (... guide3[] g)
{
  return new void(flatguide3 f) {
    if(g.length > 0) {
      for(int i=0; i < g.length-1; ++i) {
        g[i](f);
        f.out(1);
        f.in(1);
      }
      g[g.length-1](f);
    }
  };
}

guide3 operator .. (... guide3[] g)
{
  return new void(flatguide3 f) {
    for(int i=0; i < g.length; ++i)
      g[i](f);
  };
}

guide3 operator ::(... guide3[] a)
{
  if(a.length == 0) return nullpath3;
  guide3 g=a[0];
  for(int i=1; i < a.length; ++i)
    g=g.. tension atleast 1 ..a[i];
  return g;
}

guide3 operator ---(... guide3[] a)
{
  if(a.length == 0) return nullpath3;
  guide3 g=a[0];
  for(int i=1; i < a.length; ++i)
    g=g.. tension atleast infinity ..a[i];
  return g;
}

flatguide3 operator cast(guide3 g)
{
  flatguide3 f;
  g(f);
  return f;
}

flatguide3[] operator cast(guide3[] g)
{
  flatguide3[] p=new flatguide3[g.length];
  for(int i=0; i < g.length; ++i) {
    flatguide3 f;
    g[i](f);
    p[i]=f;
  }
  return p;
}

// A version of acos that tolerates numerical imprecision
real acos1(real x)
{
  if(x < -1) x=-1;
  if(x > 1) x=1;
  return acos(x);
}
  
struct Controls {
  triple c0,c1;

  // 3D extension of John Hobby's control point formula
  // (cf. The MetaFont Book, page 131),
  // as described in John C. Bowman and A. Hammerlindl,
  // TUGBOAT: The Communications of th TeX Users Group 29:2 (2008).

  void init(triple v0, triple v1, triple d0, triple d1, real tout, real tin,
            bool atLeast) {
    triple v=v1-v0;
    triple u=unit(v);
    real L=length(v);
    d0=unit(d0);
    d1=unit(d1);
    real theta=acos1(dot(d0,u));
    real phi=acos1(dot(d1,u));
    if(dot(cross(d0,v),cross(v,d1)) < 0) phi=-phi;
    c0=v0+d0*L*relativedistance(theta,phi,tout,atLeast);
    c1=v1-d1*L*relativedistance(phi,theta,tin,atLeast);
  }
}

private triple cross(triple d0, triple d1, triple reference)
{
  triple normal=cross(d0,d1);
  return normal == O ? reference : normal;
}
                                        
private triple dir(real theta, triple d0, triple d1, triple reference)
{
  triple normal=cross(d0,d1,reference);
  if(normal == O) return d1;
  return rotate(degrees(theta),dot(normal,reference) >= 0 ? normal : -normal)*
    d1;
}

private real angle(triple d0, triple d1, triple reference)
{
  real theta=acos1(dot(unit(d0),unit(d1)));
  return dot(cross(d0,d1,reference),reference) >= 0 ? theta : -theta;
}

// 3D extension of John Hobby's angle formula (The MetaFont Book, page 131).
// Notational differences: here psi[i] is the turning angle at z[i+1],
// beta[i] is the tension for segment i, and in[i] is the incoming
// direction for segment i (where segment i begins at node i).

real[] theta(triple[] v, real[] alpha, real[] beta, 
             triple dir0, triple dirn, real g0, real gn, triple reference)
{
  real[] a,b,c,f,l,psi;
  int n=alpha.length;
  bool cyclic=v.cyclicflag;
  for(int i=0; i < n; ++i)
    l[i]=1/length(v[i+1]-v[i]);
  int i0,in;
  if(cyclic) {i0=0; in=n;}
  else {i0=1; in=n-1;}
  for(int i=0; i < in; ++i)
    psi[i]=angle(v[i+1]-v[i],v[i+2]-v[i+1],reference);
  if(cyclic) {
    l.cyclic(true);
    psi.cyclic(true);
  } else {
    psi[n-1]=0;
    if(dir0 == O) {
      real a0=alpha[0];
      real b0=beta[0];
      real chi=g0*(b0/a0)^2;
      a[0]=0;
      b[0]=3a0-a0/b0+chi;
      real C=chi*(3a0-1)+a0/b0;
      c[0]=C;
      f[0]=-C*psi[0];
    } else {
      a[0]=c[0]=0;
      b[0]=1;
      f[0]=angle(v[1]-v[0],dir0,reference);
    }
    if(dirn == O) {
      real an=alpha[n-1];
      real bn=beta[n-1];
      real chi=gn*(an/bn)^2;
      a[n]=chi*(3bn-1)+bn/an;
      b[n]=3bn-bn/an+chi;
      c[n]=f[n]=0;
    } else {
      a[n]=c[n]=0;
      b[n]=1;
      f[n]=angle(v[n]-v[n-1],dirn,reference);
    }
  }
  
  for(int i=i0; i < n; ++i) {
    real in=beta[i-1]^2*l[i-1];
    real A=in/alpha[i-1];
    a[i]=A;
    real B=3*in-A;
    real out=alpha[i]^2*l[i];
    real C=out/beta[i];
    b[i]=B+3*out-C;
    c[i]=C;
    f[i]=-B*psi[i-1]-C*psi[i];
  }
  
  return tridiagonal(a,b,c,f);
}

triple reference(triple[] v, int n, triple d0, triple d1)
{
  triple[] V;
  
  for(int i=1; i < n; ++i)
    V.push(cross(v[i]-v[i-1],v[i+1]-v[i])); 
  if(n > 0) {
    V.push(cross(d0,v[1]-v[0]));
    V.push(cross(v[n]-v[n-1],d1));
  }

  triple max=V[0];
  real M=abs(max);
  for(int i=1; i < V.length; ++i) {
    triple vi=V[i];
    real a=abs(vi);
    if(a > M) {
      M=a;
      max=vi;
    }
  }

  triple reference;
  for(int i=0; i < V.length; ++i) {
    triple u=unit(V[i]);
    reference += dot(u,max) < 0 ? -u : u;
  }

  return reference;
}

// Fill in missing directions for n cyclic nodes.
void aim(flatguide3 g, int N) 
{
  bool cyclic=true;
  int start=0, end=0;
  
  // If the cycle contains one or more direction specifiers, break the loop.
  for(int k=0; k < N; ++k)
    if(g.solved(k)) {cyclic=false; end=k; break;}
  for(int k=N-1; k >= 0; --k)
    if(g.solved(k)) {cyclic=false; start=k; break;}
  while(start < N && g.control[start].active) ++start;
  
  int n=N-(start-end);
  if(n <= 1 || (cyclic && n <= 2)) return;

  triple[] v=new triple[cyclic ? n : n+1];
  real[] alpha=new real[n];
  real[] beta=new real[n];
  for(int k=0; k < n; ++k) {
    int K=(start+k) % N;
    v[k]=g.nodes[K];
    alpha[k]=g.Tension[K].out;
    beta[k]=g.Tension[K].in;
  }
  if(cyclic) {
    v.cyclic(true);
    alpha.cyclic(true);
    beta.cyclic(true);
  } else v[n]=g.nodes[(start+n) % N];
  int final=(end-1) % N;

  triple d0=g.out[start].dir;
  triple d1=g.in[final].dir;

  triple reference=reference(v,n,d0,d1);

  real[] theta=theta(v,alpha,beta,d0,d1,g.out[start].gamma,g.in[final].gamma,
                     reference);

  v.cyclic(true);
  theta.cyclic(true);
    
  for(int k=1; k < (cyclic ? n+1 : n); ++k) {
    triple w=dir(theta[k],v[k]-v[k-1],v[k+1]-v[k],reference);
    g.in[(start+k-1) % N].init(w);
    g.out[(start+k) % N].init(w);
  }

  if(g.out[start].dir == O)
    g.out[start].init(dir(theta[0],v[0]-g.nodes[(start-1) % N],v[1]-v[0],
                          reference));
  if(g.in[final].dir == O)
    g.in[final].init(dir(theta[n],v[n-1]-v[n-2],v[n]-v[n-1],reference));
}

// Fill in missing directions for the sequence of nodes i...n.
void aim(flatguide3 g, int i, int n) 
{
  int j=n-i;
  if(j > 1 || g.out[i].dir != O || g.in[i].dir != O) {
    triple[] v=new triple[j+1];
    real[] alpha=new real[j];
    real[] beta=new real[j];
    for(int k=0; k < j; ++k) {
      v[k]=g.nodes[i+k];
      alpha[k]=g.Tension[i+k].out;
      beta[k]=g.Tension[i+k].in;
    }
    v[j]=g.nodes[n];
    
    triple d0=g.out[i].dir;
    triple d1=g.in[n-1].dir;

    triple reference=reference(v,j,d0,d1);

    real[] theta=theta(v,alpha,beta,d0,d1,g.out[i].gamma,g.in[n-1].gamma,
                       reference);
    
    for(int k=1; k < j; ++k) {
      triple w=dir(theta[k],v[k]-v[k-1],v[k+1]-v[k],reference);
      g.in[i+k-1].init(w);
      g.out[i+k].init(w);
    }
    if(g.out[i].dir == O) {
      triple w=dir(theta[0],g.in[i].dir,v[1]-v[0],reference);
      if(i > 0) g.in[i-1].init(w);
      g.out[i].init(w);
    }
    if(g.in[n-1].dir == O) {
      triple w=dir(theta[j],g.out[n-1].dir,v[j]-v[j-1],reference);
      g.in[n-1].init(w);
      g.out[n].init(w);
    }
  }
}

private real Fuzz=10*realEpsilon;

triple XYplane(pair z) {return (z.x,z.y,0);}
triple YZplane(pair z) {return (0,z.x,z.y);}
triple ZXplane(pair z) {return (z.y,0,z.x);}

bool cyclic(guide3 g) {flatguide3 f; g(f); return f.cyclic();}
int size(guide3 g) {flatguide3 f; g(f); return f.size();}
int length(guide3 g) {flatguide3 f; g(f); return f.nodes.length-1;}

path3 path3(triple v)
{
  triple[] point={v};
  return path3(point,point,point,new bool[] {false},false);
}

path3 path3(path p, triple plane(pair)=XYplane)
{
  int n=size(p);
  triple[] pre=new triple[n];
  triple[] point=new triple[n];
  triple[] post=new triple[n];
  bool[] straight=new bool[n];
  for(int i=0; i < n; ++i) {
    pre[i]=plane(precontrol(p,i));
    point[i]=plane(point(p,i));
    post[i]=plane(postcontrol(p,i));
    straight[i]=straight(p,i);
  }
  return path3(pre,point,post,straight,cyclic(p));
}

path3[] path3(path[] g, triple plane(pair)=XYplane)
{
  return sequence(new path3(int i) {return path3(g[i],plane);},g.length);
}

path3[] operator * (transform3 t, path3[] p) 
{
  path3[] g=new path3[p.length];
  for(int i=0; i < p.length; ++i)
    g[i]=t*p[i];
  return g;
}

void write(file file, string s="", explicit path3 x, suffix suffix=none)
{
  write(file,s);
  int n=size(x);
  if(n == 0) write("<nullpath3>");
  else for(int i=0; i < n; ++i) {
      write(file,point(x,i));
      if(i < length(x)) {
        if(straight(x,i)) write(file,"--");
        else {
          write(file,".. controls ");
          write(file,postcontrol(x,i));
          write(file," and ");
          write(file,precontrol(x,i+1));
          write(file,"..",endl);
        }
        if(i == n-1 && cyclic(x)) write(file,"cycle");
      }
    }
  write(file,suffix);
}

void write(string s="", explicit path3 x, suffix suffix=endl)
{
  write(stdout,s,x,suffix);
}

void write(file file, string s="", explicit path3[] x, suffix suffix=none)
{
  write(file,s);
  if(x.length > 0) write(file,x[0]);
  for(int i=1; i < x.length; ++i) {
    write(file,endl);
    write(file," ^^");
    write(file,x[i]);
  }
  write(file,suffix);
}

void write(string s="", explicit path3[] x, suffix suffix=endl)
{
  write(stdout,s,x,suffix);
}

path3 solve(flatguide3 g)
{
  int n=g.nodes.length-1;

  // If duplicate points occur consecutively, add dummy controls (if absent).
  for(int i=0; i < n; ++i) {
    if(g.nodes[i] == g.nodes[i+1] && !g.control[i].active) {
      control c;
      c.init(g.nodes[i],g.nodes[i]);
      g.control[i]=c;
    }
  }  
  
  // Fill in empty direction specifiers inherited from explicit control points.
  for(int i=0; i < n; ++i) {
    if(g.control[i].active) {
      g.out[i].default(g.control[i].post-g.nodes[i]);
      g.in[i].default(g.nodes[i+1]-g.control[i].pre);
    }
  }  
  
  // Propagate directions across nodes.
  for(int i=0; i < n; ++i) {
    int next=g.cyclic[i+1] ? 0 : i+1;
    if(g.out[next].active())
      g.in[i].default(g.out[next]);
    if(g.in[i].active()) {
      g.out[next].default(g.in[i]);
      g.out[i+1].default(g.in[i]);
    }
  }  
    
  // Compute missing 3D directions.
  // First, resolve cycles
  int i=find(g.cyclic);
  if(i > 0) {
    aim(g,i);
    // All other cycles can now be reduced to sequences.
    triple v=g.out[0].dir;
    for(int j=i; j <= n; ++j) {
      if(g.cyclic[j]) {
        g.in[j-1].default(v);
        g.out[j].default(v);
        if(g.nodes[j-1] == g.nodes[j] && !g.control[j-1].active) {
          control c;
          c.init(g.nodes[j-1],g.nodes[j-1]);
          g.control[j-1]=c;
        }
      }
    }
  }
    
  // Next, resolve sequences.
  int i=0;
  int start=0;
  while(i < n) {
    // Look for a missing outgoing direction.
    while(i <= n && g.solved(i)) {start=i; ++i;}
    if(i > n) break;
    // Look for the end of the sequence.
    while(i < n && !g.solved(i)) ++i;
    
    while(start < i && g.control[start].active) ++start;
    
    if(start < i) 
      aim(g,start,i);
  }
  
  // Compute missing 3D control points.
  for(int i=0; i < n; ++i) {
    int next=g.cyclic[i+1] ? 0 : i+1;
    if(!g.control[i].active) {
      control c;
      if((g.out[i].Curl && g.in[i].Curl) ||
         (g.out[i].dir == O && g.in[i].dir == O)) {
        // fill in straight control points for path3 functions
        triple delta=(g.nodes[i+1]-g.nodes[i])/3;
        c.init(g.nodes[i]+delta,g.nodes[i+1]-delta);
        c.active=false;
      } else {
        Controls C;
        C.init(g.nodes[i],g.nodes[next],g.out[i].dir,g.in[i].dir,
               g.Tension[i].out,g.Tension[i].in,g.Tension[i].atLeast);
        c.init(C.c0,C.c1);
      }
      g.control[i]=c;
    }
  }

  // Convert to Knuth's format (control points stored with nodes)
  int n=g.nodes.length;
  bool cyclic;
  if(n > 0) {
    cyclic=g.cyclic[n-1];
    if(cyclic) --n;
  }
  triple[] pre=new triple[n];
  triple[] point=new triple[n];
  triple[] post=new triple[n];
  bool[] straight=new bool[n];
  if(n == 0) return path3(pre,point,post,straight,cyclic);
  for(int i=0; i < n-1; ++i) {
    point[i]=g.nodes[i];
    post[i]=g.control[i].post;
    pre[i+1]=g.control[i].pre;
    straight[i]=!g.control[i].active;
  }
  point[n-1]=g.nodes[n-1];
  if(cyclic) {
    pre[0]=g.control[n-1].pre;
    post[n-1]=g.control[n-1].post;
    straight[n-1]=!g.control[n-1].active;
  } else {
    pre[0]=point[0];
    post[n-1]=point[n-1];
    straight[n-1]=false;
  }

  return path3(pre,point,post,straight,cyclic);
}

path nurb(path3 p, projection P, int ninterpolate=P.ninterpolate)
{
  triple f=P.camera;
  triple u=unit(P.vector());
  transform3 t=P.t;

  path nurb(triple v0, triple v1, triple v2, triple v3) {
    return nurb(project(v0,t),project(v1,t),project(v2,t),project(v3,t),
                dot(u,f-v0),dot(u,f-v1),dot(u,f-v2),dot(u,f-v3),ninterpolate);
  }

  path g;

  if(straight(p,0))
    g=project(point(p,0),t);

  int last=length(p);
  for(int i=0; i < last; ++i) {
    if(straight(p,i))
      g=g--project(point(p,i+1),t);
    else
      g=g&nurb(point(p,i),postcontrol(p,i),precontrol(p,i+1),point(p,i+1));
  }

  int n=length(g);
  if(cyclic(p)) g=g&cycle;

  return g;
}

path project(path3 p, projection P=currentprojection,
             int ninterpolate=P.ninterpolate)
{
  guide g;

  int last=length(p);
  if(last < 0) return g;
  
  transform3 t=P.t;

  if(P.infinity || ninterpolate == 1 || piecewisestraight(p)) {
    g=project(point(p,0),t);
    // Construct the path.
    int stop=cyclic(p) ? last-1 : last;
    for(int i=0; i < stop; ++i) {
      if(straight(p,i))
        g=g--project(point(p,i+1),t);
      else {
        g=g..controls project(postcontrol(p,i),t) and
          project(precontrol(p,i+1),t)..project(point(p,i+1),t);
      }
    }
  } else return nurb(p,P);
  
  if(cyclic(p))
    g=straight(p,last-1) ? g--cycle :
      g..controls project(postcontrol(p,last-1),t) and
      project(precontrol(p,last),t)..cycle;
  return g;
}

pair[] project(triple[] v, projection P=currentprojection)
{
  transform3 t=P.t;
  int n=v.length;
  pair[] z=new pair[n];
  for(int i=0; i < n; ++i)
    z[i]=project(v[i],t);
  return z;
}

path[] project(path3[] g, projection P=currentprojection)
{
  path[] p=new path[g.length];
  for(int i=0; i < g.length; ++i) 
    p[i]=project(g[i],P);
  return p;
}
  
guide3 operator cast(path3 p)
{
  int last=length(p);
  
  bool cyclic=cyclic(p);
  int stop=cyclic ? last-1 : last;
  return new void(flatguide3 f) {
    if(last >= 0) {
      f.node(point(p,0));
      for(int i=0; i < stop; ++i) {
        if(straight(p,i)) {
          f.out(1);
          f.in(1);
        } else
          f.control(postcontrol(p,i),precontrol(p,i+1));
        f.node(point(p,i+1));
      }
      if(cyclic) {
        if(straight(p,stop)) {
          f.out(1);
          f.in(1);
        } else
          f.control(postcontrol(p,stop),precontrol(p,last));
        f.cycleToken();
      }
    }
  };
}

// Transforms that map XY plane to YX, YZ, ZY, ZX, and XZ planes.
restricted transform3 XY=identity4;
restricted transform3 YX=rotate(-90,O,Z);
restricted transform3 YZ=rotate(90,O,Z)*rotate(90,O,X);
restricted transform3 ZY=rotate(-90,O,X)*YZ;
restricted transform3 ZX=rotate(-90,O,Z)*rotate(-90,O,Y);
restricted transform3 XZ=rotate(-90,O,Y)*ZX;

private transform3 flip(transform3 t, triple X, triple Y, triple Z,
                        projection P)
{
  static transform3 flip(triple v) {
    static real s(real x) {return x > 0 ? -1 : 1;}
    return scale(s(v.x),s(v.y),s(v.z));
  }

  triple u=unit(P.vector());
  triple up=unit(P.up-dot(P.up,u)*u);
  bool upright=dot(Z,u) >= 0;
  if(dot(Y,up) < 0) {
    t=flip(Y)*t;
    upright=!upright;
  }
  return upright ? t : flip(X)*t;
}

restricted transform3 XY(projection P=currentprojection)
{
  return flip(XY,X,Y,Z,P);
}

restricted transform3 YX(projection P=currentprojection)
{
  return flip(YX,Y,X,Z,P);
}

restricted transform3 YZ(projection P=currentprojection)
{
  return flip(YZ,Y,Z,X,P);
}

restricted transform3 ZY(projection P=currentprojection)
{
  return flip(ZY,Z,Y,X,P);
}

restricted transform3 ZX(projection P=currentprojection)
{
  return flip(ZX,Z,X,Y,P);
}

restricted transform3 XZ(projection P=currentprojection)
{
  return flip(XZ,X,Z,Y,P);
}

// Transform for projecting onto plane through point O with normal cross(u,v).
transform transform(triple u, triple v, triple O=O,
                    projection P=currentprojection)
{
  transform3 t=P.t;
  static real[] O={0,0,0,1};
  real[] tO=t*O;
  real tO3=tO[3];
  real factor=1/tO3^2;
  real[] x=(tO3*t[0]-tO[0]*t[3])*factor;
  real[] y=(tO3*t[1]-tO[1]*t[3])*factor;
  triple x=(x[0],x[1],x[2]);
  triple y=(y[0],y[1],y[2]);
  u=unit(u);
  v=unit(v);
  return (0,0,dot(u,x),dot(v,x),dot(u,y),dot(v,y));
}

// Project Label onto plane through point O with normal cross(u,v).
Label project(Label L, triple u, triple v, triple O=O,
              projection P=currentprojection) {
  Label L=L.copy();
  L.position=project(O,P.t);
  L.transform(transform(u,v,O,P)); 
  return L;
}

path3 operator cast(guide3 g) {return solve(g);}
path3 operator cast(triple v) {return path3(v);}

guide3[] operator cast(triple[] v)
{
  guide3[] g=new guide3[v.length];
  for(int i=0; i < v.length; ++i)
    g[i]=v[i];
  return g;
}

path3[] operator cast(triple[] v)
{
  path3[] g=new path3[v.length];
  for(int i=0; i < v.length; ++i)
    g[i]=v[i];
  return g;
}

triple point(explicit guide3 g, int t) {
  flatguide3 f;
  g(f);
  int n=f.size();
  return f.nodes[adjustedIndex(t,n,f.cyclic())];
}

triple[] dirSpecifier(guide3 g, int t)
{
  flatguide3 f;
  g(f);
  bool cyclic=f.cyclic();
  int n=f.size();
  checkEmpty(n);
  if(cyclic) t=t % n;
  else if(t < 0 || t >= n-1) return new triple[] {O,O};
  return new triple[] {f.out[t].dir,f.in[t].dir};
}

triple[] controlSpecifier(guide3 g, int t) {
  flatguide3 f;
  g(f);
  bool cyclic=f.cyclic();
  int n=f.size();
  checkEmpty(n);
  if(cyclic) t=t % n;
  else if(t < 0 || t >= n-1) return new triple[];
  control c=f.control[t];
  if(c.active) return new triple[] {c.post,c.pre};
  else return new triple[];
}

tensionSpecifier tensionSpecifier(guide3 g, int t)
{
  flatguide3 f;
  g(f);
  bool cyclic=f.cyclic();
  int n=f.size();
  checkEmpty(n);
  if(cyclic) t=t % n;
  else if(t < 0 || t >= n-1) return operator tension(1,1,false);
  Tension T=f.Tension[t];
  return operator tension(T.out,T.in,T.atLeast);
}

real[] curlSpecifier(guide3 g)
{
  flatguide3 f;
  g(f);
  return new real[] {f.out[0].gamma,f.in[f.nodes.length-2].gamma};
}

triple intersectionpoint(path3 p, path3 q, real fuzz=0)
{
  real[] t=intersect(p,q,fuzz);
  if(t.length == 0) abort("paths do not intersect");
  return point(p,t[0]);
}

// return an array containing all intersection points of p and q
triple[] intersectionpoints(path3 p, path3 q, real fuzz=0)
{
  real[][] t=intersections(p,q,fuzz);
  triple[] v=new triple[t.length];
  for(int i=0; i < t.length; ++i)
    v[i]=point(p,t[i][0]);
  return v;
}

path3 operator &(path3 p, cycleToken tok)
{
  int n=length(p);
  if(n < 0) return nullpath3;
  triple a=point(p,0);
  triple b=point(p,n);
  return subpath(p,0,n-1)..controls postcontrol(p,n-1) and precontrol(p,n)..
    cycle;
}

// return the point on path3 p at arclength L
triple arcpoint(path3 p, real L)
{
  return point(p,arctime(p,L));
}

// return the point on path3 p at arclength L
triple arcpoint(path3 p, real L)
{
  return point(p,arctime(p,L));
}

// return the direction on path3 p at arclength L
triple arcdir(path3 p, real L)
{
  return dir(p,arctime(p,L));
}

// return the time on path3 p at the relative fraction l of its arclength
real reltime(path3 p, real l)
{
  return arctime(p,l*arclength(p));
}

// return the point on path3 p at the relative fraction l of its arclength
triple relpoint(path3 p, real l)
{
  return point(p,reltime(p,l));
}

// return the direction of path3 p at the relative fraction l of its arclength
triple reldir(path3 p, real l)
{
  return dir(p,reltime(p,l));
}

// return the point on path3 p at half of its arclength
triple midpoint(path3 p)
{
  return relpoint(p,0.5);
}

real relative(Label L, path3 g)
{
  return L.position.relative ? reltime(g,L.relative()) : L.relative();
}

// return the linear transformation that maps X,Y,Z to u,v,w.
transform3 transform3(triple u, triple v, triple w=cross(u,v)) 
{
  return new real[][] {
    {u.x,v.x,w.x,0},
      {u.y,v.y,w.y,0},
        {u.z,v.z,w.z,0},
          {0,0,0,1}
  };
}

// return the rotation that maps Z to u about cross(u,Z).
transform3 align(triple u)
{
  real a=u.x;
  real b=u.y;
  real c=u.z;
  real d=a^2+b^2;

  if(d != 0) {
    d=sqrt(d);
    real e=1/d;
    return new real[][] {
      {-b*e,-a*c*e,a,0},
        {a*e,-b*c*e,b,0},
          {0,d,c,0},
            {0,0,0,1}};
  }
  return c >= 0 ? identity(4) : diagonal(1,-1,-1,1);
}

// return a rotation that maps X,Y to the projection plane.
transform3 transform3(projection P)
{
  triple v=unit(P.oblique ? P.camera : P.vector());
  triple u=unit(P.up-dot(P.up,v)*v);
  return transform3(cross(u,v),u);
}

triple[] triples(real[] x, real[] y, real[] z)
{
  if(x.length != y.length || x.length != z.length)
    abort("arrays have different lengths");
  return sequence(new triple(int i) {return (x[i],y[i],z[i]);},x.length);
}

path3[] operator cast(path3 p)
{
  return new path3[] {p};
}

path3[] operator cast(guide3 g)
{
  return new path3[] {(path3) g};
}

path3[] operator ^^ (path3 p, path3  q) 
{
  return new path3[] {p,q};
}

path3[] operator ^^ (path3 p, explicit path3[] q) 
{
  return concat(new path3[] {p},q);
}

path3[] operator ^^ (explicit path3[] p, path3 q) 
{
  return concat(p,new path3[] {q});
}

path3[] operator ^^ (explicit path3[] p, explicit path3[] q) 
{
  return concat(p,q);
}

path3[] operator * (transform3 t, explicit path3[] p) 
{
  path3[] P;
  for(int i=0; i < p.length; ++i) P[i]=t*p[i];
  return P;
}

triple min(explicit path3[] p)
{
  checkEmpty(p.length);
  triple minp=min(p[0]);
  for(int i=1; i < p.length; ++i)
    minp=minbound(minp,min(p[i]));
  return minp;
}

triple max(explicit path3[] p)
{
  checkEmpty(p.length);
  triple maxp=max(p[0]);
  for(int i=1; i < p.length; ++i)
    maxp=maxbound(maxp,max(p[i]));
  return maxp;
}

typedef guide3 interpolate3(... guide3[]);

path3 randompath3(int n, bool cumulate=true, interpolate3 join=operator ..)
{
  guide3 g;
  triple w;
  for(int i=0; i <= n; ++i) {
    triple z=(unitrand()-0.5,unitrand()-0.5,unitrand()-0.5);
    if(cumulate) w += z; 
    else w=z;
    g=join(g,w);
  }
  return g;
}

path3[] box(triple v1, triple v2)
{
  return
    (v1.x,v1.y,v1.z)--
    (v1.x,v1.y,v2.z)--
    (v1.x,v2.y,v2.z)--
    (v1.x,v2.y,v1.z)--
    (v1.x,v1.y,v1.z)--
    (v2.x,v1.y,v1.z)--
    (v2.x,v1.y,v2.z)--
    (v2.x,v2.y,v2.z)--
    (v2.x,v2.y,v1.z)--
    (v2.x,v1.y,v1.z)^^
    (v2.x,v2.y,v1.z)--
    (v1.x,v2.y,v1.z)^^
    (v1.x,v2.y,v2.z)--
    (v2.x,v2.y,v2.z)^^
    (v2.x,v1.y,v2.z)--
    (v1.x,v1.y,v2.z);
}

path3[] unitbox=box(O,(1,1,1));

path3 unitcircle3=X..Y..-X..-Y..cycle;

path3 circle(triple c, real r, triple normal=Z)
{
  path3 p=scale3(r)*unitcircle3;
  if(normal != Z) 
    p=align(unit(normal))*p;
  return shift(c)*p;
}

// return an arc centered at c with radius r from c+r*dir(theta1,phi1) to
// c+r*dir(theta2,phi2) in degrees, drawing in the given direction
// relative to the normal vector cross(dir(theta1,phi1),dir(theta2,phi2)).
// The normal must be explicitly specified if c and the endpoints are colinear.
path3 arc(triple c, real r, real theta1, real phi1, real theta2, real phi2,
          triple normal=O, bool direction)
{
  triple v1=dir(theta1,phi1);
  triple v2=dir(theta2,phi2);

  if(normal == O) {
    normal=cross(v1,v2);
    if(normal == O) abort("explicit normal required for these endpoints");
  }

  normal=unit(normal);
  transform3 T=align(normal);
  transform3 Tinv=transpose(T);
  v1=Tinv*v1;
  v2=Tinv*v2;

  real[] t1=intersect(unitcircle3,O--2*(v1.x,v1.y,0));
  real[] t2=intersect(unitcircle3,O--2*(v2.x,v2.y,0));
  if(t1.length == 0 || t2.length == 0)
    abort("invalid normal vector");
  real t1=t1[0];
  real t2=t2[0];
  int n=length(unitcircle3);
  if(t1 >= t2 && direction) t1 -= n;
  if(t2 >= t1 && !direction) t2 -= n;

  return shift(c)*scale3(r)*T*subpath(unitcircle3,t1,t2);
}

// return an arc centered at c with radius r from c+r*dir(theta1,phi1) to
// c+r*dir(theta2,phi2) in degrees, drawing drawing counterclockwise
// relative to the normal vector cross(dir(theta1,phi1),dir(theta2,phi2))
// iff theta2 > theta1 or (theta2 == theta1 and phi2 >= phi1).
// The normal must be explicitly specified if c and the endpoints are colinear.
// If r < 0, draw the complementary arc of radius |r|.
path3 arc(triple c, real r, real theta1, real phi1, real theta2, real phi2,
          triple normal=O)
{
  bool pos=theta2 > theta1 || (theta2 == theta1 && phi2 >= phi1);
  if(r > 0) return arc(c,r,theta1,phi1,theta2,phi2,normal,pos ? CCW : CW);
  else return arc(c,-r,theta1,phi1,theta2,phi2,normal,pos ? CW : CCW);
}

// return an arc centered at c from triple v1 to v2 (assuming |v2-c|=|v1-c|),
// drawing in the given direction.
// The normal must be explicitly specified if c and the endpoints are colinear.
path3 arc(triple c, triple v1, triple v2, triple normal=O, bool direction=CCW)
{
  v1 -= c; v2 -= c;
  return arc(c,abs(v1),colatitude(v1),longitude(v1,warn=false),
             colatitude(v2),longitude(v2,warn=false),normal,direction);
}

private real epsilon=1000*realEpsilon;

// Return a representation of the plane through point O with normal cross(u,v).
path3 plane(triple u, triple v, triple O=O)
{
  return O--O+u--O+u+v--O+v--cycle;
}

// Return the unit normal vector to a planar path p.
triple normal(path3 p)
{
  triple normal;
  real abspoint,absnext;
  
  void check(triple n) {
    if(abs(n) > epsilon*max(abspoint,absnext)) {
      n=unit(n);
      if(normal != O && abs(normal-n) > epsilon && abs(normal+n) > epsilon)
        abort("path is not planar");
      normal=n;
    }
  }

  int L=length(p);
  triple nextpre=precontrol(p,0);
  triple nextpoint=point(p,0);
  absnext=abs(nextpoint);
  
  for(int i=0; i < L; ++i) {
    triple pre=nextpre;
    triple point=nextpoint;
    triple post=postcontrol(p,i);
    nextpre=precontrol(p,i+1);
    nextpoint=point(p,i+1);
    
    abspoint=abs(point);
    absnext=abs(nextpoint);
    
    check(cross(point-pre,post-point));
    check(cross(post-point,nextpoint-nextpre));
  }
  return normal;
}

triple size3(frame f)
{
  return max3(f)-min3(f);
}

// PRC/OpenGL support

private string[] file3;

string orthographic="activeCamera=scene.cameras.getByIndex(0);
function orthographic() 
{
activeCamera.projectionType=activeCamera.TYPE_ORTHOGRAPHIC;
bounds=scene.computeBoundingBox();
d=bounds.max.x-bounds.min.x;
dy=bounds.max.y-bounds.min.y;
if(dy > d) d=dy;
activeCamera.viewPlaneSize=d;
activeCamera.binding=activeCamera.BINDING_MAX;
}

orthographic();

handler=new CameraEventHandler();
runtime.addEventHandler(handler);
handler.onEvent=function(event) 
{
  orthographic();
  scene.update();
}";

include three_light;

private string format(real x)
{
  assert(abs(x) < 1e18,"Number too large: "+string(x));
  return format("%.18f",x,"C");
}

private string format(triple v, string sep=" ")
{
  return format(v.x)+sep+format(v.y)+sep+format(v.z);
}

private string format(pen p)
{
  real[] c=colors(rgb(p));
  return format((c[0],c[1],c[2]));
}

string lightscript(light light, transform3 T) {
 // Adobe Reader doesn't appear to support user-specified viewport lights.
  if(!light.on() || light.viewport) return "";
  string script="for(var i=scene.lights.count-1; i >= 0; i--)
  scene.lights.removeByIndex(i);"+'\n\n';
    for(int i=0; i < light.position.length; ++i) {
      string Li="L"+string(i);
      real[] diffuse=light.diffuse[i];
      script += Li+"=scene.createLight();"+'\n'+
	Li+".direction.set("+format(-(T*light.position[i]),",")+");"+'\n'+
      Li+".color.set("+format((diffuse[0],diffuse[1],diffuse[2]),",")+");"+'\n';
    }
// Work around initialization bug in Adobe Reader 8.0:
    return script +"
scene.lightScheme=scene.LIGHT_MODE_HEADLAMP;
scene.lightScheme=scene.LIGHT_MODE_FILE;
";
}

void writeJavaScript(string name, string preamble, string script) 
{
  file out=output(name);
  write(out,preamble);
  if(script != "") {
    file in=input(script);
    while(true) {
      string line=in;
      if(eof(in)) break;
      write(out,line,endl);
    }
  }
  close(out);
  file3.push(name);
}

string embed3D(string prefix, frame f, string label="",
               string text=label,  string options="", string script="",
               real width=0, real height=0, real angle=30,
               pen background=white, light light=currentlight,
	       projection P=currentprojection)
{
  if(!prc() || plain.embed == null) return "";

  if(width == 0) width=settings.paperwidth;
  if(height == 0) height=settings.paperheight;

  if(script == "") script=defaultembed3Dscript;

  transform3 T=P.modelview();
  string lightscript=lightscript(light,shiftless(T));

  if(P.infinity || lightscript != "") {
    string name=prefix+".js";
    writeJavaScript(name,P.infinity ? lightscript+orthographic:
		    lightscript,script);
    script=name;
  }

  if(P.infinity) {
    frame g=T*f;
    triple m=min3(g);
    triple M=max3(g);
    real r=0.5*abs(M-m);
    triple center=0.5*(M+m);

    P=P.copy();
    P.camera=O; // Eye is at (0,0,0).
    P.target=(0,0,-r);
    triple s=-center+P.target;
    m += s;
    M += s;
    g=shift(s)*g;
    shipout3(prefix,g);
  } else
    shipout3(prefix,f);
  
  prefix += ".prc";
  file3.push(prefix);

  triple v=P.vector()/cm;
  triple u=unit(v);
  triple w=unit(Z-u.z*u);
  triple up=unit(P.up-dot(P.up,u)*u);
  real roll=degrees(acos1(dot(up,w)))*sgn(dot(cross(up,w),u));

  string options3=light.viewport ? "3Dlights=Headlamp" : "3Dlights=File";
  options3 += ","+defaultembed3Doptions+",poster,text="+text+",label="+label+
    ",3Daac="+format(P.absolute ? P.angle*fovfactor : angle)+
    ",3Dc2c="+format(unit(v))+
    ",3Dcoo="+format(P.target/cm)+
    ",3Droll="+format(roll)+
    ",3Droo="+format(abs(v))+
    ",3Dbg="+format(background);
  if(options != "") options3 += ","+options;
  if(script != "") options3 += ",3Djscript="+script;

  return plain.embed(prefix,options3,width,height);
}

object embed(string prefix=defaultfilename, frame f, string label="",
             string text=label, string options="", string script="",
             real width=0, real height=0, real angle=30,
             pen background=white, projection P=currentprojection)
{
  object F;

  if(is3D())
    F.L=embed3D(prefix,f,label,text,options,script,width,height,angle,
                background,P);
  else
    F.f=f;
  return F;
}

triple rectify(triple dir) 
{
  real scale=max(abs(dir.x),abs(dir.y),abs(dir.z));
  if(scale != 0) dir *= 0.5/scale;
  dir += (0.5,0.5,0.5);
  return dir;
}

object embed(string prefix=defaultfilename, picture pic,
             real xsize=pic.xsize, real ysize=pic.ysize,
             bool keepAspect=pic.keepAspect,
             string label="", string text=label,
             bool wait=false, bool view=true, string options="",
             string script="", real angle=0, pen background=white,
             light light=currentlight, projection P=currentprojection)
{
  object F;
  if(pic.empty3()) return F;
  real xsize3=pic.xsize3, ysize3=pic.ysize3, zsize3=pic.zsize3;
  bool warn=true;
  if(xsize3 == 0 && ysize3 == 0 && zsize3 == 0) {
    xsize3=ysize3=zsize3=max(xsize,ysize);
    warn=false;
  }

  projection P=P.copy();
  picture pic2;
  transform3 t=pic.scaling(xsize3,ysize3,zsize3,keepAspect,warn);

  if(!P.absolute) {
    P.adjust(inverse(t)*pic.max(t));
    P.adjust(inverse(t)*pic.min(t));
    P=t*P;
  }
  
  frame f=pic.fit3(t,pic.bounds3.exact ? pic2 : null,P);

  if(!pic.bounds3.exact) {
    transform3 s=pic.scale3(f,xsize3,ysize3,zsize3,keepAspect);
    t=s*t;
    P=s*P;
    f=pic.fit3(t,pic2,P);
  }
  bool is3D=is3D();
  bool scale=xsize != 0 || ysize != 0;

  if(is3D || scale) {
    pic2.bounds.exact=true;
    transform s=pic2.scaling(xsize,ysize,keepAspect);
    pair M=pic2.max(s);
    pair m=pic2.min(s);
    pair lambda=M-m;
    real width=lambda.x;
    real height=lambda.y;

    if(!P.absolute) {
      pair v=(s.xx,s.yy);
      transform3 T=P.t;
      pair x=project(X,T);
      pair y=project(Y,T);
      pair z=project(Z,T);
      real f(pair a, pair b) {
        return b == 0 ? (0.5*(a.x+a.y)) : (b.x^2*a.x+b.y^2*a.y)/(b.x^2+b.y^2);
      }
      transform3 s=identity4;
      if(scale) {
        s=xscale3(f(v,x))*yscale3(f(v,y))*zscale3(f(v,z));
        P=s*P;
      }
      pair c=0.5*(M+m);
      if(is3D) {
        triple shift=invert(c,unit(P.vector()),P.target,P);
        P.target += shift;
        P.calculate();
      }
      if(scale) {
        pic2.erase();
        f=pic.fit3(s*t,is3D ? null : pic2,P);
      }
      if(is3D && angle == 0)
        // Choose the angle to be just large enough to view the entire image:
        angle=2*anglefactor*aTan((M.y-c.y)/(abs(P.vector())));
    }
    
    if(prefix == "") prefix=outprefix();
    bool prc=prc();
    bool preview=settings.render > 0;
    if(prc)
      prefix += "-"+(string) file3.length;
    else
      preview=false;
    if(preview || (!prc && settings.render != 0)) {
      transform3 T=P.modelview();
      frame g=T*f;
      triple m=min3(g);
      triple M=max3(g);
      if(P.infinity) {
        triple s=(-0.5*(m.x+M.x),-0.5*(m.y+M.y),0); // Eye will be at (0,0,0).
        m += s;
        M += s;
        g=shift(s)*g;
      }
      real r=0.5*abs(M-m);
      real zcenter=0.5*(M.z+m.z);
      M=(M.x,M.y,zcenter+r);
      m=(m.x,m.y,zcenter-r);
      if(preview)
        file3.push(prefix+".eps");
      shipout3(prefix,g,preview ? "eps" : "",width,height,
               P.infinity ? 0 : (P.absolute ? P.angle : angle),m,M,
	       light.viewport ? light.position : light.position(shiftless(T)),
	       light.diffuse,light.ambient,light.specular,
	       light.viewport,wait,view && !preview);
      if(!preview) return F;
    }

    if(prc) F.L=embed3D(prefix,f,label,
                        text=preview ? graphic(prefix+".eps") : "",options,
                        script,width,height,angle,background,light,P);
  }

  if(!is3D)
    F.f=pic2.fit2(xsize,ysize,keepAspect);

  return F;
}

embed3=new object(string prefix, frame f, string options="", string script="",
                  projection P) {
  return embed(prefix,f,options,script,P);
};

currentpicture.fitter=new frame(picture pic, real xsize, real ysize,
                                bool keepAspect, bool wait, bool view,
                                string options, string script, projection P) {
  frame f;
  add(f,pic.fit2(xsize,ysize,keepAspect));
  if(!pic.empty3()) {
    object F=embed(pic,xsize,ysize,keepAspect,wait,view,options,script,P);
    if(prc())
      label(f,F.L);
    else {
      if(settings.render != 0) return f;
      else add(f,F.f);
    }
  }
  return f;
};

void add(picture dest=currentpicture, object src, pair position=0, pair align=0,
         bool group=true, filltype filltype=NoFill, bool put=Above)
{
  if(prc())
    label(dest,src,position,align);
  else if(settings.render == 0)
    plain.add(dest,src,position,align,group,filltype,put);
}

string cameralink(string label, string text="View Parameters")
{
  if(!prc() || plain.link == null) return "";
  return plain.link(label,text,"3Dgetview");
}

private struct viewpoint {
  triple target,camera,up;
  real angle;
  void operator init(string s) {
    s=replace(s,new string[][] {{" ",","},{"}{",","},{"{",""},{"}",""},});
    string[] S=split(s,",");
    target=((real) S[0],(real) S[1],(real) S[2])*cm;
    camera=target+(real) S[6]*((real) S[3],(real) S[4],(real) S[5])*cm;
    triple u=unit(target-camera);
    triple w=unit(Z-u.z*u);
    up=rotate((real) S[7],O,u)*w;
    angle=S[8] == "" ? 30 : (real) S[8];
  }
}

projection perspective(string s)
{
  viewpoint v=viewpoint(s);
  projection P=perspective(v.camera,v.up,v.target);
  P.angle=v.angle/fovfactor;
  P.absolute=true;
  return P;
}

void begingroup3(picture pic=currentpicture)
{
  pic.add(new void(frame f, transform3, picture opic, projection) {
      if(opic != null)
        begingroup(opic);
    },true);
}

void endgroup3(picture pic=currentpicture)
{
  pic.add(new void(frame f, transform3, picture opic, projection) {
      if(opic != null)
        endgroup(opic);
    },true);
}

void addPath(picture pic, path3 g, pen p)
{
  pic.addBox(min(g),max(g),min3(p),max3(p));
}

void draw(frame f, path3 g, material p=currentpen, light light=nolight,
          projection P=currentprojection);

include three_surface;

void draw(picture pic=currentpicture, Label L="", path3 g,
          align align=NoAlign, material p=currentpen, light light=nolight)
{
  pen q=(pen) p;
  Label L=L.copy();
  L.align(align);
  if(L.s != "") {
    L.p(q);
    label(pic,L,g);
  }

  pic.add(new void(frame f, transform3 t, picture pic, projection P) {
      if(is3D())
        draw(f,t*g,p,light,null);
      if(pic != null)
        draw(pic,project(t*g,P),q);
    },true);
  addPath(pic,g,q);
}

include three_arrows;

draw=new void(frame f, path3 g, material p=currentpen,
              light light=nolight, projection P=currentprojection) {
  if(is3D()) {
    p=material(p,(p.granularity >= 0) ? p.granularity : linegranularity);
    pen q=(pen) p;
    void drawthick(path3 g) {
      _draw(f,g,q);
      if(settings.thick) {
        real width=linewidth(q);
        if(width > 0) {
          surface s=tube(g,width);
          if(!cyclic(g)) {
            real r=0.5*width;
            int L=length(g);
            real linecap=linecap(q);
            if(linecap == 0) {
              surface disk=scale(r,r,1)*unitdisk;
              s.append(shift(point(g,0))*align(dir(g,0))*disk);
              s.append(shift(point(g,L))*align(dir(g,L))*disk);
            } else if(linecap == 1) {
              surface sphere=scale3(r)*unitsphere;
              s.append(shift(point(g,0))*sphere);
              s.append(shift(point(g,L))*sphere);
            } else if(linecap == 2) {
              surface cylinder=unitcylinder;
              cylinder.append(shift(Z)*unitdisk);
              cylinder=scale3(r)*cylinder;
              s.append(shift(point(g,0))*align(-dir(g,0))*cylinder);
              s.append(shift(point(g,L))*align(dir(g,L))*cylinder);
            }
          }
          for(int i=0; i < s.s.length; ++i)
            draw3D(f,s.s[i],p,light);
        }
      }
    }
    string type=linetype(adjust(q,arclength(g),cyclic(g)));
    if(length(type) == 0) drawthick(g);
    else {
      real[] dash=(real[]) split(type," ");
      if(sum(dash) > 0) {
        dash.cyclic(true);
        real offset=0;
        real L=arclength(g);
        int i=0;
        real l=offset;
        while(l <= L) {
          real t1=arctime(g,l);
          l += dash[i];
          real t2=arctime(g,l);
          drawthick(subpath(g,t1,t2));
          ++i;
          l += dash[i];
          ++i;
        }
      }
    }
  }
  else draw(f,project(g,P),(pen) p);
};

void draw(frame f, explicit path3[] g, material p=currentpen,
          light light=nolight, projection P=currentprojection)
{
  for(int i=0; i < g.length; ++i) draw(f,g[i],p,light,P);
}

void draw(picture pic=currentpicture, explicit path3[] g,
          material p=currentpen, light light=nolight)
{
  for(int i=0; i < g.length; ++i) draw(pic,g[i],p,light);
}

void draw(picture pic=currentpicture, Label L="", path3 g, 
          align align=NoAlign, material p=currentpen, arrowbar3 arrow,
          light light=nolight)
{
  label(pic,L,g,align,(pen) p);
  begingroup3(pic);
  if(arrow(pic,g,p,light))
    draw(pic,L,g,align,p,light);
  endgroup3(pic);
}

void draw(frame f, path3 g, material p=currentpen, arrowbar3 arrow,
          light light=nolight, projection P=currentprojection)
{
  picture pic;
  if(arrow(pic,g,p,light))
    draw(f,g,p,light,P);
  add(f,pic.fit());
}

void add(picture pic=currentpicture, void d(picture,transform3),
         bool exact=false)
{
  pic.add(d,exact);
}

// Fit the picture src using the identity transformation (so user
// coordinates and truesize coordinates agree) and add it about the point
// position to picture dest.
void add(picture dest, picture src, triple position, bool group=true,
         bool put=Above)
{
  dest.add(new void(picture f, transform3 t) {
      f.add(shift(t*position)*src,group,put);
    });
}

// Align an arrow pointing to b from the direction dir. The arrow is
// 'length' PostScript units long.
void arrow(picture pic=currentpicture, Label L="", triple b, triple dir,
           real length=arrowlength, align align=NoAlign,
           pen p=currentpen, arrowbar3 arrow=Arrow3)
{
  Label L=L.copy();
  if(L.defaultposition) L.position(0);
  L.align(L.align,dir);
  L.p(p);
  picture opic;
  draw(opic,L,length*unit(dir)--O,align,p,arrow);
  add(pic,opic,b);
}

triple size3(picture pic, projection P=currentprojection)
{
  transform3 s=pic.calculateTransform3(P);
  return pic.max(s)-pic.min(s);
}

triple min3(picture pic, projection P=currentprojection)
{
  return pic.min3(P);
}
  
triple max3(picture pic, projection P=currentprojection)
{
  return pic.max3(P);
}
  
triple point(frame f, triple dir)
{
  triple m=min3(f);
  triple M=max3(f);
  return m+realmult(rectify(dir),M-m);
}

triple point(picture pic=currentpicture, triple dir)
{
  return pic.userMin+realmult(rectify(dir),pic.userMax-pic.userMin);
}

exitfcn currentexitfunction=atexit();

void exitfunction()
{
  if(currentexitfunction != null) currentexitfunction();
  if(!settings.keep)
    for(int i=0; i < file3.length; ++i)
      delete(file3[i]);
  file3=new string[];
}

atexit(exitfunction);
