/*****************************************************************************
 * feynman.asy -- An asymptote library for drawing Feynman diagrams.         *
 *                                                                           *
 * by:  Martin Wiebusch                                                      *
 *****************************************************************************/


// labels on paths are positioned with a certain offset to the path. The
// direction of the offset can be specified as absolute direction or as
// direction relative to the direction of the path. The functions
// midLabelPoint, endLabelPoint and startLabelPoint use a positiontype
// parameter to select one of the two methods.
bool Absolute = false, Relative = true;

/* default parameters ********************************************************/

// default ratio of width (distance between two loops) to amplitude for a gluon
// line. The gluon function uses this ratio, if the width parameter is
// negative. 
public real gluonratio;

// default ratio of width (distance between two crests) to amplitude for a
// photon  line. The photon function uses this ratio, if the width parameter is
// negative. 
public real photonratio;

// default gluon amplitude
public real gluonamplitude;

// default photon amplitude
public real photonamplitude;

// default pen for drawing the background. Usually white.
public pen backgroundpen;

// default pen for drawing gluon lines
public pen gluonpen;

// default pen for drawing photon lines
public pen photonpen;

// default pen for drawing fermion lines
public pen fermionpen;

// default pen for drawing scalar lines
public pen scalarpen;

// default pen for drawing ghost lines
public pen ghostpen;

// default pen for drawing double lines
public pen doublelinepen;

// default pen for drawing vertices
public pen vertexpen;

// default pen for drawing big vertices (drawVertexOX and drawVertexBoxX)
public pen bigvertexpen;

// inner spacing of a double line
public real doublelinespacing;

// default arrow for propagators
public arrowbar currentarrow;

// if true, each of the drawSomething commands blots out the background
// (with pen backgroundpen) before drawing.
public bool overpaint;

// margin around lines. If one line is drawn over anoter, a white margin
// of size linemargin is kept around the top one.
public real linemargin;

// at vertices, where many lines join, the last line drawn should not blot
// out the others. By not erasing the background near the ends of lines,
// this is prevented for lines with an angle greater than minvertexangle to
// each other. Note, that small values for minvertexangle mean that the
// background is only erased behind a small segment of every line. Setting
// minvertexangle = 0 effectively disables background erasing for lines.
public real minvertexangle;

// size (radius) of vertices
public real vertexsize;

// size (radius) of big vertices (drawVertexOX and drawVertexBoxX)
public real bigvertexsize;

// offset of labels from paths. Used by the function labelPoint.
public real labeloffset;

// default method for positioning labels on paths.
public bool labelpostype;


/* defaults for momentum arrows **********************************************/

// (momentum arrows are small arrows parallel to particle lines indicating the
// direction of momentum)

// default size of the arrowhead of momentum arrows
public arrowbar currentmomarrow;

// default length of momentum arrows
public real momarrowlength;

// default pen for momentum arrows
public pen momarrowpen;

// default offset between momentum arrow and related particle line
public real momarrowoffset;

// default margin for momentum arrows
public real momarrowmargin;


/* helper functions **********************************************************/

// internal function for overpainting
private void do_overpaint(picture pic, path p, pen bgpen,
                          real halfwidth, real vertexangle)
{
    real tanvertexangle = tan(vertexangle*pi/180);
    if(tanvertexangle != 0) {
        real t1 = arctime(p, halfwidth/tanvertexangle+halfwidth);
        real t2 = arctime(p, arclength(p)-halfwidth/tanvertexangle-halfwidth);
        draw(pic, subpath(p, t1, t2),
             bgpen+linewidth(2*halfwidth));
    }
}

// returns the path of a gluon line along path p, with amplitude amp and width
// width (distance between two loops). If width is negative, the width is
// set to amp*gluonratio
path gluon(path p, real amp = gluonamplitude, real width=-1)
{
    if(width < 0) width = abs(gluonratio*amp);

    real pathlen = arclength(p);
    int ncurls = floor(pathlen/width);
    real firstlen = (pathlen - width*(ncurls-1))/2;
    real firstt = arctime(p, firstlen);
    pair firstv = dir(p, firstt);
    guide g = point(p, 0)..{firstv}( point(p, firstt)
                                    +amp*unit(rotate(90)*firstv));

    real t1;
    pair v1;
    real t2;
    pair v2;
    pathlen -= firstlen;
    for(real len = firstlen+width/2; len < pathlen; len += width) {
        t1 = arctime(p, len);
        v1 = dir(p, t1);
        t2 = arctime(p, len + width/2);
        v2 = dir(p, t2);

        g=g..{-v1}(point(p, t1)+amp*unit(rotate(-90)*v1))
           ..{+v2}(point(p, t2)+amp*unit(rotate(+90)*v2));
    }
    g = g..point(p, size(p));
    return g;
}

// returns the path of a photon line along path p, with amplitude amp and width
// width (distance between two crests). If width is negative, the width is
// set to amp*photonratio
path photon(path p, real amp = photonamplitude, real width=-1)
{
    if(width < 0) width = abs(photonratio*amp);

    real pathlen = arclength(p);
    int ncurls = floor(pathlen/width);
    real firstlen = (pathlen - width*(ncurls-1))/2;
    real firstt = arctime(p, firstlen);
    pair firstv = dir(p, firstt);
    guide g =   point(p, 0){dir(p, 0)}
              ..{firstv}( point(p, firstt)+amp*unit(rotate(90)*firstv));

    real t1;
    pair v1;
    real t2;
    pair v2;
    pathlen -= firstlen;
    for(real len = firstlen+width/2; len < pathlen; len += width) {
        t1 = arctime(p, len);
        v1 = dir(p, t1);
        t2 = arctime(p, len + width/2);
        v2 = dir(p, t2);

        g=g..{+v1}(point(p, t1)+amp*unit(rotate(-90)*v1))
           ..{+v2}(point(p, t2)+amp*unit(rotate(+90)*v2));
    }
    g = g..{dir(p, size(p))}point(p, size(p));
    return g;
}

// generate arrows in the middle of paths. MidArrow() can be used as argument
// to draw commands, in place of EndArrow etc.
arrowbar MidArrow(real size=arrowsize, real angle=arrowangle,
                  filltype filltype=Fill)
{
  return new void(picture pic, path g, pen p, margin margin,
		  arrowbarT arrowbar) {
    arrowbar.drawpath=false;
    add(pic,arrow(g,p,size,angle,filltype,
                  arctime(g, (arclength(g)+size)/2),margin));
  };
}

// provide a middle arrow with default parameters
public arrowbar MidArrow = MidArrow();

// returns the path of a momentum arrow along path p, with length length,
// an offset offset from the path p and at position position. position will
// usually be one of the predefined pairs left or right. Making adjust
// nonzero shifts the momentum arrow along the path.
path momArrowPath(path p,
                  pair position,
                  real adjust = 0,
                  real offset = momarrowoffset,
                  real length = momarrowlength)
{
    real pathlen = arclength(p);
    real t1 = arctime(p, (pathlen-length)/2 + adjust);
    pair v1 = dir(p, t1);
    real t2 = arctime(p, (pathlen+length)/2+ adjust);
    pair v2 = dir(p, t2);

    pair p1 = point(p, t1) + offset*unit(scale(position)*rotate(-90)*v1);
    pair p2 = point(p, t2) + offset*unit(scale(position)*rotate(-90)*v2);

    return p1{v1}..{v2}p2;
}

// returns a label position near the middle of path p, with an offset offset
// from the path, shifted in direction of pos. Making adjust nonzero shifts
// the label point along the path. postype determines, whether the direction
// of pos describes an absolute direction or a direction relative to the path
// direction. The constants Relative and Absolute may be used here.
pair midLabelPoint(path p,
                   pair pos,
                   real adjust = 0,
                   real offset = labeloffset,
                   bool postype = labelpostype)
{
    real pathlen = arclength(p);
    real t = arctime(p, pathlen/2 + adjust);

    if(postype == Relative) {
        pair v = dir(p, t);
        return point(p, t) + offset*unit(scale(pos)*rotate(-90)*v);
    }

    return point(p, t) + offset*unit(pos);
}

// returns a label position near the end of path p, with an offset offset
// from the path, shifted in direction of pos. postype determines, whether the
// direction of pos describes an absolute direction or a direction relative to
// the path direction. The constants Relative and Absolute may be used here.
pair endLabelPoint(path p,
                   pair pos,
                   real offset = labeloffset,
                   bool postype = labelpostype)
{
    if(postype == Relative) {
        pair v = dir(p, size(p));
        return point(p, size(p)) + offset*unit(scale(pos)*rotate(-90)*v);
    }

    return point(p, size(p)) + offset*unit(pos);
}

// returns a label position near the begin of path p, with an offset offset
// from the path, shifted in direction of pos. postype determines, whether the
// direction of pos describes an absolute direction or a direction relative to
// the path direction. The constants Relative and Absolute may be used here.
pair initialLabelPoint(path p,
                       pair pos,
                       real offset = labeloffset,
                       bool postype = labelpostype)
{
    if(postype == Relative) {
        pair v = dir(p, 0);
        return point(p, 0) + offset*unit(scale(pos)*rotate(-90)*v);
    }

    return point(p, 0) + offset*unit(pos);
}



/* drawing functions *********************************************************/

// draw a gluon line on picture pic, along path p, with amplitude amp, width
// width (distance between loops) and with pen fgpen. If erasebg is true,
// bgpen is used to erase the background behind the line and at a margin
// margin around it. The background is not erased at a certain distance to
// the endpoints, which is determined by vertexangle (see comments to the
// default parameter minvertexangle). For negative values of width, the width
// is set to gluonratio*amp.
void drawGluon(picture pic = currentpicture,
               path p,
               real amp = gluonamplitude,
               real width = -1,
               pen fgpen = gluonpen,
               bool erasebg = overpaint,
               pen bgpen = backgroundpen,
               real vertexangle = minvertexangle,
               real margin = linemargin)
{
    if(width < 0) width = abs(2*amp);

    if(erasebg) do_overpaint(pic, p, bgpen, amp+margin, vertexangle);
    draw(pic, gluon(p, amp, width), fgpen);
}

// draw a photon line on picture pic, along path p, with amplitude amp, width
// width (distance between loops) and with pen fgpen. If erasebg is true,
// bgpen is used to erase the background behind the line and at a margin
// margin around it. The background is not erased at a certain distance to
// the endpoints, which is determined by vertexangle (see comments to the
// default parameter minvertexangle). For negative values of width, the width
// is set to photonratio*amp.
void drawPhoton(picture pic = currentpicture,
                path p,
                real amp = photonamplitude,
                real width = -1,
                pen fgpen = currentpen,
                bool erasebg = overpaint,
                pen bgpen = backgroundpen,
                real vertexangle = minvertexangle,
                real margin = linemargin)
{
    if(width < 0) width = abs(4*amp);

    if(erasebg) do_overpaint(pic, p, bgpen, amp+margin, vertexangle);
    draw(pic, photon(p, amp, width), fgpen);
}

// draw a fermion line on picture pic, along path p with pen fgpen and an
// arrowhead arrow. If erasebg is true, bgpen is used to erase the background
// at a margin margin around the line. The background is not erased at a
// certain distance to the endpoints, which is determined by vertexangle
// (see comments to the default parameter minvertexangle).
void drawFermion(picture pic = currentpicture,
                 path p,
                 pen fgpen = currentpen,
                 arrowbar arrow = currentarrow,
                 bool erasebg = overpaint,
                 pen bgpen = backgroundpen,
                 real vertexangle = minvertexangle,
                 real margin = linemargin)
{
    if(erasebg) do_overpaint(pic, p, bgpen,
                             linewidth(fgpen)+margin, vertexangle);
    draw(pic, p, fgpen, arrow);
}

// draw a scalar line on picture pic, along path p with pen fgpen and an
// arrowhead arrow. If erasebg is true, bgpen is used to erase the background
// at a margin margin around the line. The background is not erased at a
// certain distance to the endpoints, which is determined by vertexangle
// (see comments to the default parameter minvertexangle).
void drawScalar(picture pic = currentpicture,
                path p,
                pen fgpen = scalarpen,
                arrowbar arrow = currentarrow,
                bool erasebg = overpaint,
                pen bgpen = backgroundpen,
                real vertexangle = minvertexangle,
                real margin = linemargin)
{
    if(erasebg) do_overpaint(pic, p, bgpen,
                             linewidth(fgpen)+margin, vertexangle);
    draw(pic, p, fgpen, arrow);
}

// draw a ghost line on picture pic, along path p with pen fgpen and an
// arrowhead arrow. If erasebg is true, bgpen is used to erase the background
// at a margin margin around the line. The background is not erased at a
// certain distance to the endpoints, which is determined by vertexangle
// (see comments to the default parameter minvertexangle).
void drawGhost(picture pic = currentpicture,
               path p,
               pen fgpen = ghostpen,
               arrowbar arrow = currentarrow,
               bool erasebg = overpaint,
               pen bgpen = backgroundpen,
               real vertexangle = minvertexangle,
               real margin = linemargin)
{
    if(erasebg) do_overpaint(pic, p, bgpen, 
                             linewidth(fgpen)+margin, vertexangle);
    draw(pic, p, fgpen, arrow);
}

// draw a double line on picture pic, along path p with pen fgpen, an inner
// spacing of dlspacint and an arrowhead arrow. If erasebg is true, bgpen is
// used to erase the background at a margin margin around the line. The
// background is not erased at a certain distance to the endpoints, which is
// determined by vertexangle (see comments to the default parameter
// minvertexangle).
void drawDoubleLine(picture pic = currentpicture,
                    path p,
                    pen fgpen = doublelinepen,
                    real dlspacing = doublelinespacing,
                    arrowbar arrow = currentarrow,
                    bool erasebg = overpaint,
                    pen bgpen = backgroundpen,
                    real vertexangle = minvertexangle,
                    real margin = linemargin)
{
    if(erasebg) do_overpaint(pic, p, bgpen, 
                             linewidth(fgpen)+margin, vertexangle);

    real htw = linewidth(fgpen)+dlspacing/2;
    draw(pic, p, fgpen+2*htw);
    draw(pic, p, bgpen+(linewidth(dlspacing)));
    path rect = (-htw,-htw)--(-htw,htw)--(0,htw)--(0,-htw)--cycle;
    fill(shift(point(p,0))*scale(unit(dir(p,0)))*rect, bgpen);
    fill(shift(point(p,size(p)))*scale(-unit(dir(p,size(p))))*rect,
         bgpen);
    draw(pic, p, invisible, arrow);
}

// draw a vertex dot on picture pic, at position xy with radius r and pen
// fgpen
void drawVertex(picture pic = currentpicture,
                pair xy,
                real r = vertexsize,
                pen fgpen = vertexpen)
{
    fill(pic, circle(xy, r), fgpen);
}

// draw an empty vertex dot on picture pic, at position xy with radius r
// and pen fgpen. If erasebg is true, the background is erased in the inside
// of the circle.
void drawVertexO(picture pic = currentpicture,
                 pair xy,
                 real r = vertexsize,
                 pen fgpen = vertexpen,
                 bool erasebg = overpaint,
                 pen bgpen = backgroundpen)
{
    if(erasebg)
        filldraw(pic, circle(xy, r), bgpen, fgpen);
    else
        draw(pic, circle(xy, r), fgpen);
}

// draw a vertex triangle on picture pic, at position xy with radius r and pen
// fgpen
void drawVertexTriangle(picture pic = currentpicture,
                        pair xy,
                        real r = vertexsize,
                        pen fgpen = vertexpen)
{
    real cospi6 = cos(pi/6);
    real sinpi6 = sin(pi/6);
    path triangle = (cospi6,-sinpi6)--(0,1)--(-cospi6,-sinpi6)--cycle;
    fill(pic, shift(xy)*scale(r)*triangle, fgpen);
}

// draw an empty vertex triangle on picture pic, at position xy with size r
// and pen fgpen. If erasebg is true, the background is erased in the inside
// of the triangle.
void drawVertexTriangleO(picture pic = currentpicture,
                         pair xy,
                         real r = vertexsize,
                         pen fgpen = vertexpen,
                         bool erasebg = overpaint,
                         pen bgpen = backgroundpen)
{
    real cospi6 = cos(pi/6);
    real sinpi6 = sin(pi/6);
    path triangle = (cospi6,-sinpi6)--(0,1)--(-cospi6,-sinpi6)--cycle;

    if(erasebg)
        filldraw(pic, shift(xy)*scale(r)*triangle, bgpen, fgpen);
    else
        draw(pic, shift(xy)*scale(r)*triangle, fgpen);
}

// draw a vertex box on picture pic, at position xy with radius r and pen
// fgpen
void drawVertexBox(picture pic = currentpicture,
                   pair xy,
                   real r = vertexsize,
                   pen fgpen = vertexpen)
{
    path box = (1,1)--(-1,1)--(-1,-1)--(1,-1)--cycle;
    fill(pic, shift(xy)*scale(r)*box, fgpen);
}

// draw an empty vertex box on picture pic, at position xy with size r
// and pen fgpen. If erasebg is true, the background is erased in the inside
// of the box.
void drawVertexBoxO(picture pic = currentpicture,
                    pair xy,
                    real r = vertexsize,
                    pen fgpen = vertexpen,
                    bool erasebg = overpaint,
                    pen bgpen = backgroundpen)
{
    path box = (1,1)--(-1,1)--(-1,-1)--(1,-1)--cycle;
    if(erasebg)
        filldraw(pic, shift(xy)*scale(r)*box, bgpen, fgpen);
    else
        draw(pic, shift(xy)*scale(r)*box, fgpen);
}

// draw an X on picture pic, at position xy with size r and pen
// fgpen
void drawVertexX(picture pic = currentpicture,
                 pair xy,
                 real r = vertexsize,
                 pen fgpen = vertexpen)
{
    draw(pic, shift(xy)*scale(r)*((-1,-1)--(1,1)), fgpen);
    draw(pic, shift(xy)*scale(r)*((1,-1)--(-1,1)), fgpen);    
}

// draw a circle with an X in the middle on picture pic, at position xy with
// size r and pen fgpen. If erasebg is true, the background is erased in the
// inside of the circle.
void drawVertexOX(picture pic = currentpicture,
                  pair xy,
                  real r = bigvertexsize,
                  pen fgpen = vertexpen,
                  bool erasebg = overpaint,
                  pen bgpen = backgroundpen)
{
    if(erasebg)
        filldraw(pic, circle(xy, r), bgpen, fgpen);
    else
        draw(pic, circle(xy, r), fgpen);
    draw(pic, shift(xy)*scale(r)*(NW--SE), fgpen);
    draw(pic, shift(xy)*scale(r)*(SW--NE), fgpen);
}

// draw a box with an X in the middle on picture pic, at position xy with
// size r and pen fgpen. If erasebg is true, the background is erased in the
// inside of the box.
void drawVertexBoxX(picture pic = currentpicture,
                    pair xy,
                    real r = bigvertexsize,
                    pen fgpen = vertexpen,
                    bool erasebg = overpaint,
                    pen bgpen = backgroundpen)
{
    path box = (1,1)--(-1,1)--(-1,-1)--(1,-1)--cycle;
    box = shift(xy)*scale(r)*box;
    if(erasebg)
        filldraw(pic, box, bgpen, fgpen);
    else
        draw(pic, box, fgpen);
    draw(pic, shift(xy)*scale(r)*((-1,-1)--(1,1)), fgpen);
    draw(pic, shift(xy)*scale(r)*((1,-1)--(-1,1)), fgpen);
}

// draw a momentum arrow on picture pic, along path p, at position position
// (use one of the predefined pairs left or right), with an offset offset 
// from the path, a length length, a pen fgpen and an arrowhead arrow. Making
// adjust nonzero shifts the momentum arrow along the path. If erasebg is true,
// the background is erased inside a margin margin around the momentum arrow.
// Make sure that offset and margin are chosen in such a way that the momentum
// arrow does not overdraw the particle line.
void drawMomArrow(picture pic = currentpicture,
                  path p,
                  pair position,
                  real adjust = 0,
                  real offset = momarrowoffset,
                  real length = momarrowlength,
                  pen fgpen = momarrowpen,
                  arrowbar arrow = currentmomarrow,
                  bool erasebg = overpaint,
                  pen bgpen = backgroundpen,
                  real margin = momarrowmargin)
{
    path momarrow = momArrowPath(p, position, adjust, offset, length);
    if(erasebg) do_overpaint(pic, momarrow, bgpen, 
                             linewidth(fgpen)+margin, 90);
    draw(pic, momarrow, fgpen, arrow);
}

// draw a reverse momentum arrow on picture pic, along path p, at position
// position (use one of the predefined pairs left or right), with an offset
// offset from the path, a length length, a pen fgpen and an arrowhead arrow.
// Making adjust nonzero shifts the momentum arrow along the path.
// If erasebg is true, the background is erased inside a margin margin around
// the momentum arrow. Make sure that offset and margin are chosen in such
// a way that the momentum arrow does not overdraw the particle line.
void drawReverseMomArrow(picture pic = currentpicture,
                         path p,
                         pair position,
                         real adjust = 0,
                         real offset = momarrowoffset,
                         real length = momarrowlength,
                         pen fgpen = momarrowpen,
                         arrowbar arrow = currentmomarrow,
                         bool erasebg = overpaint,
                         pen bgpen = backgroundpen,
                         real margin = momarrowmargin)
{
    path momarrow = momArrowPath(p, position, adjust, offset, length);
    if(erasebg) do_overpaint(pic, reverse(momarrow), bgpen, 
                             linewidth(fgpen)+margin, 90);
    draw(pic, reverse(momarrow), fgpen, arrow);
}


/* initialisation ************************************************************/

// The function fmdefaults() tries to guess reasonable values for the
// default parameters above by looking at the default parameters of plain.asy
// (essentially, currentpen,  arrowsize and dotfactor). After customising the
// default parameters of plain.asy, you may call fmdefaults to adjust the
// parameters of feynman.asy.
void fmdefaults() 
{
    gluonratio = 2;
    photonratio = 4;
    gluonamplitude = arrowsize/3;
    photonamplitude = arrowsize/4;
    labeloffset = gluonamplitude;
    labelpostype = Relative;

    backgroundpen = white;
    gluonpen = currentpen;
    photonpen = currentpen;
    fermionpen = currentpen;
    scalarpen = dashed+linewidth(currentpen);
    ghostpen = dotted+linewidth(currentpen);
    doublelinepen = currentpen;
    vertexpen = currentpen;
    bigvertexpen = currentpen;
    currentarrow = MidArrow();

    doublelinespacing = 2*linewidth(currentpen);
    linemargin = 0.5*arrowsize;
    minvertexangle = 30;
    overpaint = true;
    vertexsize = 0.5*dotfactor*linewidth(currentpen);
    bigvertexsize = 0.4*arrowsize;

    currentmomarrow = EndArrow(0.75*arrowsize);
    momarrowlength = 2.5*arrowsize;
    momarrowpen = currentpen+min(0.5*linewidth(currentpen), 0.4);
    momarrowoffset = 0.8*arrowsize;
    momarrowmargin = 0.25*arrowsize;
}

// We call fmdefaults once, when the module is loaded.
fmdefaults();
