import graph3;

size(0,300);
currentprojection=perspective(3,-2,2);

real V(real r) {return r^4-r^2;}
real V(pair pos) {return V(abs(pos));}

real R=1/sqrt(2);
real z=-0.2;

bool activebelow(pair pos) {return abs(pos) < R && V(pos) < z;}
bool activeabove(pair pos) {return abs(pos) < R && V(pos) >= z;}

pair a=(-1.5,-1);
pair b=(0.5,1);
real f=1.2;

draw(surface(plane(f*(b.x-a.x,0,z),(0,f*(b.y-a.y),z),(a.x,a.y,z))),
     lightgrey+opacity(0.5));
draw(surface(V,a,b,operator ..,activebelow),lightblue,black);
draw(surface(V,a,b,operator ..,activeabove),lightgreen,black);

xaxis3(Label("$\phi^\dagger\phi$",1),red,Arrow3);
zaxis3(Label("$V(\phi^\dagger\phi)$",1),0,0.3,red,Arrow3);
