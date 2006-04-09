// Asymptote mathematics routines

real radians(real degrees)
{
  return degrees*pi/180;
}

real degrees(real radians) 
{
  return radians*180/pi;
}

// Convert radians to degrees in [0,360).
real Degrees(real radians) 
{
  real deg=degrees(radians);
  if(deg < 0) deg += 360; 
  return deg;
}

int quadrant(real degrees)
{
  return floor(degrees/90) % 4;
}

// Roots of unity.
pair unityroot(int n, int k = 1)
{
  return expi(2pi*k/n);
}

real Sin(real deg) {return sin(radians(deg));}
real Cos(real deg) {return cos(radians(deg));}
real Tan(real deg) {return tan(radians(deg));}
real aSin(real x) {return degrees(asin(x));}
real aCos(real x) {return degrees(acos(x));}
real aTan(real x) {return degrees(atan(x));}
real csc(real x) {return 1/sin(x);}
real sec(real x) {return 1/cos(x);}
real cot(real x) {return tan(pi/2-x);}
real frac(real x) {return x-(int)x;}

pair exp(explicit pair z) {return exp(z.x)*expi(z.y);}
pair log(explicit pair z) {return log(abs(z))+I*angle(z);}

// Return an Nx by Ny unit square lattice with lower-left corner at (0,0).
picture grid(int Nx, int Ny, pen p=currentpen)
{
  picture pic;
  for(int i=0; i <= Nx; ++i) draw(pic,(i,0)--(i,Ny),p);
  for(int j=0; j <= Ny; ++j) draw(pic,(0,j)--(Nx,j),p);
  return pic; 
}

bool straight(path p)
{
  for(int i=0; i < length(p); ++i)
    if(!straight(p,i)) return false;
  return true;
}

bool polygon(path p)
{
  return cyclic(p) && straight(p);
}

// Return the intersection point of the extensions of the line segments 
// PQ and pq.
pair extension(pair P, pair Q, pair p, pair q) 
{
  pair ac=P-Q;
  pair bd=q-p;
  real det=(conj(ac)*bd).y;
  if(det == 0) return (infinity,infinity);
  return P+(conj(p-P)*bd).y*ac/det;
}

// Compute normal vector to the plane defined by the first 3 elements of p.
triple normal(triple[] p)
{
  if(p.length < 3) abort("3 points are required to define a plane");
  return cross(p[1]-p[0],p[2]-p[0]);
}

triple unitnormal(triple[] p)
{
  return unit(normal(p));
}

// Return the intersection time of the extension of the line segment PQ
// with the plane perpendicular to n and passing through Z.
real intersect(triple P, triple Q, triple n, triple Z)
{
  real d=n.x*Z.x+n.y*Z.y+n.z*Z.z;
  real denom=n.x*(Q.x-P.x)+n.y*(Q.y-P.y)+n.z*(Q.z-P.z);
  return denom == 0 ? infinity : (d-n.x*P.x-n.y*P.y-n.z*P.z)/denom;
}
		    
// Return any point on the intersection of the two planes with normals
// n0 and n1 passing through points P0 and P1, respectively.
// If the planes are parallel return (infinity,infinity,infinity).
triple intersectionpoint(triple n0, triple P0, triple n1, triple P1)
{
  real Dx=n0.y*n1.z-n1.y*n0.z;
  real Dy=n0.z*n1.x-n1.z*n0.x;
  real Dz=n0.x*n1.y-n1.x*n0.y;
  if(abs(Dx) > abs(Dy) && abs(Dx) > abs(Dz)) {
    Dx=1/Dx;
    real d0=n0.y*P0.y+n0.z*P0.z;
    real d1=n1.y*P1.y+n1.z*P1.z+n1.x*(P1.x-P0.x);
    real y=(d0*n1.z-d1*n0.z)*Dx;
    real z=(d1*n0.y-d0*n1.y)*Dx;
    return (P0.x,y,z);
  } else if(abs(Dy) > abs(Dz)) {
    Dy=1/Dy;
    real d0=n0.z*P0.z+n0.x*P0.x;
    real d1=n1.z*P1.z+n1.x*P1.x+n1.y*(P1.y-P0.y);
    real z=(d0*n1.x-d1*n0.x)*Dy;
    real x=(d1*n0.z-d0*n1.z)*Dy;
    return (x,P0.y,z);
  } else {
    if(Dz == 0) return (infinity,infinity,infinity);
    Dz=1/Dz;
    real d0=n0.x*P0.x+n0.y*P0.y;
    real d1=n1.x*P1.x+n1.y*P1.y+n1.z*(P1.z-P0.z);
    real x=(d0*n1.y-d1*n0.y)*Dz;
    real y=(d1*n0.x-d0*n1.x)*Dz;
    return (x,y,P0.z);
  }
}

// Given a real array A, return its partial (optionally dx-weighted) sums.
real[] partialsum(real[] A, real[] dx={})
{
  real[] B=new real[A.length];
  B[0]=0;
  if(dx.length == 0)
    for(int i=0; i < A.length; ++i) B[i+1]=B[i]+A[i];
  else
    for(int i=0; i < A.length; ++i) B[i+1]=B[i]+A[i]*dx[i];
  return B;
}

real[] zero(int n)
{
  return sequence(new real(int x){return 0;},n);
}

real[][] zero(int n, int m)
{
  real[][] M=new real[n][m];
  for(int i=0; i < n; ++i)
    M[i]=sequence(new real(int x){return 0;},m);
  return M;
}

real[][] identity(int n)
{
  real[][] m=new real[n][n];
  for(int i=0; i < n; ++i)
    m[i]=sequence(new real(int x){return x == i ? 1 : 0;},n);
  return m;
}

real[][] operator + (real[][] a, real[][] b)
{
  int n=a.length;
  real[][] m=new real[0][n];
  for(int i=0; i < n; ++i)
    m[i]=a[i]+b[i];
  return m;
}

real[][] operator - (real[][] a, real[][] b)
{
  int n=a.length;
  real[][] m=new real[0][n];
  for(int i=0; i < n; ++i)
    m[i]=a[i]-b[i];
  return m;
}

private string incommensurate=
  "Multiplication of incommensurate matrices is undefined";

real[][] operator * (real[][] a, real[][] b)
{
  int n=a.length;
  int nb=b.length;
  int nb0=b[0].length;
  real[][] m=new real[n][nb0];
  for(int i=0; i < n; ++i) {
    real[] ai=a[i];
    real[] mi=m[i];
    if(ai.length != nb) 
      abort(incommensurate);
    for(int j=0; j < nb0; ++j) {
      real sum;
      for(int k=0; k < nb; ++k)
	sum += ai[k]*b[k][j];
      mi[j]=sum;
    }
  }
  return m;
}

real[] operator * (real[][] a, real[] b)
{
  int n=a.length;
  real[] m=new real[n];
  for(int i=0; i < n; ++i)
    m[i]=sum(a[i]*b);
  return m;
}

real[] operator * (real[] b, real[][] a)
{
  int nb=b.length;
  if(nb != a.length)
    abort(incommensurate);
  int na0=a[0].length;
  real[] m=new real[na0];
  for(int j=0; j < na0; ++j) {
    real sum;
    for(int k=0; k < nb; ++k)
      sum += b[k]*a[k][j];
    m[j]=sum;
  }
  return m;
}

real[][] operator * (real[][] a, real b)
{
  int n=a.length;
  real[][] m=new real[0][n];
  for(int i=0; i < n; ++i)
    m[i]=a[i]*b;
  return m;
}

real[][] operator * (real b, real[][] a)
{
  return a*b;
}

real[][] operator / (real[][] a, real b)
{
  return a*(1/b);
}

bool square2(real[][] m)
{
  return m[0].length == m.length && m[1].length == m.length;
}

bool square3(real[][] m)
{
  return
    m[0].length == m.length &&
    m[1].length == m.length &&
    m[2].length == m.length;
}

bool square(real[][] m)
{
  int n=m.length;
  for(int i=0; i < n; ++i)
    if(m[i].length != n) return false;
  return true;
}

bool rectangular(real[][] m)
{
  int n=m.length;
  int m0=m[0].length;
  for(int i=1; i < n; ++i)
    if(m[i].length != m0) return false;
  return true;
}

void nonsquare() 
{
  abort("attempt to take a determinant of a nonsquare matrix");
}

real determinant(real[][] m)
{
  int n=m.length;
  
  if(n == 2) {
    if(square2(m)) return m[0][0]*m[1][1]-m[0][1]*m[1][0];
    nonsquare();
  }
  
  if(n == 3) {
    if(square3(m)) return
      m[0][0]*(m[1][1]*m[2][2]-m[1][2]*m[2][1])-
      m[0][1]*(m[1][0]*m[2][2]-m[1][2]*m[2][0])+
      m[0][2]*(m[1][0]*m[2][1]-m[1][1]*m[2][0]);
    nonsquare();
  }
  
  if(square(m)) 
    abort("determinant of a general matrix is not yet implemented");
  else
    nonsquare();
  return 0;
}

// Solve the linear equation ax=b, returning the solution x, where a is
// an n x n matrix and b is an array of length n. 

real[] solve(real[][] a, real[] b)
{
  return transpose(solve(a,transpose(new real[][]{b})))[0];
}

real[][] inverse(real[][] m)
{
  return solve(m);
}

// draw the (infinite) line going through P and Q, without altering the
// size of picture pic.
void drawline(picture pic=currentpicture, pair P, pair Q, pen p=currentpen)
{
  pic.add(new void (frame f, transform t, transform, pair m, pair M) {
    // Reduce the bounds by the size of the pen.
    m -= min(p); M -= max(p);

    // Calculate the points and direction vector in the transformed space.
    pair z=t*P;
    pair v=t*Q-z;

    // Handle horizontal and vertical lines.
    if(v.x == 0) {
      if(m.x <= z.x && z.x <= M.x)
	draw(f,(z.x,m.y)--(z.x,M.y),p);
    } else if(v.y == 0) {
      if(m.y <= z.y && z.y <= M.y)
	draw(f,(m.y,z.y)--(M.x,z.y),p);
    } else {
      // Calculate the maximum and minimum t values allowed for the
      // parametric equation z + t*v
      real mx=(m.x-z.x)/v.x, Mx=(M.x-z.x)/v.x;
      real my=(m.y-z.y)/v.y, My=(M.y-z.y)/v.y;
      real tmin=max(v.x > 0 ? mx : Mx, v.y > 0 ? my : My);
      real tmax=min(v.x > 0 ? Mx : mx, v.y > 0 ? My : my);
      if(tmin <= tmax)
	draw(f,z+tmin*v--z+tmax*v,p);
    }
  });
}

real interpolate(real[] x, real[] y, real x0, int i) 
{
  int n=x.length;
  if(n == 0) abort("Zero data points in interpolate");
  if(n == 1) return y[0];
  if(i < 0) {
    real dx=x[1]-x[0];
    return y[0]+(y[1]-y[0])/dx*(x0-x[0]);
  }
  if(i >= n-1) {
    real dx=x[n-1]-x[n-2];
    return y[n-1]+(y[n-1]-y[n-2])/dx*(x0-x[n-1]);
  }

  real D=x[i+1]-x[i];
  real B=(x0-x[i])/D;
  real A=1.0-B;
  return A*y[i]+B*y[i+1];
}

// Linearly interpolate data points (x,y) to (x0,y0), where the elements of
// real[] x are listed in ascending order and return y0. Values outside the
// available data range are linearly extrapolated using the first derivative
// at the nearest endpoint.
real interpolate(real[] x, real[] y, real x0) 
{
  return interpolate(x,y,x0,search(x,x0));
}

real node(path g, real x)
{
  real m=min(g).y;
  real M=max(g).y;
  return intersect(g,(x,m)--(x,M)).x;
}

real node(path g, explicit pair z)
{
  real m=min(g).x;
  real M=max(g).x;
  return intersect(g,(m,z.y)--(M,z.y)).x;
}

real value(path g, real x)
{
  return point(g,node(g,x)).y;
}

real value(path g, explicit pair z)
{
  return point(g,node(g,(0,z.y))).x;
}

real slope(path g, real x)
{
  pair a=dir(g,node(g,x));
  return a.y/a.x;
}

real slope(path g, explicit pair z)
{
  pair a=dir(g,node(g,(0,z.y)));
  return a.y/a.x;
}
