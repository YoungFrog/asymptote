// Default file prefix used for inline LaTeX mode
string defaultfilename;

string outprefix(string prefix=defaultfilename) {
  return stripdirectory(stripextension(prefix == "" ? settings.outname :
				       prefix));
}

bool shipped; // Was a picture or frame already shipped out?

restricted bool Wait=true;                         
restricted bool NoWait=false;

frame currentpatterns;

frame Portrait(frame f) {return f;};
frame Landscape(frame f) {return rotate(90)*f;};
frame UpsideDown(frame f) {return rotate(180)*f;};
frame Seascape(frame f) {return rotate(-90)*f;};
typedef frame orientation(frame);
orientation orientation=Portrait;

include plain_xasy;

object embed3(string, frame, projection);
object embed3(string, picture, projection);

bool prc()
{
  return settings.prc && settings.outformat == "pdf";
}

frame enclose(string prefix=defaultfilename, object F)
{
  if(prc()) {
    frame f;
    label(f,F.L);
    return f;
  } return F.f;
}

void shipout(string prefix=defaultfilename, frame f,
             string format="", bool wait=NoWait, bool view=true,
	     projection P=currentprojection)
{
  if(is3D(f))
    f=enclose(prefix,embed3(prefix,f,P));

  if(settings.psimage && prc()) {
    string name=outprefix(prefix)+".ps";
    delete(name);
    string javascript="
console.println('Rasterizing to "+name+"');
var pp = this.getPrintParams();
pp.interactive = pp.constants.interactionLevel.silent;
pp.fileName = '"+name+"';
fv = pp.constants.flagValues;
pp.flags |= fv.suppressRotate;
pp.pageHandling = pp.constants.handling.none;
pp.printerName = 'FILE';
try{silentPrint(pp);} catch(e){this.print(pp);}";
    if(!view ||
       !(interactive() ? settings.interactiveView : settings.batchView))
      javascript += "this.closeDoc();";
    string s;
    if(pdf())
      s="\pdfannot width 1pt height 1pt { /AA << /PO << /S /JavaScript /JS ("+javascript+") >> >> }";
    else
      s="\special{ps: mark {Catalog} << /OpenAction << /S /JavaScript /JS ("+
	javascript+") >> >> /PUT pdfmark }";
    frame g;
    tex(g,s);
    prepend(f,g);
  }

  if(inXasyMode) {
    erase();
    add(f,group=false);
    return;
  }
  
  // Applications like LaTeX cannot handle large PostScript coordinates.
  pair m=min(f);
  int limit=2000;
  if(abs(m.x) > limit || abs(m.y) > limit) f=shift(-m)*f;

  shipout(prefix,f,currentpatterns,format,wait,view,xformStack.pop0);
  shipped=true;
}

void shipout(string prefix=defaultfilename, picture pic,
	     orientation orientation=orientation,
	     string format="", bool wait=NoWait, bool view=true,
	     projection P=currentprojection)
{
  shipout(prefix,orientation(pic.nodes3.length > 0 ?
			     enclose(embed3(prefix,pic,P)) : pic.fit()),
	  format,wait,view);
}

void shipout(string prefix=defaultfilename,
             orientation orientation=orientation,
             string format="", bool wait=NoWait, bool view=true)
{
  shipout(prefix,currentpicture,orientation,format,wait,view);
}

void newpage(frame f)
{
  tex(f,"\newpage");
  layer(f);
}

void newpage(picture pic=currentpicture) 
{
  tex(pic,"\newpage");
  layer(pic);
}
