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

draw(graph(t,susceptible,t <= 20),solid);
draw(graph(t,dead,t <= 20),dashed);

xaxis("Time ($\tau$)",BottomTop,LeftTicks(5.0));
yaxis(Left,RightTicks);

picture secondary=secondaryY(new void(picture pic) {
  draw(pic,graph(pic,t,infectious,t <= 20),red+solid);
});
			     
yaxis(secondary,black,red,Right,LeftTicks(2));
add(secondary);

label("Proportion of crows",point(NW),E,5mm*N);

