import three;
import graph;
import graph3;

size(0,200);

currentprojection=orthographic(4,6,3);

real x(real t) {return cos(2pi*t);}
real y(real t) {return sin(2pi*t);}
real z(real t) {return t;}

defaultpen(overwrite(SuppressQuiet));

path3 p=graph(x,y,z,0,2.7,Spline);
bbox3 b=autolimits(min(p),max(p));

xaxis("$x$",all=true,b,red,RightTicks(2,2));
yaxis("$y$",all=true,b,red,RightTicks(2,2));
zaxis("$z$",all=true,b,red,RightTicks);

draw(p,Arrow);

