size(0,150);
import graph;

real f(real t) {return exp(-t/(2pi));}

draw(polargraph(f,0,20*pi,operator ..));

xaxis(-infinity,1.3,"$x$");
yaxis(-infinity,1,"$y$");

labelx(1);
labelx("$e^{-1}$",1.0/exp(1),SE);
