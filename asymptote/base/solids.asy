import three;
import graph3;

int nslice=12;

// A solid geometry package.

// Try to find a bounding tangent line between two paths.
real[] tangent(path p, path q, bool side) 
{
  static real fuzz=1.0e-5;

  if((cyclic(p) && inside(p,point(q,0)) || 
      cyclic(q) && inside(q,point(p,0))) &&
     intersect(p,q,fuzz).length == 0) return new real[];

  static real epsilon=sqrt(realEpsilon);
  
  for(int i=0; i < 100; ++i) {
    real ta=side ? mintimes(p)[1] : maxtimes(p)[1];
    real tb=side ? mintimes(q)[1] : maxtimes(q)[1];
    pair a=point(p,ta);
    pair b=point(q,tb);
    real angle=angle(b-a,warn=false);
    if(abs(angle) <= epsilon || abs(abs(0.5*angle)-pi) <= epsilon)
      return new real[] {ta,tb};
    transform t=rotate(-degrees(angle));
    p=t*p;
    q=t*q;
  }
  return new real[];
}

path line(path p, path q, real[] t) 
{
  return point(p,t[0])--point(q,t[1]);
}

// Return the projection of a generalized cylinder of height h constructed
// from area base in the XY plane and aligned with axis.
path[] cylinder(path3 base, real h, triple axis=Z,
                projection P=currentprojection) 
{
  base=rotate(-colatitude(axis),cross(axis,Z))*base;
  path3 top=shift(h*axis)*base;
  path Base=project(base,P);
  path Top=project(top,P);
  real[] t1=tangent(Base,Top,true);
  real[] t2=tangent(Base,Top,false);
  path p=subpath(Base,t1[0],t2[0]);
  path q=subpath(Base,t2[0],t1[0]);
  return Base^^project(top,P)^^line(Base,Top,t1)^^line(Base,Top,t2);
}

// The three-dimensional "wireframe" used to visualize a volume of revolution
struct skeleton {
  // transverse skeleton (perpendicular to axis of revolution)
  path3[] front;
  path3[] back;
  // longitudinal skeleton (parallel to axis of revolution)
  path3[] longitudinal;
}

// A surface of revolution generated by rotating a planar path3 g
// from angle1 to angle2 about c--c+axis.
struct revolution {
  triple c;
  path3 g;
  triple axis;
  real angle1,angle2;
  
  void operator init(triple c=O, path3 g, triple axis=Z, real angle1=0,
                     real angle2=360) {
    this.c=c;
    this.g=g;
    this.axis=unit(axis);
    this.angle1=angle1;
    this.angle2=angle2;
  }
  
  // Return the surface of rotation obtain by rotating the path3 (x,0,f(x))
  // sampled n times between x=a and x=b about an axis lying in the XZ plane.
  void operator init(triple c=O, real f(real x), real a, real b, int n=ngraph,
                     interpolate3 join=operator --, triple axis=Z,
                     real angle1=0, real angle2=360) {
    operator init(c,graph(new triple(real x) {return (x,0,f(x));},a,b,n,
                          join),axis,angle1,angle2);
  }

  revolution copy() {
    return revolution(c,g,axis,angle1,angle2);
  }
  
  private real scalefactor() {return abs(c)+max(abs(min(g)),abs(max(g)));}

  triple vertex(int i, real j) {
    triple v=point(g,i);
    triple center=c+dot(v-c,axis)*axis;
    triple perp=v-center;
    triple normal=cross(axis,perp);
    return center+Cos(j)*perp+Sin(j)*normal;
  }

  // Construct the surface of rotation generated by rotating g
  // from angle1 to angle2 sampled n times about the line c--c+axis.
  // An optional surface pen color(int i, real j) may be specified
  // to override the color at vertex(i,j).
  surface surface(int n=nslice, pen color(int i, real j)=null) {
    real w=(angle2-angle1)/n;
    int L=length(g);
    surface s=three.surface(L*n);
    int m=-1;
    transform3[] T=new transform3[n+1];
    real j=angle1;
    for(int k=0; k <= n; ++k, j += w)
      T[k]=rotate(j,c,c+axis);

    for(int i=0; i < L; ++i) {
      path3 h=subpath(g,i,i+1);
      path3 r=reverse(h);
      triple perp=max(h)-c;
      if(perp == O) perp=min(h)-c;
      perp=unit(perp-dot(perp,axis)*axis);
      triple normal=cross(axis,perp);
      triple dir(real j) {return -Sin(j)*perp+Cos(j)*normal;}
      j=angle1;
      for(int k=0; k < n; ++k, j += w) {
        path3 G=T[k]*h{dir(j)}..{dir(j+w)}T[k+1]*r{-dir(j+w)}..{-dir(j)}cycle;
        s.s[++m]=color == null ? patch(G) :
          patch(G,new pen[] {color(i,j),color(i+1,j),color(i+1,j+w),
                             color(i,j+w)});
      }
    }

    return s;
  }

  path3 slice(real position) {
    triple v=point(g,position);
    triple center=c+dot(v-c,axis)*axis;
    triple perp=v-center;
    real o=longitude(align(axis)*perp,warn=false);
    path3 p=Arc(center,abs(v-center),90,angle1+o,90,angle2+o,axis);
    return (angle2-angle1) % 360 == 0 ? p&cycle : p;
  }
  
  // add transverse slice to skeleton s
  void transverse(skeleton s, real t,
                  projection P=currentprojection) {
    path3 S=slice(t);
    if(prc()) {
      s.front.push(S);
      return;
    }
    static real epsilon=sqrt(realEpsilon);
    triple camera=P.camera;
    if(P.infinity)
      camera *= scalefactor();
    int L=length(g);
    real midtime=0.5*L;
    real sign=sgn(dot(axis,camera-P.target))*sgn(dot(axis,dir(g,midtime)));
    if(dot(max(g)-min(g),axis) == 0 || (t <= epsilon && sign < 0) ||
       (t >= L-epsilon && sign > 0))
      s.front.push(S);
    else {
      path3 Sp=slice(t+epsilon);
      path3 Sm=slice(t-epsilon);
      path sp=project(Sp,P,1);
      path sm=project(Sm,P,1);
      real[] t1=tangent(sp,sm,true);
      real[] t2=tangent(sp,sm,false);
      if(t1.length > 1 && t2.length > 1) {
        real t1=t1[0];
        real t2=t2[0];
        int len=length(S);
        if(t2 < t1) {
          real temp=t1;
          t1=t2;
          t2=temp;
        }
        path3 p1=subpath(S,t1,t2);
        path3 p2=subpath(S,t2,len);
        path3 P2=subpath(S,0,t1);
        if(abs(midpoint(p1)-camera) <= abs(midpoint(p2)-camera)) {
          s.front.push(p1);
          if(cyclic(S))
            s.back.push(p2 & P2);
          else {
            s.back.push(p2);
            s.back.push(P2);
          }
        } else {
          if(cyclic(S))
            s.front.push(p2 & P2);
          else {
            s.front.push(p2);
            s.front.push(P2);
          }
          s.back.push(p1);
        }
      } else {
        if((t <= midtime && sign < 0) || (t >= midtime && sign > 0))
          s.front.push(S);
        else
          s.back.push(S);
      }
    }
  }

  // add m evenly spaced transverse slices to skeleton s
  void transverse(skeleton s, int m=0,
                  projection P=currentprojection) {
    int N=size(g);
    int n=(m == 0) ? N : m;
    real factor=m == 1 ? 0 : 1/(m-1);
    for(int i=0; i < n; ++i) {
      real t=(m == 0) ? i : reltime(g,i*factor);
      transverse(s,t,P);
    }
  }

  // add longitudinal curves to skeleton
  void longitudinal(skeleton s, projection P=currentprojection) {
    if(prc()) return;
    real t, d=0;
    static real epsilon=sqrt(realEpsilon);

    // Find a point on g of maximal distance from the axis.
    int N=size(g);
    for(int i=0; i < N; ++i) {
      triple v=point(g,i);
      triple center=c+dot(v-c,axis)*axis;
      real r=abs(v-center);
      if(r > d) {
        t=i;
        d=r;
      }
    }
    triple v=point(g,t);
    path3 S=slice(t);
    path3 Sm=slice(t+epsilon);
    path3 Sp=slice(t-epsilon);
    path sp=project(Sp,P,1);
    path sm=project(Sm,P,1);
    real[] t1=tangent(sp,sm,true);
    real[] t2=tangent(sp,sm,false);
    transform3 T=align(axis);
    real ref=longitude(T*(v-c),warn=false);
    real angle(real t) {return longitude(T*(point(S,t)-c),warn=false)-ref;}
    if(t1.length > 1)
      s.longitudinal.push(rotate(angle(t1[0]),c,c+axis)*g);
    if(t2.length > 1)
      s.longitudinal.push(rotate(angle(t2[0]),c,c+axis)*g);
  }
  
  skeleton skeleton(int m=0, projection P=currentprojection) {
    skeleton s;
    transverse(s,m,P);
    longitudinal(s,P);
    return s;
  }
}

surface surface(revolution r, int n=nslice, pen color(int i, real j)=null)
{
  return r.surface(n,color);
}

// Draw on picture pic the skeleton of the surface of revolution r.
// Draw the front portion of each of the m transverse slices with pen p and
// the back portion with pen backpen.
void draw(picture pic=currentpicture, revolution r, int m=0, pen p=currentpen,
          pen backpen=p, bool longitudinal=true, pen longitudinalpen=p,
          projection P=currentprojection)
{
  pen thin=prc() ? thin : defaultpen;
  skeleton s=r.skeleton(m,P);
  begingroup3(pic);
  draw(pic,s.back,linetype("8 8",8)+backpen);
  draw(pic,s.front,thin+p);
  if(longitudinal) draw(pic,s.longitudinal,thin+longitudinalpen);
  endgroup3(pic);
}

revolution operator * (transform3 t, revolution r)
{
  triple trc=t*r.c;
  return revolution(trc,t*r.g,t*(r.c+r.axis)-trc,r.angle1,r.angle2);
}

// Return a vector perpendicular to axis.
triple perp(triple axis)
{
  triple v=cross(axis,X);
  if(v == O) v=cross(axis,Y);
  return v;
}

// Return a right circular cylinder of height h in the direction of axis
// based on a circle centered at c with radius r.
// Note: unitcylinder provides a better surface.
revolution cylinder(triple c=O, real r, real h, triple axis=Z)
{
  triple C=c+r*perp(axis);
  axis=h*unit(axis);
  return revolution(c,C--C+axis,axis);
}

// Return a right circular cone of height h in the direction of axis
// based on a circle centered at c with radius r.
// Note: unitcone provides a better surface.
revolution cone(triple c=O, real r, real h, triple axis=Z)
{
  axis=unit(axis);
  return revolution(c,c+r*perp(axis)--c+h*axis,axis);
}

// Return an approximate sphere of radius r centered at c obtained by rotating
// an (n+1)-point approximation to a half circle about the Z axis.
// Note: unitsphere provides a better surface.
revolution sphere(triple c=O, real r, int n=nslice)
{
  return revolution(c,Arc(c,r,180,0,0,0,Y,n),Z);
}
