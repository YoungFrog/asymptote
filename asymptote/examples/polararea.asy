import math;
import graph;

size(0,150);

real f(real t) {return 5+cos(10*t);}

xaxis("$x$");
yaxis("$y$");

real theta1=pi/8;
real theta2=pi/3;
guide k=graph(f,theta1,theta2,Spline);
real rmin=ypart(min(k));
real rmax=ypart(max(k));
draw((0,0)--rmax*expi(theta1),dotted);
draw((0,0)--rmax*expi(theta2),dotted);

guide g=polargraph(f,theta1,theta2,Spline);
guide h=(0,0)--g--cycle;
fill(h,lightgray);
draw(h);

real thetamin=3*pi/10;
real thetamax=2*pi/10;
pair zmin=polar(f(thetamin),thetamin);
pair zmax=polar(f(thetamax),thetamax);
draw((0,0)--zmin,dotted+red);
draw((0,0)--zmax,dotted+blue);

draw("$\theta_*$",arc((0,0),0.5*rmin,0,degrees(thetamin)),red+fontsize(10));
draw("$\theta^*$",arc((0,0),0.5*rmax,0,degrees(thetamax)),blue+fontsize(10));

draw(arc((0,0),rmin,degrees(theta1),degrees(theta2)),red);
draw(arc((0,0),rmax,degrees(theta1),degrees(theta2)),blue);

shipout();
