import graph;

dotsize=0.3cm;

pair wheelpoint(real t)
{
  return (t+cos(t),-sin(t));
}
  
guide wheel(guide g=nullpath, real a, real b, int n)
{
  real width=(b-a)/n;
  for(int i=0; i <= n; ++i) {
    real t=a+width*i;
    g=g--wheelpoint(t);
  }
  return g;
}

real t1=0; 
real t2=t1+2*pi;

void initialpicture() {
  draw(circle((0,0),1));
  draw(wheel(t1,t2,100),currentpen+linetype("0 2"));
  xaxis(0,"$x$");
  yaxis(0,1.5,"$y$");
  pair z1=wheelpoint(t1);
  pair z2=wheelpoint(t2);

  yequals(-1,currentpen+linetype("4 4"));
  label("$y=-1$",(z2.x,-1),S);
  dot(z1);
  dot(z2);
}

int n=25;
real dt=(t2-t1)/n;
string prefix=fileprefix();
currentpen=linewidth(3);
for(int i=0; i <= n; ++i) {
  currentpicture=new picture;
  size(0,200);
  initialpicture();
  real t=t1+dt*i;
  draw(circle((t,0),1),currentpen+red);
  dot(wheelpoint(t),currentpen+red);
  shipout(prefix+(string) i,"gif");
}

gifmerge(10);


