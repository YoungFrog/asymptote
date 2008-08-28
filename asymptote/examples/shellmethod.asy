import graph3;
import solids;

size(0,150);
currentprojection=perspective(0,0,30,up=Y);
currentlight=(3,10,0);
pen color=green;
real alpha=240;

real f(real x) {return 2x^2-x^3;}
pair F(real x) {return (x,f(x));}
triple F3(real x) {return (x,f(x),0);}

int n=20;
path3[] blocks=new path3[n];
for(int i=1; i <= n; ++i) {
  real height=f((i-0.5)*2/n);
  real left=(i-1)*2/n;
  real right=i*2/n;
  blocks[i-1]=
    (left,0,0)--(left,height,0)--(right,height,0)--(right,0,0)--cycle;
}

path p=graph(F,0,2,n)--cycle;
surface s=surface(bezulate(p));
path3 p3=path3(p);

revolution a=revolution(p3,Y,0,alpha);
draw(surface(a),color);
draw(a,1,blue,false);
draw(s,color);
draw(rotate(alpha,(0,1,0))*s,color);
for(int i=0; i < n; ++i)
  draw(surface(blocks[i]),color,black);
draw(p3);

xaxis3(Label("$x$",1),Arrow3);
yaxis3(Label("$y$",1),dashed,Arrow3);
arrow("$y=2x^2-x^3$",XYplane(F(1.8)),X+Z,0.75cm);
draw(arc(1.22Y,0.3,90,0,7.5,180),Arrow3);
