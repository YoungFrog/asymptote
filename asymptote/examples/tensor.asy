size(200);

pen[][] p={{red,green,blue,cyan},{green,blue,rgb(black),magenta}};
path g=(0,0){dir(-120)}..(1,0)..(1,1)..(0,1)..cycle;
path[] b={g,subpath(g,1,2)..(2,1)..(2,0)..cycle};
pair[][] z={{(0.5,0.5),(0.5,0.5),(0.5,0.5),(0.5,0.5)},{(2,0.5),(2,0.5),(1.5,0.5),(2,0.5)}};
tensorshade(b,p,z);
dot(b);
