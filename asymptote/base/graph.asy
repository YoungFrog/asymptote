public real ticksize=1mm;
public real Ticksize=2*ticksize;
public real ylabelwidth=2.0;
public real axislabelmargin=2;
public real axiscoverage=0.6;
public int ngraph=100;

private real epsilon=100*realEpsilon();

scaleT Linear=new scaleT;
Linear.T=identity;
Linear.Tinv=identity;

scaleT Log=new scaleT;
Log.T=log10;
Log.Tinv=pow10;
Log.Label=identity;

public scaleT Linear(bool automin=true, bool automax=true, real s=1,
		     real intercept=0)
{
  real sinv=1/s;
  scaleT scale=new scaleT;
  scale.T=new real(real x) {return (x-intercept)*s;};
  scale.Tinv=new real(real x) {return x*sinv+intercept;};
  scale.Label=scale.Tinv;
  scale.automin=automin;
  scale.automax=automax;
  return scale;
}

public scaleT Log(bool automin=true, bool automax=true)
{
  scaleT scale=Log;
  scale.automin=automin;
  scale.automax=automax;
  return scale;
}

real scalefcn_operators(real x) {return 0;}

bool logarithmic(scaleT S) 
{
  return S.T == log10 && S.Label == identity;
}

void scale(picture pic=currentpicture, scaleT x, scaleT y)
{
  pic.scale.x.scale=x;
  pic.scale.y.scale=y;
}

struct scientific 
{
  public int sign;
  public real mantissa;
  public int exponent;
  int ceil() {return sign*ceil(mantissa);}
  real scale(real x, real exp) {return exp > 0 ? x/10^exp : x*10^-exp;}
  real ceil(real x, real exp) {return ceil(sign*scale(abs(x),exp));}
  real floor(real x, real exp) {return floor(sign*scale(abs(x),exp));}
}

scientific scientific(real x) 
{
    scientific s=new scientific;
    s.sign=sgn(x);
    x=abs(x);
    if(x == 0) {s.mantissa=0; s.exponent=-intMax(); return s;}
    real logx=log10(x);
    s.exponent=floor(logx);
    s.mantissa=s.scale(x,s.exponent);
    return s;
}

struct bounds {
  public real min=0;
  public real max=0;
  // Possible tick intervals;
  public int[] divisor=new int[];
}

int[] divisors(int a, int b)
{
  int[] dlist;
  int n=b-a;
  int sqrtn=floor(sqrt(n));
  int i=0;
  dlist[0]=1;
  for(int d=2; d <= sqrtn; ++d)
    if(n % d == 0 && (a*b >= 0 || b % (n/d) == 0)) dlist[++i]=d;
  for(int d=sqrtn; d >= 1; --d)
    if(n % d == 0 && (a*b >= 0 || b % d == 0)) dlist[++i]=n/d;
  return dlist;
}

real upscale(real b, real a)
{
  if(b <= 5) b=5; 
  else if (b > 10 && a >= 0 && b <= 12) b=12;
  else if (b > 10 && (a >= 0 || 15 % -a == 0) && b <= 15) b=15;
  else b=ceil(b/10)*10;
  return b;
}

bounds autoscale(real Min, real Max, bool logaxis=false)
{
  bounds m=new bounds;
  if(logaxis) {
    m.min=floor(Min);
    m.max=ceil(Max);
    return m;
  }
  m.min=Min;
  m.max=Max;
  if(Min == infinity && Max == -infinity) return m;
  if(Min > Max) {real tmp=Min; Min=Max; Max=tmp;}
  if(Min == Max) {
    if(Min == 0) {m.max=1; return m;}
    if(Min > 0) {Min=0; Max *= 2;}
    else {Min *= 2; Max=0;}
  }
  
  int sign;
  if(Min < 0 && Max <= 0) {real temp=-Min; Min=-Max; Max=temp; sign=-1;}
  else sign=1;
  scientific sa=scientific(Min);
  scientific sb=scientific(Max);
  int exp=max(sa.exponent,sb.exponent);
  real a=sa.floor(Min,exp);
  real b=sb.ceil(Max,exp);
//  if(sb.mantissa < 1.5 || (a < 0 && sa.mantissa < 1.5)) {
  if(sb.mantissa <= 1.5) {
    --exp;
    a=sa.floor(Min,exp);
    b=sb.ceil(Max,exp);
  }
  
  real bsave=b;
  if(b-a > (a >= 0 ? 8 : 6)) {
    b=upscale(b,a);
    if(a >= 0) {
      if(a <= 5) a=0; else a=floor(a/10)*10;
    } else a=-upscale(-a,-1);
  }
  
  // Redo b in case the value of a has changed
  if(bsave-a > (a >= 0 ? 8 : 6))
    b=upscale(bsave,a);
  
  if(sign == -1) {real temp=-a; a=-b; b=temp;}
  real scale=10.0^exp;
  m.min=a*scale;
  m.max=b*scale;
  m.divisor=divisors(round(a),round(b));
  return m;
}

typedef real part(pair);

struct ticksT {};
private ticksT ticks=null;
typedef void ticks(frame, transform, string, real, real, pair, pair, pair, 
		   pen, path, pen, scaleT, part, bool, bool, int[], real, real,
		   ticksT);
typedef string ticklabel(real);

string defaultticklabel(real x) {return math(format("%.4g",x));}

void labelaxis(frame f, string s, real position, real angle, pair align,
	       pair shift, guide g, pen p, bool labels, bool deconstruct)
{
  pair z=point(g,position);
  pair dir=dir(g,position);
  if(labels) {
    pair minf=min(f);
    pair maxf=max(f);
    pair offset=(align.x > 0 ? maxf.x : (align.x < 0 ? minf.x : 0),
		 align.y > 0 ? maxf.y : (align.y < 0 ? minf.y : 0))-z;
    pair Idir=I*dir;
    z += Dot(offset,Idir)*Idir;
  }
  if(deconstruct) {
    if(GUIDelete()) return;
    z=GUI()*z;
  }
  frame d;
  label(d,s,angle,z,labels ? axislabelmargin*align : align,p);
  if(deconstruct) deconstruct(d);
  pair width=0.5*Dot(max(d)-min(d),dir)*dir;
  if(position == 0) d=shift(width)*d;
  if(position == length(g)) d=shift(-width)*d;
  add(f,d);
}

ticklabel LogFormat=new string(real x) {
  return (string) format("$10^{%f}$",x);
};

private struct locateT {
  pair z; // User location 
  pair Z; // Frame location
  pair dir; // Frame direction
  bool calc(transform T, guide g, real pos) {
    real t=arctime(g,pos);
    z=point(g,t);
    Z=T*z;
    dir=unit(T*dir(g,t));
    return true;
  }
}

pair ticklabelshift(pair align, pen p=currentpen) 
{
  return 0.25*unit(align)*labelmargin(p);
}

pair labeltick(frame d, transform T, guide g, real pos, pair side,
	       int sign, real Size, ticklabel ticklabel, pen plabel, part part,
	       real norm=0, bool deconstruct=false) 
{
  locateT locate=new locateT;
  locate.calc(T,g,pos);
  pair align=-side*I*locate.dir;
  pair shift=Dot(align,I*sign*locate.dir) < 0 ? align*Size :
    ticklabelshift(align,plabel);
  pair Z=locate.Z+shift;
  if(deconstruct) Z=GUI()*Z;
  real v=part(locate.z);
  if(abs(v) < epsilon*norm) v=0;
  string s=ticklabel(v);
  s=baseline(s,align,"$10^4$");
  label(d,s,Z,align,plabel);
  return locate.dir;
}  

ticks Ticks(bool begin=true, int sign, int N, int n=0, real Step=0,
	    real step=0, real Size=0, real size=0,
	    ticklabel ticklabel=defaultticklabel, bool end=true)
{
  locateT locate=new locateT;
  uptodate(false);
  return new void(frame f, transform T, string s, real position, real angle,
		  pair align, pair shift, pair side, pen plabel, path G, pen p,
		  scaleT S, part part, bool deconstruct, bool opposite,
		  int[] divisor, real tickmin, real tickmax, ticksT) {
    // Use local copy of context variables:
    int sign=opposite ? -sign : sign;
    int N=N;
    int n=n;
    real Step=Step;
    real step=step;
    
    bool labels=false;
    guide g=inverse(T)*G;
    
    if(!logarithmic(S)) {
      real a=part(point(g,0));
      real b=part(point(g,length(g)));
      if(!finite(tickmin)) tickmin=S.T(0);
      if(!finite(tickmax)) tickmax=S.T(arclength(g));
      real len=tickmax-tickmin;
      real offset=tickmin-S.T(a);
      real norm=max(abs(a),abs(b));
      if(Step == 0 && N == 0) {
	if(divisor.length > 0) {
	  real limit=axiscoverage*arclength(G);
	  for(int d=divisor.length-1; d >= 0; --d) {
	    N=divisor[d];
	    Step=len/N;
	    real coverage=0;
	    for(int i=0; i <= N; ++i) {
	      frame d;
	      pair dir=labeltick(d,T,g,i*Step,side,sign,Size,ticklabel,plabel,
				 part,norm);
	      coverage += abs(Dot(max(d)-min(d),dir));
	      if(coverage > limit) break;
	    }
	    if(coverage <= limit) {
	      // Found a good divisor; now compute subtick divisor
	      if(n == 0) {
		n=divisor[-1]/N;
		if(N == 1) n=(a*b >= 0) ? 2 : 1;
		if(n == 1) n=2;
	      }
	      break;
	    }
	  }
	} else N=1;
      }
      
      if(N == 0) N=(int) (len/Step);
      else {
	Step=len/N;
	if(cyclic(g) && len == arclength(g)) --N;
      }

      if(n == 0) {
	if(step != 0) n=ceil(Step/step);
      } else step=Step/n;
      
      real lastpos=S.T(b)-S.T(a);
      real firstpos=-epsilon*lastpos;
      lastpos *= (1+epsilon);
      if(!deconstruct || !GUIDelete()) {
	frame d;
	draw(d,G,p);
	if(Size > 0) for(int i=0; i <= N; ++i) {
	  real pos=i*Step+offset;
	  if(cyclic(g) || (pos >= firstpos && pos <= lastpos)) {
	    locate.calc(T,g,pos);
	    draw(d,locate.Z--locate.Z-Size*I*sign*locate.dir,p);
	  }
	  if(size > 0 && step > 0) {
	    real iStep=i*Step;
	    real jstop=(len-iStep)/step;
	    iStep += offset;
	    for(int j=1; j < n && j <= jstop; ++j) {
	      real pos=iStep+j*step;
	      if(cyclic(g) || (pos >= firstpos && pos <= lastpos)) {
		locate.calc(T,g,pos);
		draw(d,locate.Z--locate.Z-size*I*sign*locate.dir,p);
	      }
	    }
	  }
	}
	if(deconstruct) deconstruct(d);
	add(f,d);
      }
    
      if(Size > 0 && !opposite) {
	for(int i=0; i <= N; ++i) {
	  if(i == 0 && !begin) continue;
	  if(i == N && !end) continue;
	  if(!deconstruct || !GUIDelete()) {
	    labels=true;
	    frame d;
	    real pos=i*Step+offset;
	    if(cyclic(g) || (pos >= firstpos && pos <= lastpos)) {
	    labeltick(d,T,g,pos,side,sign,Size,ticklabel,plabel,part,
		      norm,deconstruct);
	    }
	      if(deconstruct) deconstruct(d);
	      add(f,d);
	  }
	}
      }

    } else { // Logarithmic
      if(N == 0) {N=1; n=10;}
      else if(N > 1) n=0;
      real initial=part(point(g,0));
      real final=part(point(g,length(g)));
      int first=ceil(initial-epsilon);
      int last=floor(final+epsilon);
      real len=arclength(g);
      real denom=final-initial;
      real factor=denom != 0 ? len/denom : len;
    
      if(!deconstruct || !GUIDelete()) {
	frame d;
	draw(d,G,p);
	if(N > 0) for(int i=first; i <= last; i += N) {
	  locate.calc(T,g,(i-initial)*factor);
	  draw(d,locate.Z--locate.Z-Size*I*sign*locate.dir,p);
	  if(n > 0) {
	    for(int j=2; j < n; ++j) {
	      real pos=(i-initial+1+log10((real) j/n))*factor;
	      if(pos > len+epsilon) break;
	      locate.calc(T,g,pos);
	      draw(d,locate.Z--locate.Z-size*I*sign*locate.dir,p);
	    }
	  }
	}
	if(deconstruct) deconstruct(d);
	add(f,d);
      }
    
      if(!opposite && N > 0) for(int i=first; i <= last; i += N) {
	if(i == first && !begin) continue;
	if(i == last && !end) continue;
	if(!deconstruct || !GUIDelete()) {
	  labels=true;
	  frame d;
	  labeltick(d,T,g,(i-initial)*factor,side,sign,Size,LogFormat,plabel,
		part,deconstruct);
	  if(deconstruct) deconstruct(d);
	  add(f,d);
	}
      }
    }
    
    if(s != "" && !opposite) 
      labelaxis(f,s,position,angle,align,shift,G,plabel,labels,deconstruct);
  };
}

ticks NoTicks()
{
  return Ticks(1,-1);
}

ticks LeftTicks(bool begin=true, int N=0, int n=0, real Step=0, real step=0,
		real Size=Ticksize, real size=ticksize,
		ticklabel ticklabel=defaultticklabel,
		bool end=true)
{
  return Ticks(begin,-1,N,n,Step,step,Size,size,ticklabel,end);
}

ticks LeftTicks(bool begin=true, int N=0, int n=0, real Step=0, real step=0,
		real Size=Ticksize, real size=ticksize, string F,
		bool end=true)
{
  return Ticks(begin,-1,N,n,Step,step,Size,size,
	       new string(real x) {return math(format(F,x));},end);
}

ticks RightTicks(bool begin=true, int N=0, int n=0, real Step=0, real step=0,
		 real Size=Ticksize, real size=ticksize,
		 ticklabel ticklabel=defaultticklabel, bool end=true)
{
  return Ticks(begin,1,N,n,Step,step,Size,size,ticklabel,end);
}

ticks RightTicks(bool begin=true, int N=0, int n=0, real Step=0, real step=0,
		 real Size=Ticksize, real size=ticksize, string F,
		 bool end=true)
{
  return Ticks(begin,1,N,n,Step,step,Size,size,
	       new string(real x) {return math(format(F,x));},end);
}

public ticks
  NoTicks=NoTicks(),
  LeftTicks=LeftTicks(),
  RightTicks=RightTicks();

void axis(picture pic=currentpicture, guide g,
	  real tickmin=-infinity, real tickmax=infinity, pen p=currentpen,
	  string s="", real position=1, real angle=0, pair align=S,
	  pair shift=0, pair side=right, pen plabel=currentpen,
	  ticks ticks=NoTicks, int[] divisor=new int[],
	  bool logarithmic=false, scaleT scale=Linear, part part,
	  bool opposite=false) 
{
  pic.add(new void (frame f, transform t, transform T, pair lb, pair rt) {
    frame d;
    ticks(d,t,s,position,angle,align,shift,side,plabel,t*g,p,scale,part,
	  pic.deconstruct,opposite,divisor,tickmin,tickmax,ticks);
    add(f,t*T*inverse(t)*d);
  });
  
  pic.addPath(g,p);
  
  if(s != "") {
    frame f;
    label(f,s,angle,(0,0),align,plabel);
    pair pos=point(g,position*length(g));
    pic.addBox(pos,pos,min(f),max(f));
  }
}

void xequals(picture pic=currentpicture, real x,
	     real ymin=-infinity, real ymax=infinity, 
	     real tickmin=-infinity, real tickmax=infinity, pen p=currentpen,
	     string s="", real position=1, real angle=0, pair align=W,
	     pair shift=0, pair side=right, pen plabel=currentpen,
	     ticks ticks=NoTicks, int[] divisor=new int[], bool opposite=false)
{
  pic.add(new void (frame f, transform t, transform T, pair lb, pair rt) {
    pair a=ymin == -infinity ? (xtrans(t,x),lb.y-min(p).y) : t*(x,ymin);
    pair b=ymax == infinity ? (xtrans(t,x),rt.y-max(p).y) : t*(x,ymax);
    frame d;
    ticks(d,t,s,position,angle,align,shift,side,plabel,a--b,p,
	  pic.scale.y.scale,
	  new real(pair z) {return pic.scale.y.scale.Label(z.y);},
	  pic.deconstruct,opposite,divisor,tickmin,tickmax,ticks);
    add(f,t*T*inverse(t)*d);
  });
  
  pair a=(x,finite(ymin) ? ymin : pic.userMin.y);
  pair b=(x,finite(ymax) ? ymax : pic.userMax.y);
  
  pic.addPoint(a,p);
  pic.addPoint(b,p);
  
  if(finite(a) && finite(b)) {
    frame d;
    ticks(d,identity(),s,position,angle,align,shift,side,plabel,
	  (0,a.y)--(0,b.y),p,pic.scale.y.scale,
	  new real(pair z) {return pic.scale.y.scale.Label(z.y);},
	  false,opposite,divisor,tickmin,tickmax,ticks);
    frame f;
    if(s != "") label(f,s,angle,(0,0),align,plabel);
    pair pos=a+position*(b-a);
    pic.addBox(pos,pos,(min(d).x,min(f).y),(max(d).x,max(f).y));
  }
}

void yequals(picture pic=currentpicture, real y,
	     real xmin=-infinity, real xmax=infinity,
	     real tickmin=-infinity, real tickmax=infinity, pen p=currentpen,
	     string s="", real position=1, real angle=0, pair align=S, 
	     pair shift=0, pair side=left, pen plabel=currentpen,
	     ticks ticks=NoTicks, int[] divisor=new int[], bool opposite=false)
{
  pic.add(new void (frame f, transform t, transform T, pair lb, pair rt) {
    pair a=xmin == -infinity ? (lb.x-min(p).x,ytrans(t,y)) : t*(xmin,y);
    pair b=xmax == infinity ? (rt.x-max(p).x,ytrans(t,y)) : t*(xmax,y);
    frame d;
    ticks(d,t,s,position,angle,align,shift,side,plabel,a--b,p,
	  pic.scale.x.scale,
	  new real(pair z) {return pic.scale.x.scale.Label(z.x);},
	  pic.deconstruct,opposite,divisor,tickmin,tickmax,ticks);
    add(f,t*T*inverse(t)*d);
  });

  pair a=(finite(xmin) ? xmin : pic.userMin.x,y);
  pair b=(finite(xmax) ? xmax : pic.userMax.x,y);
  
  pic.addPoint(a,p);
  pic.addPoint(b,p);
  
  if(finite(a) && finite(b)) {
    frame d;
    ticks(d,identity(),s,position,angle,align,shift,side,plabel,
	  (a.x,0)--(b.x,0),p,pic.scale.x.scale,
	  new real(pair z) {return pic.scale.y.scale.Label(z.x);},
	  false,opposite,divisor,tickmin,tickmax,ticks);
    frame f;
    if(s != "") label(f,s,angle,(0,0),align,plabel);
    pair pos=a+position*(b-a);
    pic.addBox(pos,pos,(min(f).x,min(d).y),(max(f).x,max(d).y));
  }
}

private struct axisT {
  public pair value;
  public real position;
  public pair side;
  public pair align;
  public pair value2;
  
  public pair userMin;
  public pair userMax;
  public int[] xdivisor;
  public int[] ydivisor;
  public bool extend;
};

public axisT axis=new axisT;
typedef void axis(picture, axisT);

axis Bottom(bool extend=false) {
  return new void(picture pic, axisT axis) {
    axis.value=pic.scale.y.automin ?
      (pic.scale.x.tickMin,pic.scale.y.tickMin) : axis.userMin;
    axis.position=0.5;
    axis.side=right;
    axis.align=S;
    axis.value2=infinity;
    axis.extend=extend;
  };
}

axis Top(bool extend=false) {
  return new void(picture pic, axisT axis) {
    axis.value=pic.scale.y.automax ?
    (pic.scale.x.tickMax,pic.scale.y.tickMax) : axis.userMax;
    axis.position=0.5;
    axis.side=left;
    axis.align=N;
    axis.value2=infinity;
    axis.extend=extend;
  };
}

axis BottomTop(bool extend=false) {
  return new void(picture pic, axisT axis) {
    axis.value=pic.scale.y.automin ?
    (pic.scale.x.tickMin,pic.scale.y.tickMin) : axis.userMin;
    axis.position=0.5;
    axis.side=right;
    axis.align=S;
    axis.value2=pic.scale.y.automax ?
    (pic.scale.x.tickMax,pic.scale.y.tickMax) : axis.userMax;
    axis.extend=extend;
  };
}

axis Left(bool extend=false) {
  return new void(picture pic, axisT axis) {
    axis.value=pic.scale.x.automin ? 
    (pic.scale.x.tickMin,pic.scale.y.tickMin) : axis.userMin;
    axis.position=0.5;
    axis.side=left;
    axis.align=W;
    axis.value2=infinity;
    axis.extend=extend;
  };
}

axis Right(bool extend=false) {
  return new void(picture pic, axisT axis) {
    axis.value=pic.scale.x.automax ?
    (pic.scale.x.tickMax,pic.scale.y.tickMax) : axis.userMax;
    axis.position=0.5;
    axis.side=right;
    axis.align=E;
    axis.value2=infinity;
    axis.extend=extend;
  };
}

axis LeftRight(bool extend=false) {
  return new void(picture pic, axisT axis) {
    axis.value=pic.scale.x.automin ?
      (pic.scale.x.tickMin,pic.scale.y.tickMin) : axis.userMin;
    axis.position=0.5;
    axis.side=left;
    axis.align=W;
    axis.value2=pic.scale.x.automax ?
      (pic.scale.x.tickMax,pic.scale.y.tickMax) : axis.userMax;
    axis.extend=extend;
  };
}

axis XEquals(real x, bool extend=true)
{
  return new void(picture pic, axisT axis) {
    axis.value=x;
    axis.position=1;
    axis.side=left;
    axis.align=W;
    axis.value2=infinity;
    axis.extend=extend;
  };
}

axis YEquals(real y, bool extend=true)
{
    return new void(picture pic, axisT axis) {
    axis.value=I*y;
    axis.position=1;
    axis.side=right;
    axis.align=S;
    axis.value2=infinity;
    axis.extend=extend;
  };
}

axis XZero(bool extend=true)
{
  return XEquals(0,extend);
}

axis YZero(bool extend=true)
{
  return YEquals(0,extend);
}

public axis
  Bottom=Bottom(),
  Top=Top(),
  BottomTop=BottomTop(),
  Left=Left(),
  Right=Right(),
  LeftRight=LeftRight(),
  XZero=XZero(),
  YZero=YZero();

void crop(picture pic=currentpicture) 
{
  clip(pic,pic.userMin,pic.userMax);
}

void xlimits(picture pic=currentpicture, real Min=-infinity, real Max=infinity)
{
  bounds mx=autoscale(pic.userMin.x,pic.userMax.x,
		      logarithmic(pic.scale.x.scale));
  if(Min == -infinity) Min=mx.min;
  else pic.scale.x.automin=false;
  if(Max == infinity) Max=mx.max;
  else pic.scale.x.automax=false;
  pic.userMin=(Min,pic.userMin.y);
  pic.userMax=(Max,pic.userMax.y);
}

void ylimits(picture pic=currentpicture, real Min=-infinity, real Max=infinity)
{
  bounds my=autoscale(pic.userMin.y,pic.userMax.y,
		      logarithmic(pic.scale.y.scale));
  if(Min == -infinity) Min=my.min;
  else pic.scale.y.automin=false;
  if(Max == infinity) Max=my.max;
  else pic.scale.y.automax=false;
  pic.userMin=(pic.userMin.x,Min);
  pic.userMax=(pic.userMax.x,Max);
}

void limits(picture pic=currentpicture, pair min, pair max)
{
  xlimits(min.x,max.x);
  ylimits(min.y,max.y);
}
  

void autoscale(picture pic=currentpicture, axis axis)
{
  if(!pic.scale.set) {
    bounds mx,my;
    pic.scale.set=true;
    if(finite(pic.userMin.x) && finite(pic.userMax.x))
      mx=autoscale(pic.userMin.x,pic.userMax.x,logarithmic(pic.scale.x.scale));
    else {mx=new bounds; mx.min=mx.max=0; pic.scale.set=false;}
    if(finite(pic.userMin.y) && finite(pic.userMax.y))
      my=autoscale(pic.userMin.y,pic.userMax.y,logarithmic(pic.scale.y.scale));
    else {my=new bounds; my.min=my.max=0; pic.scale.set=false;}
    pic.scale.x.tickMin=mx.min;
    pic.scale.y.tickMin=my.min;
    pic.scale.x.tickMax=mx.max;
    pic.scale.y.tickMax=my.max;
    axis.xdivisor=mx.divisor;
    axis.ydivisor=my.divisor;
    axis.userMin=(pic.scale.x.automin ? mx.min : pic.userMin.x,
		  pic.scale.y.automin ? my.min : pic.userMin.y);
    axis.userMax=(pic.scale.x.automax ? mx.max : pic.userMax.x,
		  pic.scale.y.automax ? my.max : pic.userMax.y);
  }
}

void xaxis(picture pic=currentpicture, real xmin=-infinity, real xmax=infinity,
	   pen p=currentpen, string s="", real position=infinity, real angle=0,
	   pair align=0, pair shift=0, pair side=0, pen plabel=currentpen,
	   axis axis=YZero, ticks ticks=NoTicks)
{
  pic.scale.update();
  
  bool newticks=false;
  if(xmin != -infinity) {
    pic.userMin=(xmin,pic.userMin.y);
    newticks=true;
  }
  if(xmax != infinity) {
    pic.userMax=(xmax,pic.userMax.y);
    newticks=true;
  }
  
  if(pic.scale.set && newticks) {
    bounds mx=autoscale(xmin,xmax,logarithmic(pic.scale.x.scale));
    pic.scale.x.tickMin=mx.min;
    pic.scale.x.tickMax=mx.max;
    axis.xdivisor=mx.divisor;
  } else autoscale(pic,axis);
  
  axis(pic,axis);
  
  if(xmin == -infinity) {
    if(pic.scale.x.automin) {
      if(!axis.extend) xmin=pic.scale.x.tickMin;
    } else xmin=pic.userMin.x;
  }
  
  if(xmax == infinity) {
    if(pic.scale.x.automax) {
      if(!axis.extend) xmax=pic.scale.x.tickMax;
    } else xmax=pic.userMax.x;
  }
  
  if(position == infinity) position=axis.position;
  if(align == 0) align=axis.align;
  if(side == 0) side=axis.side;
  
  yequals(pic,axis.value.y,xmin,xmax,pic.scale.x.tickMin,pic.scale.x.tickMax,
	  p,s,position,angle,align,shift,side,plabel,ticks,axis.xdivisor);
  if(axis.value2 != infinity)
    yequals(pic,axis.value2.y,xmin,xmax,pic.scale.x.tickMin,
	    pic.scale.x.tickMax,p,s,
	    position,angle,align,shift,side,plabel,ticks,axis.xdivisor,true);
}

void yaxis(picture pic=currentpicture, real ymin=-infinity, real ymax=infinity,
	   pen p=currentpen, string s="", real position=infinity,
	   real angle=infinity, pair align=0, pair shift=0, pair side=0,
	   pen plabel=currentpen, axis axis=XZero, ticks ticks=NoTicks)
{
  pic.scale.update();
  
  bool newticks=false;
  if(ymin != -infinity) {
    pic.userMin=(pic.userMin.x,ymin);
    newticks=true;
  }
  if(ymax != infinity) {
    pic.userMax=(pic.userMax.x,ymax);
    newticks=true;
  }
  
  if(pic.scale.set && newticks) {
    bounds my=autoscale(ymin,ymax,logarithmic(pic.scale.y.scale));
    pic.scale.y.tickMin=my.min;
    pic.scale.y.tickMax=my.max;
    axis.ydivisor=my.divisor;
  } else autoscale(pic,axis);
  
  axis(pic,axis);
  
  if(ymin == -infinity) {
    if(pic.scale.y.automin) {
      if(!axis.extend) ymin=pic.scale.y.tickMin;
    } else ymin=pic.userMin.y;
  }
  
  if(ymax == infinity) {
    if(pic.scale.y.automax) {
      if(!axis.extend) ymax=pic.scale.y.tickMax;
    } else ymax=pic.userMax.y;
  }
  
  if(position == infinity) position=axis.position;
  if(align == 0) align=axis.align;
  if(side == 0) side=axis.side;
  
  if(angle == infinity) {
    frame f;
    label(f,s,0,(0,0),0,plabel);
    angle=length(max(f)-min(f)) > ylabelwidth*fontsize(plabel) ? 90 : 0;
  }
  
  xequals(pic,axis.value.x,ymin,ymax,pic.scale.y.tickMin,pic.scale.y.tickMax,
	  p,s,position,angle,align,shift,side,plabel,ticks,axis.ydivisor);
  if(axis.value2 != infinity)
    xequals(pic,axis.value2.x,ymin,ymax,pic.scale.y.tickMin,
	    pic.scale.y.tickMax,p,s,
	    position,angle,align,shift,side,plabel,ticks,axis.ydivisor,true);
}

void axes(picture pic=currentpicture, pen p=currentpen)
{
  xaxis(pic,p);
  yaxis(pic,p);
}

void tick(picture pic=currentpicture, pair z, pair align, real size=Ticksize,
	  pen p=currentpen)
{
  pic.add(new void (frame f, transform t) {
    pair tz=t*z;
    draw(f,tz--tz+align*size,p);
  });
  pic.addPoint(z,p);
  pic.addPoint(z,align*size,p);
}

void xtick(picture pic=currentpicture, real x, pair align=N,
	   real size=Ticksize, pen p=currentpen)
{
  tick(pic,(x,pic.userMin.y),align,Ticksize,p);
}

void labelx(picture pic=currentpicture, string s, pair z, pair align=S,
	    pair shift=infinity, pen p=currentpen)
{
  if(shift == infinity) shift=ticklabelshift(align,p);
  label(pic,baseline(s,align,"$10^4$"),z,align,shift,p);
}

void labelx(picture pic=currentpicture, real x, pair align=S,
	    pair shift=infinity, pen p=currentpen)
{
  labelx(pic,math(x),(x,0),align,shift,p);
}

void labelxtick(picture pic=currentpicture, real x, pair align=S,
		pair shift=infinity,
		real size=Ticksize, pen p=currentpen)
{
  labelx(pic,x,align,shift,p);
  xtick(pic,x,-align,Ticksize,p);
}

void ytick(picture pic=currentpicture, real y, pair align=E,
	   real size=Ticksize, pen p=currentpen)
{
  tick(pic,(0,y),align,Ticksize,p);
}

void labely(picture pic=currentpicture, string s, pair z, pair align=W,
	    pair shift=infinity, pen p=currentpen)
{
  if(shift == infinity) shift=ticklabelshift(align,p);
  label(pic,baseline(s,align,"$10^4$"),z,align,shift,p);
}

void labely(picture pic=currentpicture, string s, real y, pair align=W,
	    pair shift=infinity, pen p=currentpen)
{
  labely(pic,s,(0,y),align,shift,p);
}

void labely(picture pic=currentpicture, real y, pair align=W,
	    pair shift=infinity, pen p=currentpen)
{
  labely(pic,math(y),(0,y),align,shift,p);
}

void labelytick(picture pic=currentpicture, real y, pair align=W,
		pair shift=infinity, real size=Ticksize, pen p=currentpen)
{
  labely(pic,y,align,shift,p);
  ytick(pic,y,-align,Ticksize,p);
}

// Construct a secondary linear X axis
picture secondaryX(picture primary=currentpicture, void f(picture))
{
  picture pic=new picture;
  f(pic);
  bounds b=autoscale(pic.userMin.x,pic.userMax.x);
  real denom=b.max-b.min;
  if(denom != 0.0) {
    real m=(primary.userMax.x-primary.userMin.x)/denom;
    pic.erase();
    scale(pic,Linear(m,b.min),primary.scale.y.scale);
    pic.userMin=primary.userMin;
    pic.userMax=primary.userMax;
    f(pic);
  }
  return pic;
}

// Construct a secondary linear Y axis
picture secondaryY(picture primary=currentpicture, void f(picture))
{
  picture pic=new picture;
  f(pic);
  bounds b=autoscale(pic.userMin.y,pic.userMax.y);
  real denom=b.max-b.min;
  if(denom != 0.0) {
    real m=(primary.userMax.y-primary.userMin.y)/denom;
    pic.erase();
    scale(pic,primary.scale.x.scale,Linear(m,b.min));
    pic.userMin=primary.userMin;
    pic.userMax=primary.userMax;
    f(pic);
  }
  return pic;
}

private struct interpolateT {};
public interpolateT interpolate=null;
typedef guide interpolate(pair F(real), guide, real, real, int, interpolateT);
public interpolate
  LinearInterp=new guide(pair F(real), guide g, real a, real b, int n,
			 interpolateT) {
			   real width=(b-a)/n;
			   for(int i=0; i <= n; ++i) {
			     real x=a+width*i;
			     g=g--F(x);	
			   }
			   return g;
			 },
  Spline=new guide(pair F(real), guide g, real a, real b, int n,
		   interpolateT) {
		     real width=(b-a)/n;
		     for(int i=0; i <= n; ++i) {
		       real x=a+width*i;
		       g=g..F(x);
		     }
		     return g;
		   };

guide graph(picture pic=currentpicture, guide g=nullpath,
	    real f(real), real a, real b, int n=ngraph,
	    interpolate interpolatetype=LinearInterp)
{
  return interpolatetype(new pair (real x) {
    return (x,pic.scale.y.scale.T(f(pic.scale.x.scale.Tinv(x))));
  },g,pic.scale.x.scale.T(a),pic.scale.x.scale.T(b),n,interpolate);
}

guide graph(picture pic=currentpicture, guide g=nullpath,
	    real x(real), real y(real), real a, real b,
	    int n=ngraph, interpolate interpolatetype=LinearInterp)
{
  return interpolatetype(new pair (real t) {
    return (pic.scale.x.scale.T(x(t)),pic.scale.y.scale.T(y(t)));
  },g,a,b,n,interpolate);
}

guide graph(picture pic=currentpicture, guide g=nullpath,
	    pair z(real), real a, real b,
	    int n=ngraph, interpolate interpolatetype=LinearInterp)
{
  return interpolatetype(new pair (real t) {
    pair z=z(t);
    return (pic.scale.x.scale.T(z.x),pic.scale.y.scale.T(z.y));
  },g,a,b,n,interpolate);
}

private int next(int i, bool[] cond)
{
  ++i;
  if(cond.length > 0) while(!cond[i]) ++i;
  return i;
}

guide graph(picture pic=currentpicture, guide g=nullpath,
	    pair z[], bool cond[]={}, interpolate interpolatetype=LinearInterp)
{
  int n;
  if(cond.length > 0) {
    if(cond.length != z.length)
      abort("condition array has different length than data array");
    n=sum(cond)-1;
  } else n=z.length-1;
  
  int i=-1;
  return interpolatetype(new pair (real) {
    i=next(i,cond);
    return (pic.scale.x.scale.T(z[i].x),pic.scale.y.scale.T(z[i].y));
  },g,0,0,n,interpolate);
}

guide graph(picture pic=currentpicture, guide g=nullpath,
	    real x[], real y[], bool cond[]={},
	    interpolate interpolatetype=LinearInterp)
{
  if(x.length != y.length)
    abort("attempt to graph arrays of different lengths");
  
  int n;
  if(cond.length > 0) {
    if(cond.length != x.length)
      abort("condition array has different length than data arrays");
    n=sum(cond)-1;
  } else n=x.length-1;
  
  int i=-1;
  return interpolatetype(new pair (real) {
    i=next(i,cond);
    return (pic.scale.x.scale.T(x[i]),pic.scale.y.scale.T(y[i]));
  },g,0,0,n,interpolate);
}

guide graph(guide g=nullpath, real f(real), real a, real b, int n=ngraph,
	    real T(real), interpolate interpolatetype=LinearInterp)
{
  return interpolatetype(new pair (real x) {return (T(x),f(T(x)));},
			 g,a,b,n,interpolate);
}

pair polar(real r, real theta)
{
  return r*expi(theta);
}

guide polargraph(guide g=nullpath, real f(real), real a, real b, int n=ngraph,
		 interpolate interpolatetype=LinearInterp)
{
  return interpolatetype(new pair (real theta) {return f(theta)*expi(theta);},
			 g,a,b,n,interpolate);
}

// True arc
guide Arc(pair c, real r, real angle1, real angle2)
{
  return shift(c)*polargraph(new real (real t){return r;},angle1,angle2,
  Spline);
}

// True circle
guide Circle(pair c, real r)
{
  return Arc(c,r,0,2pi)--cycle;
}
