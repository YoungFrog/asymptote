/*****
 * plain.asy
 * Andy Hammerlindl and John Bowman 2004/08/19
 *
 * A package for general purpose drawing, with automatic sizing of pictures.
 *
 *****/

defaultpen(); // Reset the meaning of pen default attributes.
static public pen currentpen;

real inches=72;
real inch=inches;
real cm=inches/2.540005;
real mm=0.1cm;
real bp=1;	    // A PostScript point.
real pt=72.0/72.27; // A TeX pt is slightly smaller than a PostScript bp.

pair I=(0,1);
real pi=pi();

pair up=(0,1);
pair down=(0,-1);
pair right=(1,0);
pair left=(-1,0);

pair E=(1,0);
pair N=(0,1);
pair W=(-1,0);
pair S=(0,-1);

pair NE=unit(N+E);
pair NW=unit(N+W);
pair SW=unit(S+W);
pair SE=unit(S+E);

pair ENE=unit(E+NE);
pair NNE=unit(N+NE);
pair NNW=unit(N+NW);
pair WNW=unit(W+NW);
pair WSW=unit(W+SW);
pair SSW=unit(S+SW);
pair SSE=unit(S+SE);
pair ESE=unit(E+SE);
  
pen solid=linetype("");
pen dotted=linetype("0 4");
pen dashed=linetype("8 8");
pen longdashed=linetype("24 8");
pen dashdotted=linetype("8 8 0 8");
pen longdashdotted=linetype("24 8 0 8");

pen Dotted=linetype("0 4")+1.0;

pen invisible=invisible();
pen black=gray(0);
pen lightgray=gray(0.9);
pen lightgrey=lightgray;
pen gray=gray(0.5);
pen grey=gray;
pen white=gray(1);

pen red=rgb(1,0,0);
pen green=rgb(0,1,0);
pen blue=rgb(0,0,1);

pen cmyk=cmyk(0,0,0,0);
pen Cyan=cmyk(1,0,0,0);
pen Magenta=cmyk(0,1,0,0);
pen Yellow=cmyk(0,0,1,0);
pen Black=cmyk(0,0,0,1);

pen yellow=red+green;
pen magenta=red+blue;
pen cyan=blue+green;

pen brown=red+black;
pen darkgreen=green+black;
pen darkblue=blue+black;

pen orange=red+yellow;
pen purple=magenta+blue;

pen chartreuse=brown+green;
pen fuchsia=red+darkblue;
pen salmon=red+darkgreen+darkblue;
pen lightblue=darkgreen+blue;
pen lavender=brown+darkgreen+blue;
pen pink=red+darkgreen+blue;

// Global parameters:
public real labelmargin=0.3;
public real arrowlength=0.75cm;
public real arrowsize=7.5;
public real arrowangle=15;
public real arcarrowsize=0.5*arrowsize;
public real arcarrowangle=2*arrowangle;
public real barsize=arrowsize;
public real dotfactor=6;

public pair legendlocation=(1.0,0.8);
public real legendlinelength=50;
public real legendskip=1.5;
public pen legendboxpen=black;
public real legendmargin=10;

public string defaultfilename="";

real infinity=0.1*realMax();
real epsilon=realEpsilon();

bool finite(real x)
{
  return x != infinity && x != -infinity;
}

bool finite(pair z)
{
  return finite(z.x) && finite(z.y);
}

// To cut down two parentheses.
transform shift(real x, real y)
{
  return shift((x,y));
}

// I/O operations

file stdin=input("");
file stdout;

private struct endlT {};
public endlT endl=null;

private struct tabT {};
public tabT tab=null;

void write(file out, endlT endl=null) {write(out,"\n"); flush(out);}
void write(file out=stdout, bool x, endlT) {write(out,x); write(out);}
void write(file out=stdout, int x, endlT) {write(out,x); write(out);}
void write(file out=stdout, real x, endlT) {write(out,x); write(out);}
void write(file out=stdout, pair x, endlT) {write(out,x); write(out);}
void write(file out=stdout, string x, endlT) {write(out,x); write(out);}
void write(file out=stdout, guide x, endlT) {write(out,x); write(out);}
void write(file out=stdout, pen x, endlT) {write(out,x); write(out);}
void write(file out=stdout, transform x, endlT) {write(out,x); write(out);}

void write(file out=stdout, tabT) {write(out,"\t");}
void write(file out=stdout, bool x, tabT) {write(out,x); write(out,tab);}
void write(file out=stdout, int x, tabT) {write(out,x); write(out,tab);}
void write(file out=stdout, real x, tabT) {write(out,x); write(out,tab);}
void write(file out=stdout, pair x, tabT) {write(out,x); write(out,tab);}
void write(file out=stdout, string x, tabT) {write(out,x); write(out,tab);}
void write(file out=stdout, guide x, tabT) {write(out,x); write(out,tab);}
void write(file out=stdout, pen x, tabT) {write(out,x); write(out,tab);}
void write(file out=stdout, transform x, tabT) {write(out,x); write(out,tab);}

// write(x) with no file argument does a write(stdout,x,endl)
void write() {write(stdout);}
void write(guide x) {write(stdout,x,endl);}
void write(pen x) {write(stdout,x,endl);}
void write(transform x) {write(stdout,x,endl);}

void write(file out=stdout, string x, real y)
{
  write(out,x); write(out,y,endl);
}

void write(file out=stdout, string x, pair y)
{
  write(out,x); write(out,y,endl);
}

void write(file out=stdout, string x, real y, string x2, real y2)
{
  write(out,x); write(out,y,tab); write(out,x2,y2);
}

string ask(string prompt)
{
  write(stdout,prompt);
  return stdin;
}

private int GUIFilenum=0;
private int GUIObject=0;
private string GUIPrefix;

public frame patterns;

void deconstruct(frame d)
{
  if(deconstruct()) {
    string prefix=GUIPrefix == "" ? fileprefix() : GUIPrefix;
    shipout(prefix+"_"+(string) GUIObject,d,patterns,"tgif",false);
  }
  ++GUIObject;
}

private struct DELETET {}
public DELETET DELETE=null;

struct GUIop
{
  public transform [] Transform=new transform [];
  public bool Delete=false;
}

GUIop [][] GUIlist;

// Delete item
void GUIop(int index, int filenum=0, DELETET)
{
  if(GUIlist.length <= filenum) GUIlist[filenum]=new GUIop [];
  GUIop [] GUIobj=GUIlist[filenum];
  while(GUIobj.length <= index) GUIobj.push(new GUIop);
  GUIobj[index].Delete=true;
}

// Transform item
void GUIop(int index, int filenum=0, transform g)
{
  if(GUIlist.length <= filenum) GUIlist[filenum]=new GUIop [];
  GUIop [] GUIobj=GUIlist[filenum];
  while(GUIobj.length <= index) GUIobj.push(new GUIop);
  GUIobj[index].Transform.push(g);
}

bool GUIDelete()
{
  if(GUIFilenum < GUIlist.length) {
    GUIop [] GUIobj=GUIlist[GUIFilenum];
    bool del=(GUIObject < GUIobj.length) ? GUIobj[GUIObject].Delete : false;
    if(del) deconstruct(nullframe);
    return del;
  }
  return false;
}

transform GUI(transform t=identity())
{
  if(GUIFilenum < GUIlist.length) {
    GUIop [] GUIobj=GUIlist[GUIFilenum];
    if(GUIObject < GUIobj.length) {
      transform [] G=GUIobj[GUIObject].Transform;
      for(int i=0; i < G.length; ++i) {
	t=G[i]*t;
      }
    }
  }
  return t;
}

// A function that draws an object to frame pic, given that the transform
// from user coordinates to true-size coordinates is t.
typedef void drawer(frame f, transform t);

// A generalization of drawer that includes the final frame's bounds.
typedef void drawerBound(frame f, transform t, transform T, pair lb, pair rt);

// A coordinate in "flex space." A linear combination of user and true-size
// coordinates.
struct coord {
  public real user, truesize;

  // Build a coord.
  static coord build(real user, real truesize) {
    coord c=new coord;
    c.user=user;
    c.truesize=truesize;
    return c;
  }

  // Deep copy of coordinate.  Users may add coords to the picture, but then
  // modify the struct. To prevent this from yielding unexpected results, deep
  // copying is used.
  coord copy() {
    return build(user, truesize);
  }
  
  void clip(real min, real max) {
    user=min(max(user,min),max);
  }
  
}

coord[] append (coord[] dest, coord[] src)
{
  for(int i=0; i < src.length; ++i)
    dest.push(src[i]);
  return dest;
}

void append (coord[] x, coord[] y, transform T, coord[] srcx, coord[] srcy)
{
  for(int i=0; i < srcx.length; ++i) {
    pair z=T*(srcx[i].user,srcy[i].user);
    x.push(coord.build(z.x,srcx[i].truesize));
    y.push(coord.build(z.y,srcy[i].truesize));
  }
  return;
}

public struct scaleT {
  typedef real scalefcn(real x);
  public scalefcn T,Tinv,Label;
  T=Tinv=Label=identity;
  public bool automin=true, automax=true;
};

public struct autoscaleT {
  public scaleT scale=new scaleT;
  public bool automin=true, automax=true;
  public real tickMin=infinity, tickMax=-infinity;
  void update() {
    if(automin) automin=scale.automin;
    if(automax) automax=scale.automax;
  }
}

public struct ScaleT {
  public bool set=false;
  public autoscaleT x=new autoscaleT;
  public autoscaleT y=new autoscaleT;
  public autoscaleT z=new autoscaleT;
  void update() {
    x.update();
    y.update();
    z.update();
  }
};

struct Legend {
  public string label;
  public pen p;
}

pair minbound(pair z, pair w) 
{
  return (min(z.x,w.x),min(z.y,w.y));
}

pair maxbound(pair z, pair w) 
{
  return (max(z.x,w.x),max(z.y,w.y));
}

struct picture {
  // The functions to do the deferred drawing.
  drawerBound[] nodes;
  
  // The coordinates in flex space to be used in sizing the picture.
  coord[] xcoords,ycoords;

  // Transform to be applied to this picture.
  public transform T;
  
  public bool deconstruct=false;
  public pair userMin,userMax;
  
  public ScaleT scale; // Needed by graph
  public Legend legend[];

  // The maximum sizes in the x and y directions; zero means no restriction.
  public real xsize=0, ysize=0;
  
  // If true, the x and y must be scaled by the same amount.
  public bool keepAspect=false;

  void init() {
    userMin=(infinity,infinity);
    userMax=-userMin;
    scale=new ScaleT;
  }
  init();
  
  // Erase the current picture, retaining any size specification.
  void erase() {
    nodes=new drawerBound[];
    xcoords=new coord[];
    ycoords=new coord[];
    T=identity();
    legend=new Legend[];
    init();
  }
  
  void userBox(pair min, pair max) {
    userMin=minbound(userMin,min);
    userMax=maxbound(userMax,max);
  }
  
  void add(drawerBound d) {
    nodes.push(d);
  }

  void build(frame f, drawer d, transform t) {
      if(deconstruct) {
	if(GUIDelete()) return;
	t=GUI(t);
      }
      d(f,t);
      if(deconstruct) deconstruct(f);
      return;
  }
  
  void add(drawer d) {
    uptodate(false);
    add(new void (frame f, transform t, transform T, pair, pair) {
      frame F;
      build(F,d,t*T);
      add(f,F);
    });
  }

  void clip(drawer d) {
    uptodate(false);
    for(int i=0; i < xcoords.length; ++i) {
      xcoords[i].clip(userMin.x,userMax.x);
      ycoords[i].clip(userMin.y,userMax.y);
    }
    add(new void (frame f, transform t, transform, pair, pair) {
      d(f,t);
    });
  }

  // Add a point to the sizing.
  void addPoint(pair userZ, pair trueZ=(0,0))
  {
    xcoords.push(coord.build(userZ.x,trueZ.x));
    ycoords.push(coord.build(userZ.y,trueZ.y));
    userBox(userZ,userZ);
  }
  
  // Add a box to the sizing.
  void addBox(pair userMin, pair userMax,
              pair trueMin=(0,0), pair trueMax=(0,0))
  {
    addPoint(userMin,trueMin);
    addPoint(userMax,trueMax);
  }

  // Add a point to the sizing, accounting also for the size of the pen.
  void addPoint(pair userZ, pair trueZ=(0,0), pen p)
  {
    addPoint(userZ, trueZ + max(p));
    addPoint(userZ, trueZ + min(p));
  }
  
  // Add a (user space) path to the sizing.
  void addPath(path g)
  {
    addBox(min(g),max(g));
  }

  // Add a path to the sizing with the additional padding of a pen.
  void addPath(path g, pen p)
  {
    addBox(min(g), max(g), min(p), max(p));
  }

  void size(real x=0, real y=0, bool a=true)
  {
    xsize=x;
    ysize=y;
    keepAspect=a;
  }

  // The scaling in one dimension:  x --> a*x + b
  struct scaling {
    public real a,b;
    static scaling build(real a, real b) {
      scaling s=new scaling;
      s.a=a; s.b=b;
      return s;
    }
    real scale(real x) {
      return a*x+b;
    }
    real scale(coord c) {
      return scale(c.user) + c.truesize;
    }
  }

  // Calculate the minimum point in scaling the coords.
  real min(scaling s, coord[] c)
  {
    if (c.length > 0) {
      real m=infinity;
      for (int i=0; i < c.length; ++i)
	if(finite(c[i].user) && s.scale(c[i]) < m)
          m=s.scale(c[i]);
      return m;
    }
    else
      // I don't know...
      return 0;
  }
 
  // Calculate the maximum point in scaling the coords.
  real max(scaling s, coord[] c)
  {
    if (c.length > 0) {
      real M=-infinity;
      for (int i=0; i < c.length; ++i)
        if (finite(c[i].user) && s.scale(c[i]) > M)
          M=s.scale(c[i]);
      return M;
    }
    else
      // I don't know...
      return 0;
  }

  // Calculate the min for the final picture, given the transform of coords.
  pair min(transform t)
  {
    pair a=t*(1,1)-t*(0,0), b=t*(0,0);
    scaling xs=scaling.build(a.x, b.x);
    scaling ys=scaling.build(a.y, b.y);
    return (min(xs,xcoords),min(ys,ycoords));
  }

  // Calculate the max for the final picture, given the transform of coords.
  pair max(transform t)
  {
    pair a=t*(1,1)-t*(0,0), b=t*(0,0);
    scaling xs=scaling.build(a.x, b.x);
    scaling ys=scaling.build(a.y, b.y);
    return (max(xs,xcoords),max(ys,ycoords));
  }

  // Calculate the sizing constants for the given array and maximum size.
  scaling calculateScaling(coord[] coords, real max) {
    import simplex;
    simplex.problem p=new simplex.problem;
   
    void addCoord(coord c) {
      // (a*user + b) + truesize >= 0:
      p.addRestriction(c.user,1,c.truesize);
      // (a*user + b) + truesize <= max:
      p.addRestriction(-c.user,-1,max-c.truesize);
    }

    for(int i=0; i < coords.length; ++i) {
      if(finite(coords[i].user)) addCoord(coords[i]);
    }

    int status=p.optimize();
    if (status == simplex.problem.OPTIMAL) {
      return scaling.build(p.a(),p.b());
    }
    else if (status == simplex.problem.UNBOUNDED) {
      write("warning: scaling in picture unbounded");
      return scaling.build(1,0);
    }
    else {
      write("warning: picture cannot fit in requested size");
      return scaling.build(1,0);
    }
  }

  // Returns the transform for turning user-space pairs into true-space pairs.
  transform calculateTransform(real xmax, real ymax=0, bool keepAspect=true)
  {
    if (xmax == 0 && ymax == 0)
      return identity();
    else if (ymax == 0) {
      scaling sx=calculateScaling(xcoords,xmax);
      return scale(sx.a);
    }
    else if (xmax == 0) {
      scaling sy=calculateScaling(ycoords,ymax);
      return scale(sy.a);
    }
    else {
      scaling sx=calculateScaling(xcoords,xmax);
      scaling sy=calculateScaling(ycoords,ymax);
      if (keepAspect)
        return scale(min(sx.a,sy.a));
      else
        return xscale(sx.a) * yscale(sy.a);
    }
  }

  frame fit(transform t, transform T0=T, pair m, pair M) {
    frame f;
    for (int i=0; i < nodes.length; ++i)
      nodes[i](f,t,T0,m,M);
    return f;
  }

  // Returns a rigid version of the picture using t to transform user coords
  // into truesize coords.
  frame fit(transform t) {
    return fit(t,min(t),max(t));
  }

  // Returns the picture fit to the wanted size.
  frame fit(real xmax, real ymax, bool keepAspect=true) {
    return fit(calculateTransform(xmax,ymax,keepAspect));
  }

  frame fit() {
    return fit(xsize,ysize,keepAspect);
  }
  
  // Copies the drawing information, but not the sizing information into a new
  // picture. Warning: Shipping out this picture will not scale as a normal
  // picture would.
  picture drawcopy()
  {
    picture dest=new picture;
    for (int i=0; i < nodes.length; ++i)
      dest.add(nodes[i]);
    
    dest.T=T;
    dest.deconstruct=deconstruct;
    dest.userMin=userMin;
    dest.userMax=userMax;
    dest.scale=scale;
    dest.legend=legend;

    return dest;
  }

  // A deep copy of this picture.  Modifying the copied picture will not affect
  // the original.
  picture copy()
  {
    picture dest=drawcopy();

    append(dest.xcoords,xcoords);
    append(dest.ycoords,ycoords);

    dest.xsize=xsize; dest.ysize=ysize; dest.keepAspect=keepAspect;

    return dest;
  }

  // Add a picture to this picture, such that the user coordinates will be
  // scaled identically in the shipout.
  void add(picture src)
  {
    // Copy the picture.  Only the drawing function closures are needed, so we
    // only copy them.  This needs to be a deep copy, as src could later have
    // objects added to it that should not be included in this picture.

    picture src_copy=src.drawcopy();

    // Draw by drawing the copied picture.
    add(new void (frame f, transform t, transform T, pair m, pair M) {
      if(deconstruct && !src.deconstruct) {
	if(GUIDelete()) return;
	T=GUI(T);
      }
     frame d=src_copy.fit(t,T*src_copy.T,m,M);
     if(deconstruct && !src.deconstruct) deconstruct(d);
     add(f,d);
     for(int i=0; i < src.legend.length; ++i)
       legend.push(src.legend[i]);
    });
    
    userBox(src.userMin,src.userMax);

    // Add the coord info to this picture.
    append(xcoords,ycoords,src_copy.T,src.xcoords,src.ycoords);
  }
}

picture operator * (transform t, picture orig)
{
  picture pic=orig.copy();
  pic.T=t*pic.T;
  pic.userMin=t*pic.userMin;
  pic.userMax=t*pic.userMax;
  return pic;
}

pair realmult(pair z, pair w) 
{
  return (z.x*w.x,z.y*w.y);
}

public picture currentpicture=new picture;
currentpicture.deconstruct=true;

public picture gui[];

picture gui(int index) {
  while(gui.length <= index) {
    picture g=new picture;
    g.deconstruct=true;
    gui.push(g);
  }
  return gui[index];
}

// Add frame f about origin to currentpicture
void addabout(pair origin, picture pic, frame src)
{
  pic.add(new void (frame dest, transform t) {
      add(dest,shift(t*origin)*src);
      });
  pic.addBox(origin,origin,min(src),max(src));
}

void addabout(pair origin, frame src)
{
  addabout(origin,currentpicture,src);
}

// Add a picture to another such that user coordinates in both will be scaled
// identically in the shipout.
void add(picture dest, picture src)
{
  dest.add(src);
}

void add(picture src)
{
  add(currentpicture,src);
}

// Fit the picture src using the identity transformation (so user
// coordinates and truesize coordinates agree) and add it about the point
// origin to picture dest.
void addabout(pair origin, picture dest, picture src)
{
  addabout(origin,dest,src.fit(identity()));
}

void addabout(pair origin, picture src)
{
  addabout(origin,currentpicture,src);
}

transform rotate(real a) 
{
  return rotate(a,0);
}

void _draw(picture pic=currentpicture, path g, pen p=currentpen)
{
  pic.add(new void (frame f, transform t) {
    draw(f,t*g,p);
    });
  pic.addPath(g,p);
}

// truesize draw about origin
void _drawabout(pair origin, picture pic=currentpicture, path g,
		pen p=currentpen)
{
  pic.add(new void (frame f, transform t) {
    draw(f,shift(t*origin)*g,p);
  });
  pic.addBox(origin,origin,min(g)+min(p),max(g)+max(p));
}
  
void fill(picture pic=currentpicture, path g,
	  pen pena=currentpen, pair a=0, real ra=0,
	  pen penb=currentpen, pair b=0, real rb=0)
{
  pic.add(new void (frame f, transform t) {
    pair A=t*a, B=t*b;
    fill(f,t*g,pena,A,abs(t*(a+ra)-A),penb,B,abs(t*(b+rb)-B));
    });
  pic.addPath(g);
}

void fillabout(pair origin, picture pic=currentpicture, path g,
	       pen pena=currentpen, pair a=0, real ra=0,
	       pen penb=currentpen, pair b=0, real rb=0)
{
  picture opic=new picture;
  fill(opic,g,pena,a,ra,penb,b,rb);
  addabout(origin,pic,opic);
}
  
void filldraw(picture pic=currentpicture, path g,
	      pen pena=currentpen, pen drawpen=currentpen, pair a=0, real ra=0,
	      pen penb=currentpen, pair b=0, real rb=0)
{
  pic.add(new void (frame f, transform t) {
    path G=t*g;
    pair A=t*a, B=t*b;
    fill(f,G,pena,A,abs(t*(a+ra)-A),penb,B,abs(t*(b+rb)-B));
    draw(f,G,drawpen);
    });
  pic.addPath(g,drawpen);
}

void filldrawabout(pair origin, picture pic=currentpicture, path g,
		   pen pena=currentpen, pen drawpen=currentpen,
		   pair a=0, real ra=0,
		   pen penb=currentpen, pair b=0, real rb=0)
{
  picture opic=new picture;
  filldraw(opic,g,pena,drawpen,a,ra,penb,b,rb);
  addabout(origin,pic,opic);
}
  
void clip(picture pic=currentpicture, path g)
{
  pic.userMin=maxbound(pic.userMin,min(g));
  pic.userMax=minbound(pic.userMax,max(g));
  pic.clip(new void (frame f, transform t) {
    clip(f,t*g);
  });
}

guide box(pair a, pair b)
{
  return a--(a.x,b.y)--b--(b.x,a.y)--cycle;
}

real labelmargin(pen p=currentpen)
{
  return labelmargin*fontsize(p);
}

void label(frame f, string s, real angle=0, pair position,
	   pair align=0, pen p=currentpen)
{
  _label(f,s,angle,position+align*labelmargin(p),align,p);
}

void label(picture pic=currentpicture, string s, real angle=0, pair position,
	   pair align=0, pair shift=0, pen p=currentpen)
{
  pic.add(new void (frame f, transform t) {
    pair offset=t*0;
    label(f,s,Angle(t*dir(angle)-offset),t*position+shift,
	  length(align)*unit(t*align-offset),p);
    });
  frame f;
  // Create a picture with label at the origin to extract its bbox truesize.
  label(f,s,angle,(0,0),align,p);
  pic.addBox(position,position,min(f),max(f));
}

pair point(picture pic=currentpicture, pair dir)
{
  real scale=max(abs(dir.x),abs(dir.y));
  if(scale != 0) dir *= 0.5/scale;
  dir += (0.5,0.5);
  return pic.userMin+realmult(dir,pic.userMax-pic.userMin);
}

guide arrowhead(picture pic=currentpicture, path g, real position=infinity,
		pen p=currentpen, real size=arrowsize, real angle=arrowangle)
{
  path r=subpath(g,position,0.0);
  pair x=point(r,0);
  real t=arctime(r,size);
  pair y=point(r,t);
  path base=y+2*size*I*dir(r,t)--y-2*size*I*dir(r,t);
  path left=rotate(-angle,x)*r, right=rotate(angle,x)*r;
  real tl=intersect(left,base).x, tr=intersect(right,base).x;
  pair denom=point(right,tr)-y;
  real factor=denom != 0 ? length((point(left,tl)-y)/denom) : 1;
  left=rotate(-angle,x)*r; right=rotate(angle*factor,x)*r;
  tl=intersect(left,base).x; tr=intersect(right,base).x;
  return subpath(left,0,tl > 0 ? tl : t)--subpath(right,tr > 0 ? tr : t,0)
    ..cycle;
}

void arrowheadbbox(picture pic=currentpicture, path g, real position=infinity,
		   pen p=currentpen, real size=arrowsize,
		   real angle=arrowangle)
{
  // Estimate the bounding box contribution using the local slope at endpoint:
  path r=subpath(g,position,0.0);
  pair x=point(r,0);
  pair y=point(r,arctime(r,size));
  pair dz1=rotate(-angle)*(y-x);
  pair dz2=rotate(angle)*(y-x);
  pic.addPoint(x,p);
  pic.addPoint(x,dz1,p);
  pic.addPoint(x,dz2,p);
}

private struct arrowheadT {};
public arrowheadT arrowhead=null;
typedef void arrowhead(frame, path, pen, arrowheadT);
public arrowhead
  Fill=new void(frame f, path g, pen p, arrowheadT) {
    p += solid;
    fill(f,g,p,0,0,p,0,0);
    draw(f,g,p);
  },
  NoFill=new void(frame f, path g, pen p, arrowheadT) {
    draw(f,g,p+solid);
  };

picture arrow(path g, pen p=currentpen, real size=arrowsize,
	      real angle=arrowangle, arrowhead arrowhead=Fill,
	      real position=infinity)
{
  picture pic=new picture;
  pic.add(new void (frame f, transform t) {
            picture pic=new picture;
	    path G=t*g;
	    path R=subpath(G,position,0.0);
	    path S=subpath(G,position,length(G));
	    size=min(arclength(G),size);
            draw(f,subpath(R,arctime(R,size),length(R)),p);
            draw(f,S,p);
	    guide head=arrowhead(pic,G,position,p,size,angle);
	    arrowhead(f,head,p,arrowhead);
          });
  
  pic.addPath(g,p);
  arrowheadbbox(pic,g,position,p,size,angle);
  return pic;
}

picture arrow2(path g, pen p=currentpen, real size=arrowsize,
	       real angle=arrowangle, arrowhead arrowhead=Fill)
{
  picture pic=new picture;
  pic.add(new void (frame f, transform t) {
            picture pic=new picture;
	    path G=t*g;
	    path R=reverse(G);
	    size=min(0.5*arclength(G),size);
            draw(f,subpath(R,arctime(R,size),length(R)-arctime(G,size)),p);
	    guide head=arrowhead(pic,G,p,size,angle);
	    guide tail=arrowhead(pic,R,p,size,angle);
	    arrowhead(f,head,p,arrowhead);
	    arrowhead(f,tail,p,arrowhead);
          });
  
  pic.addPath(g,p);
  arrowheadbbox(pic,g,p,size,angle);
  arrowheadbbox(pic,reverse(g),p,size,angle);
  return pic;
}

void postscript(picture pic=currentpicture, string s)
{
  pic.add(new void (frame f, transform) {
    postscript(f,s);
    });
}

void tex(picture pic=currentpicture, string s)
{
  pic.add(new void (frame f, transform) {
    tex(f,s);
    });
}

void layer(picture pic=currentpicture)
{
  pic.add(new void (frame f, transform) {
    layer(f);
    });
}

void newpage() 
{
  tex("\newpage");
  layer();
}

void include(picture pic=currentpicture, string name, string options="") 
{
  if(options != "") options="["+options+"]";
  string include="\includegraphics"+options+"{"+name+"}";
  tex(pic,"\kern-\wd\ASYpsbox%
\setbox\ASYpsbox=\hbox{"+include+"}%
"+include+"%");
  layer(pic);
}

private struct keepAspectT {};
public keepAspectT keepAspect=null;
typedef bool keepAspect(keepAspectT);
public keepAspect
  Aspect=new bool(keepAspectT) {return true;},
  IgnoreAspect=new bool(keepAspectT) {return false;};

private struct waitT {};
public waitT wait=null;
typedef bool wait(waitT);
public wait
  Wait=new bool(waitT) {return true;},
  NoWait=new bool(waitT) {return false;};

void size(picture pic=currentpicture,
          real xsize, real ysize=0, keepAspect keepAspect=Aspect)
{
  pic.size(xsize,ysize,keepAspect(keepAspect));
}

frame bbox(picture pic=currentpicture, real xmargin=0, real ymargin=infinity,
	   real xsize=infinity, real ysize=infinity, keepAspect keepAspect,
	   pen p=currentpen)
{
  if(ymargin == infinity) ymargin=xmargin;
  if(xsize == infinity) xsize=pic.xsize;
  if(ysize == infinity) ysize=pic.ysize;
  frame f=pic.fit(max(xsize-2*xmargin,0),max(ysize-2*ymargin,0),
		  keepAspect(keepAspect));
  if(pic.deconstruct && GUIDelete()) return f;
  pair z=(xmargin,ymargin);
  frame d;
  draw(d,box(min(f)+0.5*min(p)-z,max(f)+0.5*max(p)+z),p);
  if(pic.deconstruct) {
    d=GUI()*d;
    deconstruct(d);
  }
  add(f,d);
  return f;
}

frame bbox(picture pic=currentpicture, real xmargin=0, real ymargin=infinity,
	   real xsize=infinity, real ysize=infinity, pen p=currentpen)
{
  return bbox(pic,xmargin,ymargin,xsize,ysize,
	      pic.keepAspect ? Aspect : IgnoreAspect,p);
}

void labelbox(picture pic=currentpicture, real xmargin=0,
	      real ymargin=infinity, string s, real angle=0, pair position,
	      pair align=0, pair shift=0, pen p=currentpen,
	      pen pbox=currentpen)
{
  if(ymargin == infinity) ymargin=xmargin;
  pair margin=(xmargin,ymargin);
  pic.add(new void (frame f, transform t) {
    pair offset=t*0;
    frame b;
    label(b,s,Angle(t*dir(angle)-offset),t*position+shift,
	  length(align)*unit(t*align-offset),p);
    draw(b,box(min(b)-margin,max(b)+margin),pbox);
    add(f,b);
  });
  frame f;
  // Create a picture with label at the origin to extract its bbox truesize.
  label(f,s,angle,(0,0),align,p);
  draw(f,box(min(f)-margin,max(f)+margin),p);
  pic.addBox(position,position,min(f),max(f));
}

void legend(frame f, Legend[] legend, bool placement=true)
{
  if(legend.length > 0 && !GUIDelete()) {
    picture inset=new picture;
    for(int i=0; i < legend.length; ++i) {
      pen p=legend[i].p;
      pair z1=-i*I*legendskip*fontsize(p);
      pair z2=z1+legendlinelength;
      _draw(inset,z1--z2,p);
      label(inset,legend[i].label,z2,E,p);
    }
    frame d;
    // Place legend with top left corner at legendlocation;
    add(d,bbox(inset,legendmargin,legendmargin,0,0,IgnoreAspect,legendboxpen));
    if(placement) {
      pair topleft=min(f)+realmult(legendlocation,max(f)-min(f))+legendmargin;
      d=GUI()*shift(topleft-(min(d).x,max(d).y))*d;
      deconstruct(d);
    }
    add(f,d);
  }
}
  
void shipout(string prefix=defaultfilename, frame f, frame preamble=patterns,
	     Legend[] legend={}, string format="", wait wait=NoWait)
{
  GUIPrefix=prefix;
  add(f,gui(GUIFilenum).fit(identity()));
  legend(f,legend);
  shipout(prefix,f,preamble,format,wait(wait));
  ++GUIFilenum;
  GUIObject=0;
}

// Useful for compensating for space taken up by legend. For example:
// shipout(currentpicture.xsize-legendsize().x);
pair legendsize(picture pic=currentpicture)
{
  frame f;
  legend(f,pic.legend,false);
  return legendmargin+max(f)-min(f);
}

private struct orientationT {};
public orientationT orientation=null;
typedef frame orientation(frame, orientationT);
public orientation
  Portrait=new frame(frame f, orientationT) {return f;},
  Landscape=new frame(frame f, orientationT) {return rotate(90)*f;},
  Seascape=new frame(frame f, orientationT) {return rotate(-90)*f;};

void shipout(string prefix=defaultfilename, picture pic,
	     frame preamble=patterns, real xsize=infinity, real ysize=infinity,
	     keepAspect keepAspect, orientation orientation=Portrait,
	     string format="", wait wait=NoWait)
{
  if(xsize == infinity) xsize=pic.xsize;
  if(ysize == infinity) ysize=pic.ysize;
  GUIPrefix=prefix;
  pic.deconstruct=true;
  frame f=pic.fit(xsize,ysize,keepAspect(keepAspect));
  shipout(prefix,orientation(f,orientation),preamble,pic.legend,format,wait);
}

void shipout(string prefix=defaultfilename,
	     real xsize=infinity, real ysize=infinity,
	     keepAspect keepAspect, orientation orientation=Portrait,
	     string format="", wait wait=NoWait)
{
  shipout(prefix,currentpicture,ysize,keepAspect,orientation,format,wait);
}

void shipout(string prefix=defaultfilename, picture pic,
	     frame preamble=patterns, real xsize=infinity, real ysize=infinity,
	     orientation orientation=Portrait, string format="",
	     wait wait=NoWait)
{
  shipout(prefix,pic,preamble,xsize,ysize,
	  pic.keepAspect ? Aspect : IgnoreAspect,orientation,format,wait);
}

void shipout(string prefix=defaultfilename,
	     real xsize=infinity, real ysize=infinity,
	     orientation orientation=Portrait, string format="",
	     wait wait=NoWait)
{
  shipout(prefix,currentpicture,xsize,ysize,
	  currentpicture.keepAspect ? Aspect : IgnoreAspect,
	  orientation,format,wait);
}

void erase(picture pic=currentpicture)
{
  pic.erase();
}

// End of flex routines

real cap(real x, real m, real M, real bottom, real top)
{
  return x+top > M ? M-top : x+bottom < m ? m-bottom : x;
}

// Scales pair z, so that when drawn with pen p, it does not exceed box(lb,rt).
pair cap(pair z, pair lb, pair rt, pen p=currentpen)
{

  return (cap(z.x,lb.x,rt.x,min(p).x,max(p).x),
          cap(z.y,lb.y,rt.y,min(p).y,max(p).y));
}

real xtrans(transform t, real x)
{
  return (t*(x,0)).x;
}

real ytrans(transform t, real y)
{
  return (t*(0,y)).y;
}

real cap(transform t, real x, real m, real M, real bottom, real top,
                   real ct(transform,real))
{
  return x == infinity  ? M-top :
         x == -infinity ? m-bottom : cap(ct(t,x),m,M,bottom,top);
}

pair cap(transform t, pair z, pair lb, pair rt, pen p=currentpen)
{
  if (finite(z.x) && finite(z.y))
    return cap(t*z, lb, rt, p);
  else
    return (cap(t,z.x,lb.x,rt.x,min(p).x,max(p).x,xtrans),
            cap(t,z.y,lb.y,rt.y,min(p).y,max(p).y,ytrans));
}
  
void clip(picture pic=currentpicture, pair lb, pair tr)
{
  clip(pic,box(lb,tr));
}

void label(picture pic=currentpicture, real angle=0, pair position,
	   pair align=0, pair shift=0, pen p=currentpen)
{
  label(pic,(string) position,angle,position,align,shift,p);
}

private struct sideT {};
public sideT side=null;
typedef pair side(pair, sideT);
public side
  LeftSide=new pair(pair align, sideT) {return -align;},
  Center=new pair(pair align, sideT) {return 0;},
  RightSide=new pair(pair align, sideT) {return align;};

void label(picture pic=currentpicture, string s, real angle=0,
	   path g, real position=infinity, pair align=0, pair shift=0,
	   side side=RightSide, pen p=currentpen)
{
  real L=length(g);
  if(position == infinity) position=0.5L;
  if(align == 0) {
    if(position <= 0) align=-dir(g,0);
    else if(position >= L) align=dir(g,L);
    else align=side(-dir(g,position)*I,side);
  }
  label(pic,s,angle,point(g,position),align,shift,p);
}

void dot(picture pic=currentpicture, pair c)
{
  _draw(pic,c,currentpen+linewidth(currentpen)*dotfactor);
}

void dot(picture pic=currentpicture, pair c, pen p)
{
  _draw(pic,c,linewidth(p)*dotfactor+p);
}

void dot(picture pic=currentpicture, pair[] c, pen p=currentpen)
{
  for(int i=0; i < c.length; ++i) dot(pic,c[i],p);
}

void dot(picture pic=currentpicture, guide g, pen p=currentpen)
{
  for(int i=0; i <= length(g); ++i) dot(pic,point(g,i),p);
}

void labeldot(picture pic=currentpicture, string s="", real angle=0,
	      pair c, pair align=E, pair shift=0, pen p=currentpen)
{
  if(s == "") s=(string) c;
  dot(pic,c,p);
  label(pic,s,angle,c,align,shift,p);
}

void arrow(picture pic=currentpicture, string s, real angle=0, pair shift=0,
	   path g, pen p=currentpen, real size=arrowsize,
	   real Angle=arrowangle, arrowhead arrowhead=Fill)
{
  add(pic,arrow(g,p,size,Angle,arrowhead));
  pair a=point(g,0);
  pair b=point(g,1);
  label(pic,s,angle,a,unit(a-b),shift,p);
}

guide unitsquare=(0,0)--(1,0)--(1,1)--(0,1)--cycle;

guide square(pair z1, pair z2)
{
  pair v=z2-z1;
  pair z3=z2+I*v;
  pair z4=z3-v;
  return z1--z2--z3--z4--cycle;
}

guide unitcircle=E..N..W..S..cycle;

guide circle(pair c, real r)
{
  return shift(c)*scale(r)*unitcircle;
}

guide ellipse(pair c, real a, real b)
{
  return shift(c)*xscale(a)*yscale(b)*unitcircle;
}

private struct directionT {};
public directionT direction=null;
typedef bool direction(directionT);
public direction
  CCW=new bool(directionT) {return true;},
  CW=new bool(directionT) {return false;};

// return an arc centered at c with radius r from angle1 to angle2 in degrees,
// drawing in the given direction.
guide arc(pair c, real r, real angle1, real angle2, direction direction)
{
  real t1=intersect(unitcircle,(0,0)--2*dir(angle1)).x;
  real t2=intersect(unitcircle,(0,0)--2*dir(angle2)).x;
  static int n=length(unitcircle);
  if(t1 >= t2 && direction(direction)) t1 -= n;
  if(t2 >= t1 && !direction(direction)) t2 -= n;
  return shift(c)*scale(r)*subpath(unitcircle,t1,t2);
}
  
// return an arc centered at c with radius r > 0 from angle1 to angle2 in
// degrees, drawing counterclockwise if angle2 >= angle1 (otherwise clockwise).
// If r < 0, draw the complementary arc of radius |r|.
guide arc(pair c, real r, real angle1, real angle2)
{
  bool pos=angle2 >= angle1;
  if(r > 0) return arc(c,r,angle1,angle2,pos ? CCW : CW);
  else return arc(c,-r,angle1,angle2,pos ? CW : CCW);
}

// return an arc centered at c from pair z1 to z2 (assuming |z2-c|=|z1-c|),
// drawing in the given direction.
guide arc(pair c, explicit pair z1, explicit pair z2, direction direction=CCW)
{
  return arc(c,abs(z1-c),Angle(z1-c),Angle(z2-c),direction);
}

picture bar(pair a, pair d, pen p=currentpen)
{
  picture pic=new picture;
  _drawabout(a,pic,-0.5d--0.5d,p+solid);
  return pic;
}

private struct arrowbarT {
  public bool drawpath=true;
};
public arrowbarT arrowbar=null;

typedef void arrowbar(picture, path, pen, arrowbarT);

arrowbar Blank()
{
  return new void(picture pic, path g, pen p, arrowbarT arrowbar) {
    arrowbar.drawpath=false;
  };	
}

arrowbar None()
{
  return new void(picture pic, path g, pen p, arrowbarT arrowbar) {};	
}

arrowbar BeginArrow(real size=arrowsize, real angle=arrowangle,
		    arrowhead arrowhead=Fill, real position=infinity)
{
  return new void(picture pic, path g, pen p, arrowbarT arrowbar) {
    arrowbar.drawpath=false;
    add(pic,arrow(reverse(g),p,size,angle,arrowhead,position));
  };
}

arrowbar Arrow(real size=arrowsize, real angle=arrowangle,
	       arrowhead arrowhead=Fill, real position=infinity)
{
  return new void(picture pic, path g, pen p, arrowbarT arrowbar) {
    arrowbar.drawpath=false;
    add(pic,arrow(g,p,size,angle,arrowhead,position));
  };
}

arrowbar EndArrow(real size=arrowsize, real angle=arrowangle,
		  arrowhead arrowhead=Fill, real position=infinity)
{
  return Arrow(size,angle);
}

arrowbar Arrows(real size=arrowsize, real angle=arrowangle,
		arrowhead arrowhead=Fill, real position=infinity)
{
  return new void(picture pic, path g, pen p, arrowbarT arrowbar) {
    arrowbar.drawpath=false;
    add(pic,arrow2(g,p,size,angle,arrowhead));
  };
}

arrowbar BeginArcArrow(real size=arcarrowsize, real angle=arcarrowangle,
		       arrowhead arrowhead=Fill, real position=infinity)
{
  return BeginArrow(size,angle,arrowhead,position);
}

arrowbar ArcArrow(real size=arcarrowsize, real angle=arcarrowangle,
		  arrowhead arrowhead=Fill, real position=infinity)
{
  return Arrow(size,angle,arrowhead,position);
}

arrowbar EndArcArrow(real size=arcarrowsize, real angle=arcarrowangle,
		     arrowhead arrowhead=Fill, real position=infinity)
{
  return Arrow(size,angle,arrowhead,position);
}
  
arrowbar ArcArrows(real size=arcarrowsize, real angle=arcarrowangle,
		   arrowhead arrowhead=Fill, real position=infinity)
{
  return Arrows(size,angle,arrowhead,position);
}
  
arrowbar BeginBar(real size=barsize) 
{
  return new void(picture pic, path g, pen p, arrowbarT) {
    add(pic,bar(point(g,0),size*dir(g,0)*I,p));
  };
}

arrowbar Bar(real size=barsize) 
{
  return new void(picture pic, path g, pen p, arrowbarT) {
    int L=length(g);
    add(pic,bar(point(g,L),size*dir(g,L)*I,p));
  };
}

arrowbar EndBar(real size=barsize) 
{
  return Bar(size);
}

arrowbar Bars(real size=barsize) 
{
  return new void(picture pic, path g, pen p, arrowbarT) {
    BeginBar(size)(pic,g,p,arrowbar);
    EndBar(size)(pic,g,p,arrowbar);
  };
}

public arrowbar
  Blank=Blank(),
  None=None(),
  BeginArrow=BeginArrow(),
  Arrow=Arrow(),
  EndArrow=Arrow(),
  Arrows=Arrows(),
  BeginArcArrow=BeginArcArrow(),
  ArcArrow=ArcArrow(),
  EndArcArrow=ArcArrow(),
  ArcArrows=ArcArrows(),
  BeginBar=BeginBar(),
  Bar=Bar(),
  EndBar=Bar(),
  Bars=Bars();

void draw(picture pic=currentpicture, string s="", real angle=0,
	  path g, real position=infinity, pair align=0, pair shift=0,
	  side side=RightSide, pen p=currentpen,
	  arrowbar arrow=None, arrowbar bar=None, string legend="")
{
  arrowbarT arrowbar=new arrowbarT;
  if(s != "") label(pic,s,angle,g,position,align,shift,side,p);
  bar(pic,g,p,arrowbar);
  arrow(pic,g,p,arrowbar);
  if(arrowbar.drawpath) _draw(pic,g,p);
  if(legend != "") {
    Legend L=new Legend; L.label=legend; L.p=p;
    pic.legend.push(L);
  }
}

// Draw a fixed-size object about the user-coordinate 'origin'.
void drawabout(pair origin, picture pic=currentpicture, string s="",
	       real angle=0, path g, real position=infinity, pair align=0,
	       pair shift=0, side side=RightSide, pen p=currentpen,
	       arrowbar arrow=None, arrowbar bar=None)
{
  picture opic=new picture;
  draw(opic,s,angle,g,position,align,shift,side,p,arrow,bar);
  addabout(origin,pic,opic);
}

void arrow(picture pic=currentpicture, string s="", real angle=0,
	   pair b, pair align, real length=arrowlength, pair shift=0,
	   pen p=currentpen, real size=arrowsize, real Angle=arrowangle,
	   arrowhead arrowhead=Fill)
{
  pair a,c;
  pair dir=unit(align);
  if(s == "") {
    a=0; c=length*dir;
  } else {
    c=labelmargin(p)*dir;
    a=length*dir+c;
  }
  drawabout(b,pic,s,angle,a--c,0.0,align,shift,p,Arrow(size,Angle,arrowhead));
}

string substr(string s, int pos)
{
  return substr(s,pos,-1);
}

int find(string s, string t)
{
  return find(s,t,0);
}

int rfind(string s, string t)
{
  return rfind(s,t,-1);
}

// returns a string with all occurrences of string 'from' in string 's'
// changed to string 'to'
string replace(string s, string from, string to) 
{
  return replace(s,new string[][] {{from,to}});
}

// Like texify but don't convert embedded TeX commands: \${}
string TeXify(string s) 
{
  static string[][] t={{"&","\&"},{"%","\%"},{"_","\_"},{"#","\#"},{"<","$<$"},
		       {">","$>$"},{"|","$|$"},{"^","$\hat{\ }$"},{". ",".\ "},
                       {"~","$\tilde{\ }$"}};
  return replace(s,t);
}

// Convert string to TeX
string texify(string s) 
{
  static string[][] t={{'\\',"\backslash "},{"$","\$"},{"{","\{"},{"}","\}"}};
  static string[][] u={{"\backslash ","$\backslash$"}};
  return TeXify(replace(replace(s,t),u));
}

string italic(string s)
{
  if(s == "") return s;
  return "{\it "+s+"}";
}

string baseline(string s, pair align=S, string template="M") 
{
  if(s == "") return s;
  return align.y <= -0.5*abs(align.x) ? 
    "\setbox\ASYbox=\hbox{"+template+"}\ASYdimen=\ht\ASYbox%
\setbox\ASYbox=\hbox{"+s+"}\lower\ASYdimen\box\ASYbox" : s;
}

string math(string s)
{
  if(s == "") return s;
  return "$"+s+"$";
}

string minipage(string s, real width=100pt)
{
  return "\begin{minipage}{"+(string) (width*pt)+"pt}"+s+"\end{minipage}";
}

string math(real x)
{
  return math((string) x);
}

private struct keepT {};
public keepT keep=null;
typedef bool keep(keepT);
public keep
  Keep=new bool(keepT) {return true;},
  Purge=new bool(keepT) {return false;};

// delay is in units of 0.01s
int gifmerge(int loops=0, int delay=50, keep keep=Purge)
{
  return merge("-loop " +(string) loops+" -delay "+(string)delay,"gif",
	       keep(keep));
}

// Return the sequence 0,1,...n-1
int[] sequence(int n) {return sequence(new int(int x){return x;},n);}
// Return the sequence n,...m
int[] sequence(int n, int m) {
  return sequence(new int(int x){return x;},m-n+1)+n;
}
int[] reverse(int n) {return sequence(new int(int x){return n-1-x;},n);}

bool[] reverse(bool[] a) {return a[reverse(a.length)];}
int[] reverse(int[] a) {return a[reverse(a.length)];}
real[] reverse(real[] a) {return a[reverse(a.length)];}
pair[] reverse(pair[] a) {return a[reverse(a.length)];}
string[] reverse(string[] a) {return a[reverse(a.length)];}

int find(bool[] a) {return find(a,1);}

// Transform coordinate in [0,1]x[0,1] to current user coordinates.
// This might be improved with deferring drawing...
pair relative(picture pic=currentpicture, pair z)
{
  pair w=(pic.userMax-pic.userMin);
  return pic.userMin+(z.x*w.x,z.y*w.y);
}

void pause(string w="Hit enter to continue") 
{
  write(w);
  w=stdin;
}

// Options for handling label overwriting
private struct OverwriteT {};
public OverwriteT Overwrite=null;
typedef int Overwrite(OverwriteT);
public Overwrite
  Allow=new int(OverwriteT) {return 0;},
  Suppress=new int(OverwriteT) {return 1;},
  SuppressQuiet=new int(OverwriteT) {return 2;},
  Move=new int(OverwriteT) {return 3;},
  MoveQuiet=new int(OverwriteT) {return 4;};
    
pen overwrite(Overwrite Overwrite) 
{
  return overwrite(Overwrite(Overwrite));
}

private struct LinecapT {};
public LinecapT Linecap=null;
typedef int Linecap(LinecapT);
public Linecap
  Square=new int(LinecapT) {return 0;},
  Round=new int(LinecapT) {return 1;},
  Extended=new int(LinecapT) {return 2;};
  
pen linecap(Linecap Linecap)
{
  return linecap(Linecap(Linecap));
}

private struct LinejoinT {};
public LinejoinT Linejoin=null;
typedef int Linejoin(LinejoinT);
public Linejoin
  Miter=new int(LinejoinT) {return 0;},
  Round=new int(LinejoinT) {return 1;},
  Bevel=new int(LinejoinT) {return 2;};
  
pen linejoin(Linejoin Linejoin)
{
  return linejoin(Linejoin(Linejoin));
}

struct slice {
  public path before,after;
}

slice firstcut(path p, path knife) 
{
  slice s=new slice;
  real t=intersect(p,knife).x;
  if (t < 0) {s.before=p; s.after=nullpath; return s;}
  s.before=subpath(p,0,min(t,intersect(p,reverse(knife)).x));
  s.after=subpath(p,min(t,intersect(p,reverse(knife)).x),length(p));
  return s;
}

slice lastcut(path p, path knife) 
{
  slice s=firstcut(reverse(p),knife);
  path before=reverse(s.after);
  s.after=reverse(s.before);
  s.before=before;
  return s;
}

real interp(int a, int b, real c)
{
  return a+c*(b-a);
}

real interp(real a, real b, real c)
{
  return a+c*(b-a);
}

pair interp(pair a, pair b, real c)
{
  return a+c*(b-a);
}

pen interp(pen a, pen b, real c) 
{
  return (1-c)*a+c*b;
}

string format(real x) {
  return format("%.9g",x);
}

frame tiling(string name, picture pic, pair lb=0, pair rt=0)
{
  frame tiling;
  frame f=pic.fit(identity());
  pair pmin=min(f)-lb;
  pair pmax=max(f)-rt;
  postscript(tiling,"<< /PaintType 1 /PatternType 1 /TilingType 1 
/BBox ["+format(pmin.x)+" "+format(pmin.y)+" "+format(pmax.x)+" "
	     +format(pmax.y)+"]
/XStep "+format(pmax.x-pmin.x)+"
/YStep "+format(pmax.y-pmin.y)+"
/PaintProc {pop");
  add(tiling,f);
  postscript(tiling,"} >>
 matrix makepattern
/"+name+" exch def");
  return tiling;
}

void add(frame preamble=patterns, string name, picture pic, pair lb=0,
	 pair rt=0)
{
  add(preamble,tiling(name,pic,lb,rt));
}

pair dir(path g)
{
  return dir(g,length(g));
}

pair dir(path g, path h)
{
  return 0.5*(dir(g)+dir(h));
}

// return the point on path p at arclength L
pair arcpoint(path p, real L)
{
    return point(p,arctime(p,L));
}

// return the point on path p at the given relative fraction of its arclength
pair relpoint(path p, real l)
{
  return arcpoint(p,l*arclength(p));
}

// return the direction on path p at arclength L
pair arcdir(path p, real L)
{
    return dir(p,arctime(p,L));
}

// return the direction of path p at the given relative fraction of its
// arclength
pair reldir(path p, real l)
{
  return arcdir(p,l*arclength(p));
}

// return the initial point of path p
pair beginpoint(path p)
{
    return point(p,0);
}

// return the point on path p at half of its arclength
pair midpoint(path p)
{
    return relpoint(p,0.5);
}

// return the final point of path p
pair endpoint(path p)
{
    return point(p,length(p));
}

pen[] colorPens={red,blue,green,magenta,cyan,orange,purple,brown,darkgreen,
		 darkblue,chartreuse,fuchsia,salmon,lightblue,black,lavender,
		 pink,yellow,gray};
pen[] monoPens={solid,dashed,dotted,longdashed,dashdotted,longdashdotted};

public bool mono=false;
pen Pen(int n) 
{
  return mono ? monoPens[n % monoPens.length] : 
    colorPens[n % colorPens.length];
}
