import graph;

size(9cm,6cm,IgnoreAspect);
string data="secondaryaxis.csv";

file in=line(csv(input(data)));

string[] titlelabel=in;
string[] columnlabel=in;

real[][] a=dimension(in,0,0);
a=transpose(a);
real[] t=a[0], susceptible=a[1], infectious=a[2], dead=a[3], larvae=a[4];
real[] susceptibleM=a[5], exposed=a[6],infectiousM=a[7];

draw(graph(t,susceptible,t >= 10 && t <= 15),solid);
draw(graph(t,dead,t >= 10 && t <= 15),dashed);

xaxis("Time ($\tau$)",BottomTop,LeftTicks);
yaxis(Left,RightTicks);

picture secondary=secondaryY(new void(picture pic) {
  draw(pic,graph(pic,t,4*infectious,t >= 10 && t <= 15),red+solid);
});
			     
//crop(secondary);
yaxis(secondary,black,red,Right,LeftTicks);
add(secondary);

label("Proportion of crows",point(NW),E,5mm*N);

