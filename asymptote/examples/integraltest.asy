import graph;
size(300,150,IgnoreAspect);

real f(real x) {return 1/x^(1.1);}
pair F(real x) {return (x,f(x));}

dotfactor=7;

void subinterval(real a, real b)
{
  guide g=box((a,0),(b,f(b)));
  fill(g,lightgray); 
  draw(g); 
  draw(box((a,f(a)),(b,0)));
}

int a=1, b=9;
  
xaxis(0,b,"$x$"); 
yaxis(0,"$y$"); 
 
draw(graph(f,a,b,Spline),red);
 
for(int i=a; i <= b; ++i) {
  if(i < b) subinterval(i,i+1);
  if(i <= 3) xlabel(i);
  dot(F(i));
}
 
int i=3;
xlabel("$\ldots$",++i);
xlabel("$k$",++i);
xlabel("$k+1$",++i);
xlabel("$\ldots$",++i);

arrow("$f(x)$",F(2.55),0.7*NE,1.5cm,red);

