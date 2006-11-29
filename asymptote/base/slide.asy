import fontsize;
usepackage("rotating");
usepackage("color");
usepackage("asycolors");

bool reverse=false; // Set to true to enable reverse video
bool stepping=false; // Set to true to enable stepping
bool itemstep=true;  // Set to false to disable stepping on each item

bool allowstepping=false; // Allow stepping for current slide.

real pagemargin=0.5cm;
real pagewidth=-2pagemargin;
real pageheight=-2pagemargin;

if(orientation == Portrait || orientation == UpsideDown) {
  pagewidth += settings.paperwidth;
  pageheight += settings.paperheight;
} else {
  if(settings.outformat == "pdf") settings.tex="pdflatex";
  if(pdf()) {
    orientation=Portrait;
    real temp=settings.paperwidth;
    settings.paperwidth=settings.paperheight;
    settings.paperheight=temp;
    pagewidth += settings.paperwidth;
    pageheight += settings.paperheight;
  } else {
    pagewidth += settings.paperheight;
    pageheight += settings.paperwidth;
  }
}

size(pagewidth,pageheight,IgnoreAspect);

real minipagemargin=1inch;
real minipagewidth=pagewidth-2minipagemargin;

transform tinv=inverse(fixedscaling((-1,-1),(1,1),currentpen));
  
pen itempen=fontsize(24pt);
real itemskip=0.5;

pen titlepagepen=fontsize(36pt)+red;
pen authorpen=fontsize(24pt)+blue;
pen institutionpen=authorpen;
pen urlpen=fontsize(20pt);
pair urlskip=(0,0.2);
pen datepen=urlpen;
pair dateskip=(0,0.1);

pair titlealign=2S;
pen titlepen=fontsize(32pt);
real titleskip=0.5;

string oldbulletcolor;
string newbulletcolor="red";
string bullet="{\bulletcolor{$\bullet$}}";
                                              
pair pagenumberposition=S+E;
pair pagenumberalign=4NW;
pen pagenumberpen=fontsize(12);
pen steppagenumberpen=colorless(pagenumberpen)+red;

real figureborder=0.25cm;
pen figuremattpen;

pair titleposition=(-0.8,0.4);
pair startposition=(-0.8,0.9);
pair currentposition=startposition;

string bulletcolor(string color) {
  return "\def\bulletcolor{"+'\\'+"color{"+color+"}}";
}

picture background;
size(background,pagewidth,pageheight,IgnoreAspect);

defaultpen(itempen);

int[] firstnode=new int[] {currentpicture.nodes.length};
int[] lastnode=new int[];
bool firststep=true;

int page=1;
bool havepagenumber=false;

int preamblenodes=2;

bool empty()
{
  return currentpicture.nodes.length <= preamblenodes;
}

void background() 
{
  if(!background.empty()) {
    add(background);
    layer();
    preamblenodes += 2;
  }
}

void color(string name, string color) {
  texpreamble("\def"+'\\'+name+"#1{{\color{"+color+"}#1}}");
}

void normalvideo() {
    figuremattpen=invisible;
    color("Red","red");
    color("Green","heavygreen");
    color("Blue","blue");
    color("Foreground","black");
    color("Background","white");
    oldbulletcolor="black";
}

normalvideo();
texpreamble(bulletcolor(newbulletcolor));
texpreamble("\hyphenpenalty=10000\tolerance=1000");

// Evaluate user command line option.
void usersetting()
{
  plain.usersetting();
  if(reverse) { // Black background
    fill(background,box((-1,-1),(1,1)),black);
    itempen=white;
    defaultpen(itempen);
    pagenumberpen=colorless(pagenumberpen)+white;
    steppagenumberpen=colorless(steppagenumberpen)+mediumblue;
    titlepagepen=colorless(titlepagepen)+mediumred;
    authorpen=colorless(authorpen)+paleblue;
    institutionpen=colorless(institutionpen)+paleblue;
    // Work around pdflatex bug, in which white is mapped to black!
    figuremattpen=pdf() ? cmyk(0,0,0,1/255) : white;
    color("Red","mediumred");
    color("Green","green");
    color("Blue","paleblue");
    color("Foreground","white");
    color("Background","black");
    oldbulletcolor="white";
  } else { // White background
    normalvideo();
  }
}

void numberpage(pen p=pagenumberpen)
{
  label((string) page,pagenumberposition,pagenumberalign,p);
  havepagenumber=true;
}

void nextpage(pen p=pagenumberpen)
{
  numberpage(p);
  newpage();
  background();
  firststep=true;
}

void newslide(bool stepping=true) 
{
  allowstepping=stepping;
  nextpage();
  ++page;
  currentposition=startposition;
  firstnode=new int[] {currentpicture.nodes.length};
  lastnode=new int[];
}

bool checkposition()
{
  if(abs(currentposition.x) > 1 || abs(currentposition.y) > 1) {
    newslide();
    return false;
  }
  return true;
}

void step()
{
  if(!stepping || !allowstepping) return;
  if(!checkposition()) return;
  lastnode.push(currentpicture.nodes.length-1);
  nextpage(steppagenumberpen);
  for(int i=0; i < firstnode.length; ++i) {
    for(int j=firstnode[i]; j <= lastnode[i]; ++j) {
      tex(bulletcolor(oldbulletcolor));
      currentpicture.add(currentpicture.nodes[j]);
    }
  }
  firstnode.push(currentpicture.nodes.length-1);
  tex(bulletcolor(newbulletcolor));
}

void incrementposition(pair z)
{
  currentposition += z;
}

void title(string s, pair position=N, pair align=titlealign,
           pen p=titlepen, bool newslide=true)
{
  if(newslide && !empty()) newslide();
  checkposition();
  frame f;
  label(f,minipage("\center "+s,minipagewidth),(0,0),align,p);
  add(f,position,labelmargin(p)*align);
  currentposition=(currentposition.x,position.y+
                   (tinv*(min(f)-titleskip*I*lineskip(p)*pt)).y);
}

void outline(string s="Outline", pair position=N, pair align=titlealign,
             pen p=titlepen)
{
  newslide(stepping=false);
  title(s,position,align,p,newslide=false);
}

void remark(bool center=false, string s, pair align=0, pen p=itempen,
            real indent=0, bool minipage=true, real itemskip=itemskip,
            filltype filltype=NoFill, bool step=false) 
{
  checkposition();
  if(minipage) s=minipage(s,minipagewidth);
  
  pair offset;
  if(center) {
    if(align == 0) align=S;
    offset=(0,currentposition.y);
  } else {
    if(align == 0) align=SE;
    offset=currentposition;
  }
  
  frame f;
  label(f,s,(indent,0),align,p,filltype);
  pair m=tinv*min(f);
  pair M=tinv*min(f);
  
  if(abs(offset.x+M.x) > 1)
    write("warning: slide too wide on page "+(string) page+':\n'+(string) s);

  if(abs(offset.y+M.y) > 1) {
    void toohigh() {
      write("warning: slide too high on page "+(string) page+':\n'+(string) s);
    }
    if(M.y-m.y < 2) {
      newslide(); offset=(offset.x,currentposition.y);
      if(offset.y+M.y > 1 || offset.y+m.y < -1) toohigh();
    } else toohigh();
  }

  if(step) {
    if(!firststep) step();
    firststep=false;
  }

  add(f,offset);
  incrementposition((0,(tinv*(min(f)-itemskip*I*lineskip(p)*pt)).y));
}

void center(string s, pen p=itempen)
{
  remark("\center "+s,p);
}

void equation(string s, pen p=itempen)
{
  remark(center=true,"\vbox{$$"+s+"$$}",p,minipage=false,itemskip=0);
}

void vbox(string s, pen p=itempen)
{
  remark(center=true,"\vbox{"+s+"}",p,minipage=false,itemskip=0);
}

void equations(string s, pen p=itempen)
{
  vbox("\begin{eqnarray}"+s+"\end{eqnarray}",p);
}

void display(string[] s, real margin=0, pen figuremattpen=figuremattpen,
	     string[] captions=new string[], string caption="", pair align=S,
	     pen p=itempen)
{
  if(s.length == 0) return;
  real[] width=new real[s.length];
  real sum;
  for(int i=0; i < s.length; ++i) {
    frame f;
    label(f,s[i]);
    width[i]=max(f).x-min(f).x;
    sum += width[i];
  }
  if(sum > pagewidth)
    write("warning: slide too wide on page "+(string) page+':\n'+s[0]);
  else margin=(pagewidth-sum)/(s.length+1);
  real[] center;
  real pos;
  frame f;
  for(int i=0; i < s.length; ++i) {
    real w=margin+width[i];
    pos += 0.5*w;
    center[i]=pos;
    label(f,s[i],(center[i],0));
    pos += 0.5*w;
  }
  int stop=min(s.length,captions.length);
  real y=min(f).y;
  for(int i=0; i < stop; ++i)
    label(f,captions[i],(center[i],y),align);
  add(f,(0,currentposition.y),align);
  incrementposition((0,(tinv*(-(max(f)-min(f))-itemskip*I*lineskip(p)*pt)).y));
  if(caption != "") center(caption,p);
}

void display(string s, pen figuremattpen=figuremattpen,
	     string caption="", pair align=S, pen p=itempen)
{
  display(new string[] {s},figuremattpen,caption,align,p);
}

void figure(string[] s, string options="", real margin=0, 
            pen figuremattpen=figuremattpen,
            string[] captions=new string[], string caption="",
	    pair align=S, pen p=itempen)
{
  string[] S;
  for(int i=0; i < s.length; ++i) S[i]=graphic(s[i],options);
  display(S,margin,figuremattpen,captions,caption,align,p);
}

void figure(string s, string options="", pen figuremattpen=figuremattpen,
            string caption="", pair align=S, pen p=itempen)
{
  figure(new string[] {s},options,figuremattpen,caption,align,p);
}

void item(string s, pen p=itempen, bool step=itemstep)
{
  frame b;
  label(b,bullet,(0,0),p);
  real bulletwidth=max(b).x-min(b).x;
  remark(bullet+"\hangindent"+(string) bulletwidth+"pt$\,$"+s,p,
         -bulletwidth*pt,step=step);
}

void subitem(string s, pen p=itempen)
{
  remark("\quad -- "+s,p);
}

void skip(real n=1)
{
  incrementposition((0,(tinv*(-n*itemskip*I*lineskip(itempen)*pt)).y));
}

void titlepage(string title, string author, string institution="",
               string date="", string url="", bool newslide=false)
{
  if(newslide && !empty()) newslide();
  background();
  currentposition=titleposition;
  center(title,titlepagepen);
  center(author,authorpen);
  if(institution != "") center(institution,institutionpen);
  currentposition -= dateskip;
  if(date != "") center(date,datepen);
  currentposition -= urlskip;
  if(url != "") center("{\tt "+url+"}",urlpen);
}

void exitfunction()
{
  if(havepagenumber) numberpage();
  plain.exitfunction();
}

atexit(exitfunction);
