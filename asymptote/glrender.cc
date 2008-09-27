/*****
 * glrender.cc
 * John Bowman and Orest Shardt
 * Render 3D Bezier paths and surfaces.
 *****/

#include <stdlib.h>
#include <fstream>
#include "picture.h"
#include "common.h"
#include "arcball.h"
#include "bbox3.h"
#include "drawimage.h"

#ifdef HAVE_LIBGLUT

#include <GL/freeglut_ext.h>

namespace gl {
  
using camp::picture;
using camp::drawImage;
using camp::transform;
using camp::pair;
using camp::triple;
using vm::array;
using camp::bbox3;
using settings::getSetting;
using settings::Setting;

const double moveFactor=1.0;  
const double zoomFactor=1.05;
const double zoomFactorStep=0.25;
const double spinStep=60.0; // Degrees per second
const double arcballRadius=750.0;
const double resizeStep=1.5;

bool View;
int Oldpid;
const string* Prefix;
picture* Picture;
string Format;
int Width,Height;

double oWidth,oHeight;

bool Xspin,Yspin,Zspin;
int Fitscreen;
int Mode;

double H;
GLint viewportLimit[2];
double xmin,xmax;
double ymin,ymax;
double zmin,zmax;

double Xmin,Xmax;
double Ymin,Ymax;
double X,Y;

int minimumsize=50; // Minimum rendering window width and height

const double degrees=180.0/M_PI;
const double radians=1.0/degrees;

size_t Nlights;
triple *Lights; 
double *Diffuse;
double *Ambient;
double *Specular;
bool ViewportLighting;

int x0,y0;
int mod;

double lastangle;

double Zoom;
double lastzoom;

float Rotate[16];
float Modelview[16];

GLUnurbs *nurb;

int window;
  
template<class T>
inline T min(T a, T b)
{
  return (a < b) ? a : b;
}

template<class T>
inline T max(T a, T b)
{
  return (a > b) ? a : b;
}

void lighting(void)
{
  for(size_t i=0; i < Nlights; ++i) {
    GLenum index=GL_LIGHT0+i;
    glEnable(index);
    
    triple Lighti=Lights[i];
    GLfloat position[]={Lighti.getx(),Lighti.gety(),Lighti.getz(),0.0};
    glLightfv(index,GL_POSITION,position);
    
    size_t i4=4*i;
    
    GLfloat diffuse[]={Diffuse[i4],Diffuse[i4+1],Diffuse[i4+2],Diffuse[i4+3]};
    glLightfv(index,GL_DIFFUSE,diffuse);
    
    GLfloat ambient[]={Ambient[i4],Ambient[i4+1],Ambient[i4+2],Ambient[i4+3]};
    glLightfv(index,GL_AMBIENT,ambient);
    
    GLfloat specular[]={Specular[i4],Specular[i4+1],Specular[i4+2],
			Specular[i4+3]};
    glLightfv(index,GL_SPECULAR,specular);
  }
}

void save()
{  
  glFinish();
  glPixelStorei(GL_PACK_ALIGNMENT, 1);
  size_t ndata=3*Width*Height;
  unsigned char *data=new unsigned char[ndata];
  glReadPixels(0,0,Width,Height,GL_RGB,GL_UNSIGNED_BYTE,data);
  Picture->append(new drawImage(data,Width,Height,
				transform(0.0,0.0,oWidth,0.0,0.0,oHeight),
				true));
  Picture->shipout(NULL,*Prefix,Format,0.0,false,View);
  delete[] data;
}
  
void quit() 
{
  glutDestroyWindow(window);
  glutLeaveMainLoop();
}

void display(void)
{
  glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

  glMatrixMode(GL_MODELVIEW);
  
  if(!ViewportLighting) 
    lighting();
    
  triple m(xmin,ymin,zmin);
  triple M(xmax,ymax,zmax);
  double perspective=H == 0.0 ? 0.0 : 1.0/zmax;
  
  bool twosided=settings::getSetting<bool>("twosided");
  
  double size2=hypot(Width,Height)/Zoom;
  
  // Render opaque objects
  Picture->render(nurb,size2,m,M,perspective,false,twosided);
  
  // Enable transparency
  glEnable(GL_BLEND);
  glDepthMask(GL_FALSE);
  glBlendFunc(GL_SRC_ALPHA,GL_ONE_MINUS_SRC_ALPHA);
  
  // Render transparent objects
  Picture->render(nurb,size2,m,M,perspective,true,twosided);
  glDepthMask(GL_TRUE);
  glDisable(GL_BLEND);
  
  if(View) {
    glutSwapBuffers();
    int status;
    if(Oldpid != 0 && waitpid(Oldpid, &status, WNOHANG) != Oldpid) {
      kill(Oldpid,SIGHUP);
      Oldpid=0;
    }
  } else {
    glReadBuffer(GL_BACK_LEFT);
    save();
    quit();
  }
}

Arcball arcball;
  
void setProjection()
{
  glMatrixMode(GL_PROJECTION);
  glLoadIdentity();
  double Aspect=((double) Width)/Height;
  double X0=X*(xmax-xmin)/(lastzoom*Width);
  double Y0=Y*(ymax-ymin)/(lastzoom*Height);
  if(H == 0.0) {
    double xsize=Xmax-Xmin;
    double ysize=Ymax-Ymin;
    if(xsize < ysize*Aspect) {
      double r=0.5*ysize*Zoom*Aspect;
      xmin=-r-X0;
      xmax=r-X0;
      ymin=Ymin*Zoom-Y0;
      ymax=Ymax*Zoom-Y0;
    } else {
      double r=0.5*xsize*Zoom/Aspect;
      xmin=Xmin*Zoom-X0;
      xmax=Xmax*Zoom-X0;
      ymin=-r-Y0;
      ymax=r-Y0;
    }
    glOrtho(xmin,xmax,ymin,ymax,-zmax,-zmin);
  } else {
    double r=H*Zoom;
    xmin=-r*Aspect-X0;
    xmax=r*Aspect-X0;
    ymin=-r-Y0;
    ymax=r-Y0;
    glFrustum(xmin,xmax,ymin,ymax,-zmax,-zmin);
  }
  arcball.set_params(vec2(0.5*Width,0.5*Height),arcballRadius/Zoom);
}

bool capsize(int& width, int& height) 
{
  if(width > viewportLimit[0]) {
    width=viewportLimit[0];
    return true;
  }
  if(height > viewportLimit[1]) {
    height=viewportLimit[1];
    return true;
  }
  return false;
}

void reshape(int width, int height)
{
  if(capsize(width,height))
    glutReshapeWindow(width,height);
  
  X=X/Width*width;
  Y=Y/Height*height;
  
  Width=width;
  Height=height;
  
  setProjection();
  glViewport(0,0,Width,Height);
}
  
void update() 
{
  lastzoom=Zoom;
  glMatrixMode(GL_MODELVIEW);
  glLoadIdentity();
  double cz=0.5*(zmin+zmax);
  glTranslatef(0,0,cz);
  glMultMatrixf(Rotate);
  glTranslatef(0,0,-cz);
  glGetFloatv(GL_MODELVIEW_MATRIX,Modelview);
  setProjection();
  glutPostRedisplay();
}

void move(int x, int y)
{
  if(x > 0 && y > 0) {
    X += (x-x0)*Zoom;
    Y += (y0-y)*Zoom;
    x0=x; y0=y;
    update();
  }
}
  
void capzoom() 
{
  static double maxzoom=sqrt(DBL_MAX);
  static double minzoom=1/maxzoom;
  if(Zoom <= minzoom) Zoom=minzoom;
  if(Zoom >= maxzoom) Zoom=maxzoom;
  
}

void zoom(int x, int y)
{
  if(x > 0 && y > 0) {
    static const double limit=log(0.1*DBL_MAX)/log(zoomFactor);
    lastzoom=Zoom;
    double s=zoomFactorStep*(y-y0);
    if(fabs(s) < limit) {
      Zoom *= pow(zoomFactor,s);
      capzoom();
      y0=y;
      setProjection();
      glutPostRedisplay();
    }
  }
}
  
void mousewheel(int wheel, int direction, int x, int y) 
{
  lastzoom=Zoom;
  if(direction > 0)
    Zoom /= zoomFactor;
  else
    Zoom *= zoomFactor;
  
  capzoom();
  setProjection();
  glutPostRedisplay();
}

void rotate(int x, int y)
{
  if(x > 0 && y > 0) {
    arcball.mouse_motion(x,Height-y,0,
			 mod == GLUT_ACTIVE_SHIFT, // X rotation only
			 mod == GLUT_ACTIVE_CTRL);  // Y rotation only

    for(int i=0; i < 4; ++i) {
      const vec4& roti=arcball.rot[i];
      int i4=4*i;
      for(int j=0; j < 4; ++j)
	Rotate[i4+j]=roti[j];
    }
    update();
  }
}
  
double Degrees(int x, int y) 
{
  return atan2(0.5*Height-y-Y,x-0.5*Width-X)*degrees;
}

void updateArcball() 
{
  for(int i=0; i < 4; ++i) {
    int i4=4*i;
    vec4& roti=arcball.rot[i];
    for(int j=0; j < 4; ++j)
      roti[j]=Rotate[i4+j];
  }
  update();
}
  
void rotateX(double step) 
{
  glMatrixMode(GL_MODELVIEW);
  glLoadIdentity();
  glRotatef(step,1,0,0);
  glMultMatrixf(Rotate);
  glGetFloatv(GL_MODELVIEW_MATRIX,Rotate);
  updateArcball();
}

void rotateY(double step) 
{
  glMatrixMode(GL_MODELVIEW);
  glLoadIdentity();
  glRotatef(step,0,1,0);
  glMultMatrixf(Rotate);
  glGetFloatv(GL_MODELVIEW_MATRIX,Rotate);
  updateArcball();
}

void rotateZ(double step) 
{
  glMatrixMode(GL_MODELVIEW);
  glLoadIdentity();
  glRotatef(step,0,0,1);
  glMultMatrixf(Rotate);
  glGetFloatv(GL_MODELVIEW_MATRIX,Rotate);
  updateArcball();
}

void rotateZ(int x, int y)
{
  if(x > 0 && y > 0) {
    double angle=Degrees(x,y);
    rotateZ(angle-lastangle);
    lastangle=angle;
  }
}

// Mouse bindings.
// LEFT: rotate
// SHIFT LEFT: zoom
// CTRL LEFT: shift
// MIDDLE: menu
// RIGHT: zoom
// SHIFT RIGHT: rotateX
// CTRL RIGHT: rotateY
// ALT RIGHT: rotateZ
void mouse(int button, int state, int x, int y)
{
  mod=glutGetModifiers();
  if(state == GLUT_DOWN) {
    if(button == GLUT_LEFT_BUTTON && mod == GLUT_ACTIVE_CTRL) {
      x0=x; y0=y;
      glutMotionFunc(move);
      return;
    } 
    if((button == GLUT_LEFT_BUTTON && mod == GLUT_ACTIVE_SHIFT) ||
       (button == GLUT_RIGHT_BUTTON && mod == 0)) {
      y0=y;
      glutMotionFunc(zoom);
      return;
    }
    if(button == GLUT_RIGHT_BUTTON && mod == GLUT_ACTIVE_ALT) {
      lastangle=Degrees(x,y);
      glutMotionFunc(rotateZ);
      return;
    }
    arcball.mouse_down(x,Height-y);
    glutMotionFunc(rotate);
  } else
    arcball.mouse_up();
}

#include <sys/time.h>

timeval lasttime;

double spinstep() 
{
  timeval tv;
  gettimeofday(&tv,NULL);
  double step=spinStep*(tv.tv_sec-lasttime.tv_sec+
			((double) tv.tv_usec-lasttime.tv_usec)/1000000.0);
  lasttime=tv;
  return step;
}

void xspin()
{
  rotateX(spinstep());
}

void yspin()
{
  rotateY(spinstep());
}

void zspin()
{
  rotateZ(spinstep());
}

void initTimer() 
{
  gettimeofday(&lasttime,NULL);
}

void windowposition(int& x, int& y, int width, int height) 
{
  pair z=getSetting<pair>("position");
  x=(int) z.getx();
  y=(int) z.gety();
  if(x < 0) {
    x += glutGet(GLUT_SCREEN_WIDTH)-width;
    if(x < 0) x=0;
  }
  if(y < 0) {
    y += glutGet(GLUT_SCREEN_HEIGHT)-height;
    if(y < 0) y=0;
  }
}

void expand() 
{
  int x,y;
  int w=(int) (Width*resizeStep);
  int h=(int) (Height*resizeStep);
  capsize(w,h);
  glutReshapeWindow(w,h);
  windowposition(x,y,w,h);
  glutPositionWindow(x,y);
  glutPostRedisplay();
}

void shrink() 
{
  int x,y;
  int w=(int) (Width/resizeStep);
  int h=(int) (Height/resizeStep);
  capsize(w,h);
  glutReshapeWindow(w,h);
  windowposition(x,y,w,h);
  glutPositionWindow(x,y);
  glutPostRedisplay();
}

void fitscreen() 
{
  static int oldwidth,oldheight;
  int x,y;
  switch(Fitscreen) {
    case 0: // Original size
    {
      glutReshapeWindow(oldwidth,oldheight);
      windowposition(x,y,oldwidth,oldheight);
      glutPositionWindow(x,y);
     ++Fitscreen;
     break;
    }
    case 1: // Fit to screen in one dimension
    {
      oldwidth=Width;
      oldheight=Height;
      double Aspect=((double) Width)/Height;
      int w=glutGet(GLUT_SCREEN_WIDTH);
      int h=glutGet(GLUT_SCREEN_HEIGHT);
      if(w > 0 && h > 0) {
	if(w > h*Aspect) w=(int) (h*Aspect);
	else h=(int) (w/Aspect);
	glutReshapeWindow(w,h);
	windowposition(x,y,w,h);
	glutPositionWindow(x,y);
	reshape(w,h);
      }
      ++Fitscreen;
      break;
    }
    case 2: // Full screen
    {
      glutFullScreen();
      glutPositionWindow(0,0);
      Fitscreen=0;
      break;
    }
  }
}

void home() 
{
  glutIdleFunc(NULL);
  X=Y=0.0;
  arcball.init();
  glMatrixMode(GL_MODELVIEW);
  glLoadIdentity();
  glGetFloatv(GL_MODELVIEW_MATRIX,Rotate);
  Zoom=1.0;
  update();
}

void Export() 
{
  glReadBuffer(GL_FRONT_LEFT);
  save();
}

void idleFunc(void (*f)())
{
  initTimer();
  glutIdleFunc(f);
}

void mode() 
{
  switch(Mode) {
    case 0:
      glEnable(GL_LIGHTING);
      glPolygonMode(GL_FRONT_AND_BACK,GL_FILL);
      gluNurbsProperty(nurb,GLU_DISPLAY_MODE,GLU_FILL);
      ++Mode;
    break;
    case 1:
      glDisable(GL_LIGHTING);
      gluNurbsProperty(nurb,GLU_DISPLAY_MODE,GLU_OUTLINE_POLYGON);
      glPolygonMode(GL_FRONT_AND_BACK,GL_LINE);
      ++Mode;
    break;
    case 2:
      gluNurbsProperty(nurb,GLU_DISPLAY_MODE,GLU_OUTLINE_PATCH);
      Mode=0;
    break;
  }
  glutPostRedisplay();
}

void idle() 
{
  glutIdleFunc(NULL);
  Xspin=Yspin=Zspin=false;
}

void spinx() 
{
  if(Xspin)
    idle();
  else {
    idleFunc(xspin);
    Xspin=true;
    Yspin=Zspin=false;
  }
}

void spiny()
{
  if(Yspin)
    idle();
  else {
    idleFunc(yspin);
    Yspin=true;
    Xspin=Zspin=false;
  }
}

void spinz()
{
  if(Zspin)
    idle();
  else {
    idleFunc(zspin);
    Zspin=true;
    Xspin=Yspin=false;
  }
}

void keyboard(unsigned char key, int x, int y)
{
  switch(key) {
    case 'h':
      home();
      break;
    case 'f':
      fitscreen();
      glutPostRedisplay();
      break;
    case 'x':
      spinx();
      break;
    case 'y':
      spiny();
      break;
    case 'z':
      spinz();
      break;
    case 's':
      glutIdleFunc(NULL);
      break;
    case 'm':
      mode();
      break;
    case 'e':
      Export();
      break;
    case '+':
    case '=':
      expand();
      break;
    case '-':
    case '_':
      shrink();
      break;
    case 17: // Ctrl-q
    case 'q':
      if(!Format.empty()) Export();
      quit();
      break;
  }
}
 
enum Menu {HOME,FITSCREEN,XSPIN,YSPIN,ZSPIN,STOP,MODE,EXPORT,QUIT};

void menu(int choice)
{
  switch (choice) {
    case HOME: // Home
      home();
      break;
    case FITSCREEN:
      fitscreen();
      break;
    case XSPIN:
      spinx();
      break;
    case YSPIN:
      spiny();
      break;
    case ZSPIN:
      spinz();
      break;
    case STOP:
      glutIdleFunc(NULL);
      break;
    case MODE:
      mode();
      break;
    case EXPORT:
      Export();
      break;
    case QUIT:
      quit();
      break;
  }
}

// angle=0 means orthographic.
void glrender(const string& prefix, picture *pic, const string& format,
	      double width, double height,
	      double angle, const triple& m, const triple& M,
	      size_t nlights, triple *lights, double *diffuse,
	      double *ambient, double *specular, bool viewportlighting,
	      bool view, int oldpid)
{
  Prefix=&prefix;
  Picture=pic;
  Format=format;
  View=view;
  Oldpid=oldpid;
  Nlights=min(nlights,(size_t) GL_MAX_LIGHTS);
  Lights=lights;
  Diffuse=diffuse;
  Ambient=ambient;
  Specular=specular;
  ViewportLighting=viewportlighting;
    
  Xmin=m.getx();
  Xmax=M.getx();
  Ymin=m.gety();
  Ymax=M.gety();
  zmin=m.getz();
  zmax=M.getz();
  H=angle != 0.0 ? -tan(0.5*angle*radians)*zmax : 0.0;
   
  X=Y=0.0;
  lastzoom=Zoom=1.0;
  Xspin=Yspin=Zspin=false;
  
  Fitscreen=1;
  Mode=0;
  
  string options=string(settings::argv0)+" ";
#ifndef __CYGWIN__
  if(!View) options += "-iconic ";
#endif  
  options += getSetting<string>("glOptions");
  char **argv=args(options.c_str(),true);
  int argc=0;
  while(argv[argc] != NULL)
    ++argc;
  
  bool interactive=View && Format.empty();
  
  double expand=getSetting<double>("render");
  if(expand < 0)
    expand *= interactive ? -1.0 : 
      (Format.empty() || Format == "eps" || Format == "pdf" ? -4.0 : -2.0);
  
  glutInit(&argc,argv);
  glutInitDisplayMode(GLUT_DOUBLE | GLUT_RGBA | GLUT_DEPTH);
  
  glutInitWindowSize(1,1);
  window=glutCreateWindow("");
  glGetIntegerv(GL_MAX_VIEWPORT_DIMS, viewportLimit);
  glutDestroyWindow(window);

  // Work around direct rendering allocation bugs.
  int limit=(int) getSetting<Int>("maxviewport");
  if(limit > 0) {
    viewportLimit[0]=min(viewportLimit[0],limit);
    viewportLimit[1]=min(viewportLimit[1],limit);
  }

  oWidth=width;
  oHeight=height;
  double Aspect=((double) width)/height;
  
  Width=min(max((int) (expand*width),minimumsize),viewportLimit[0]);
  Height=min(max((int) (expand*height),minimumsize),viewportLimit[1]);
  
  if(Width > Height*Aspect) Width=(int) (Height*Aspect);
  else Height=(int) (Width/Aspect);
  
  if(settings::verbose > 1) 
    cout << "Rendering " << prefix << " as " << Width << "x" << Height
	 << " image" << endl;
    
  int x,y;
  windowposition(x,y,Width,Height);
  glutInitWindowPosition(x,y);
  
  glutInitWindowSize(Width,Height);
  window=glutCreateWindow((prefix+" [Click middle button for menu]").c_str());
  
  if(interactive && getSetting<bool>("fitscreen"))
    fitscreen();
  
  glClearColor(1.0,1.0,1.0,0.0);
   
  glEnable(GL_DEPTH_TEST);
  glEnable(GL_MAP1_VERTEX_3);
  glEnable(GL_MAP2_VERTEX_3);
  glEnable(GL_AUTO_NORMAL);
  
  glMapGrid2f(1,0.0,1.0,1,0.0,1.0);

  nurb=gluNewNurbsRenderer();
  gluNurbsProperty(nurb,GLU_SAMPLING_METHOD,GLU_PARAMETRIC_ERROR);
  gluNurbsProperty(nurb,GLU_SAMPLING_TOLERANCE,0.5);
  gluNurbsProperty(nurb,GLU_PARAMETRIC_TOLERANCE,1.0);
  gluNurbsProperty(nurb,GLU_CULLING,GLU_TRUE);
  
  // The callback tesselation algorithm avoids artifacts at degenerate control
  // points.
  gluNurbsProperty(nurb,GLU_NURBS_MODE,GLU_NURBS_TESSELLATOR);
  gluNurbsCallback(nurb,GLU_NURBS_BEGIN,(_GLUfuncptr) glBegin);
  gluNurbsCallback(nurb,GLU_NURBS_VERTEX,(_GLUfuncptr) glVertex3fv);
  gluNurbsCallback(nurb,GLU_NURBS_NORMAL,(_GLUfuncptr) glNormal3fv);
  gluNurbsCallback(nurb,GLU_NURBS_END,(_GLUfuncptr) glEnd);
  mode();
  
  glMatrixMode(GL_MODELVIEW);
  glLoadIdentity();
  glGetFloatv(GL_MODELVIEW_MATRIX,Rotate);
  glGetFloatv(GL_MODELVIEW_MATRIX,Modelview);
  
  glEnable(GL_LIGHTING);
  if(getSetting<bool>("twosided"))
    glLightModeli(GL_LIGHT_MODEL_TWO_SIDE,GL_TRUE);
  
  if(ViewportLighting)
    lighting();
  
  glutReshapeFunc(reshape);
  glutDisplayFunc(display);
  glutKeyboardFunc(keyboard);
  glutMouseFunc(mouse);
  glutMouseWheelFunc(mousewheel);
   
  glutSetOption(GLUT_ACTION_ON_WINDOW_CLOSE,GLUT_ACTION_CONTINUE_EXECUTION);

  glutCreateMenu(menu);
  glutAddMenuEntry("(h) Home",HOME);
  glutAddMenuEntry("(f) Fitscreen",FITSCREEN);
  glutAddMenuEntry("(x) X spin",XSPIN);
  glutAddMenuEntry("(y) Y spin",YSPIN);
  glutAddMenuEntry("(z) Z spin",ZSPIN);
  glutAddMenuEntry("(s) Stop",STOP);
  glutAddMenuEntry("(m) Mode",MODE);
  glutAddMenuEntry("(e) Export",EXPORT);
  glutAddMenuEntry("(q) Quit" ,QUIT);
  glutAttachMenu(GLUT_MIDDLE_BUTTON);

  glutMainLoop();
}
  
} // namespace gl

#endif
