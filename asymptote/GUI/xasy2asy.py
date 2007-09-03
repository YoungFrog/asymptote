#!/usr/bin/env python
###########################################################################
#
# xasy2asy provides a Python interface to Asymptote
#
#
# Author: Orest Shardt
# Created: June 29, 2007
#
###########################################################################
import sys,os,signal,threading
from subprocess import *
from string import *
import xasyOptions
from Tkinter import *

#PIL support is now mandatory due to rotations
try:
  from PIL import ImageTk
  import Image
  PILAvailable = True
except:
  PILAvailable = False

import CubicBezier

class asyProcessFailure(Exception):
  """asy could not be invoked to execute a command because the process has failed."""
  pass

idCounter = 0;
randString = 'wGd3I26kOcu4ZI4arZZMqoJufO2h1QE2D728f1Lai3aqeTQC9'

quickAsyFailed = True

def startQuickAsy():
  global quickAsy
  global quickAsyFailed
  try:
    quickAsy.stdin.close()
    quickAsy.wait()
  except:
    pass
  try:
    quickAsyFailed = False
    quickAsy = Popen([xasyOptions.options['asyPath']]+split("-noV -q -multiline -interactive"),stdin=PIPE,stdout=PIPE,stderr=PIPE)
    if quickAsy.returncode != None:
      quickAsyFailed = True
  except:
    quickAsyFailed = True

def quickAsyRunning():
  if quickAsyFailed or quickAsy.returncode != None:
    return False
  else:
    return True

def asyExecute(command):
  if not quickAsyRunning():
    startQuickAsy()
  syncQuickAsyOutput()
  quickAsy.stdin.write(command)

def syncQuickAsyOutput():
  global idCounter
  idStr = randString+"-id "+str(idCounter)
  idCounter += 1
  quickAsy.stdin.write("\nwrite(\""+idStr+"\");\n")
  quickAsy.stdin.flush()
  line = quickAsy.stdout.readline()
  while not line.endswith(idStr+'\n'):
    line = quickAsy.stdout.readline()

class asyTransform:
  """A python implementation of an asy transform"""
  def __init__(self,initTuple):
    """Initialize the transform with a 6 entry tuple"""
    if type(initTuple) == type((0,)) and len(initTuple) == 6:
      self.t = initTuple
      self.x,self.y,self.xx,self.xy,self.yx,self.yy = initTuple
    else:
      raise Exception,"Illegal initializer for asyTransform"

  def getCode(self):
    """Obtain the asy code that represents this transform"""
    return str(self.t)

  def __str__(self):
    """Equivalent functionality to getCode(). It allows the expression str(asyTransform) to be meaningful."""
    return self.getCode()

  def __mul__(self,other):
    """Define multiplication of transforms as composition."""
    if type(other)==type((0,)):
      if len(other) == 6:
        return self*asyTransform(other)
      elif len(other) == 2:
        return ((self.t[0]+self.t[2]*other[0]+self.t[3]*other[1]),(self.t[1]+self.t[4]*other[0]+self.t[5]*other[1]))
      else:
        raise Exception, "Illegal multiplier of %s"%str(type(other))
    elif isinstance(other,asyTransform):
      result = asyTransform((0,0,0,0,0,0))
      result.x = self.x+self.xx*other.x+self.xy*other.y
      result.y = self.y+self.yx*other.x+self.yy*other.y
      result.xx = self.xx*other.xx+self.xy*other.yx
      result.xy = self.xx*other.xy+self.xy*other.yy
      result.yx = self.yx*other.xx+self.yy*other.yx
      result.yy = self.yx*other.xy+self.yy*other.yy
      result.t = (result.x,result.y,result.xx,result.xy,result.yx,result.yy)
      return result
    else:
      raise Exception, "Illegal multiplier of %s"%str(type(other))

identity = asyTransform((0,0,1,0,0,1))

class asyObj:
  """A base class for asy objects: an item represented by asymptote code."""
  def __init__(self):
    """Initialize the object"""
    self.asyCode = ""

  def updateCode(self):
    """Update the object's code: should be overriden."""
    pass

  def getCode(self):
    """Return the code describing the object"""
    self.updateCode()
    return self.asyCode

class asyPen(asyObj):
  """A python wrapper for an asymptote pen"""
  def __init__(self,color=(0,0,0),width=0.5,options=""):
    """Initialize the pen"""
    asyObj.__init__(self)
    self.options=options
    self.width=width
    self.setColor(color)
    self.updateCode()
    if options != "":
      self.computeColor()

  def updateCode(self):
    """Generate the pen's code"""
    self.asyCode = "rgb(%g,%g,%g)"%self.color+"+"+str(self.width)
    if len(self.options) > 0:
      self.asyCode += "+"+self.options

  def setWidth(self,newWidth):
    """Set the pen's width"""
    self.width=newWidth
    self.updateCode()

  def setColor(self,color):
    """Set the pen's color"""
    if type(color) == type((1,)) and len(color) == 3:
      self.color = color
    else:
      self.color = "(0,0,0)"
    self.updateCode()

  def computeColor(self):
    """Find out the color of an arbitrary asymptote pen."""
    syncQuickAsyOutput()
    quickAsy.stdin.write("pen p="+self.getCode()+';\n')
    quickAsy.stdin.write("write(\";\n\");write(colorspace(p));\n")
    quickAsy.stdin.write("write(colors(p));\n")
    quickAsy.stdin.flush()
    quickAsy.stdout.readline()
    quickAsy.stdout.readline()
    colorspace = quickAsy.stdout.readline()
    if colorspace.find("cmyk") != -1:
      lines = quickAsy.stdout.readline()+quickAsy.stdout.readline()+quickAsy.stdout.readline()+quickAsy.stdout.readline()
      parts = lines.split()
      c,m,y,k = eval(parts[2]),eval(parts[4]),eval(parts[6]),eval(parts[8])
      k = 1-k
      r,g,b = ((1-c)*k,(1-m)*k,(1-y)*k)
    elif colorspace.find("rgb") != -1:
      lines = quickAsy.stdout.readline()+quickAsy.stdout.readline()+quickAsy.stdout.readline()
      parts = lines.split()
      r,g,b = eval(parts[2]),eval(parts[4]),eval(parts[6])
    elif colorspace.find("gray") != -1:
      lines = quickAsy.stdout.readline()
      parts = lines.split()
      r = g = b = eval(parts[2])
    self.color = (r,g,b)

  def tkColor(self):
    """Return the tk version of the pens color"""
    self.computeColor()
    r,g,b = self.color
    r,g,b = int(256*r),int(256*g),int(256*b)
    if r == 256:
      r = 255
    if g == 256:
      g = 255
    if b == 256:
      b = 255
    r,g,b = map(hex,(r,g,b))
    r,g,b = r[2:],g[2:],b[2:]
    if len(r) < 2:
      r += '0'
    if len(g) < 2:
      g += '0'
    if len(b) < 2:
      b += '0'
    return'#'+r+g+b

class asyPath(asyObj):
  """A python wrapper for an asymptote path"""
  def __init__(self):
    """Initialize the path to be an empty path: a path with no nodes, control points, or links."""
    asyObj.__init__(self)
    self.nodeSet = []
    self.linkSet = []
    self.controlSet = []
    self.computed = False

  def initFromNodeList(self,nodeSet,linkSet):
    """Initialize the path from a set of nodes and link types, "--", "..", or "::" """
    if len(nodeSet)>0:
      self.nodeSet = nodeSet[:]
      self.linkSet = linkSet[:]
      self.computed = False

  def initFromControls(self,nodeSet,controlSet):
    """Initialize the path from nodes and control points"""
    self.controlSet = controlSet[:]
    self.nodeSet = nodeSet[:]
    self.computed = True

  def makeNodeStr(self,node):
    """Represent a node as a string"""
    if node == 'cycle':
      return node
    else:
      return "("+str(node[0])+","+str(node[1])+")"

  def updateCode(self):
    """Generate the code describing the path"""
    if not self.computed:
      count = 0
      #this string concatenation could be optimised
      self.asyCode = self.makeNodeStr(self.nodeSet[0])
      for node in self.nodeSet[1:]:
        self.asyCode += self.linkSet[count]+self.makeNodeStr(node)
        count += 1
    else:
      count = 0
      #this string concatenation could be optimised
      self.asyCode = self.makeNodeStr(self.nodeSet[0])
      for node in self.nodeSet[1:]:
        self.asyCode += "..controls"
        self.asyCode += self.makeNodeStr(self.controlSet[count][0])
        self.asyCode += "and"
        self.asyCode += self.makeNodeStr(self.controlSet[count][1])
        self.asyCode += ".." + self.makeNodeStr(node) + "\n"
        count += 1

  def getNode(self,index):
    """Return the requested node"""
    return self.nodeSet[index]

  def getLink(self,index):
    """Return the requested link"""
    return self.linkSet[index]

  def setNode(self,index,newNode):
    """Set a node to a new position"""
    self.nodeSet[index] = newNode

  def moveNode(self,index,offset):
    """Translate a node"""
    if self.nodeSet[index] != "cycle":
      self.nodeSet[index] = (self.nodeSet[index][0]+offset[0],self.nodeSet[1]+offset[1])

  def setLink(self,index,ltype):
    """Change the specified link"""
    self.linkSet[index] = ltype

  def addNode(self,point,ltype):
    """Add a node to the end of a path"""
    self.nodeSet.append(point)
    if len(self.nodeSet) != 1:
      self.linkSet.append(ltype)
    if self.computed:
      self.computeControls()

  def insertNode(self,index,point,ltype=".."):
    """Insert a node, and its corresponding link, at the given index"""
    self.nodeSet.insert(index,point)
    self.linkSet.insert(index,ltype)
    if self.computed:
      self.computeControls()

  def setControl(self,index,position):
    """Set a control point to a new position"""
    self.controlSet[index] = position

  def moveControl(self,index,offset):
    """Translate a control point"""
    self.controlSet[index] = (self.controlSet[index][0]+offset[0],self.controlSet[index][1]+offset[1])

  def computeControls(self):
    """Evaluate the code of the path to obtain its control points"""
    syncQuickAsyOutput()
    quickAsy.stdin.write("path p="+self.getCode()+';\n')
    quickAsy.stdin.write("write(length(p));\n")
    quickAsy.stdin.write("write(p);write(\"\");\n")
    quickAsy.stdin.flush()
    lengthStr = quickAsy.stdout.readline()
    #print "length",lengthStr
    pathSegments = eval(lengthStr.split()[-1])
    pathStrLines = []
    for i in range(pathSegments+1):
      #print text
      pathStrLines.append(quickAsy.stdout.readline())
    #print "path",pathStrLines
    oneLiner = "".join(split(join(pathStrLines)))
    oneLiner = oneLiner.replace(">","")
    splitList = oneLiner.split("..")
    nodes = [a for a in splitList if a.find("controls")==-1]
    self.nodeSet = []
    for a in nodes:
      if a == 'cycle':
        self.nodeSet.append(a)
      else:
        self.nodeSet.append(eval(a))
    controls = [a.replace("controls","").split("and") for a in splitList if a.find("controls") != -1]
    self.controlSet = [[eval(a[0]),eval(a[1])] for a in controls]
    #print "nodes",self.nodeSet
    #print "controls",self.controlSet
    self.computed = True


unitcircle = asyPath()
#(1,0).. controls (1,0.552285) and (0.552285,1)
# ..(0,1).. controls (-0.552285,1) and (-1,0.552285)
# ..(-1,0).. controls (-1,-0.552285) and (-0.552285,-1)
# ..(0,-1).. controls (0.552285,-1) and (1,-0.552285)
# ..cycle
unitcircle.initFromControls([(1,0),(0,1),(-1,0),(0,-1),'cycle'],[[(1,0.552285),(0.552285,1)],[(-0.552285,1),(-1,0.552285)],[(-1,-0.552285),(-0.552285,-1)],[(0.552285,-1),(1,-0.552285)]])

unitsquare = asyPath()
#(0,0).. controls (0.333333,0) and (0.666667,0)
# ..(1,0).. controls (1,0.333333) and (1,0.666667)
# ..(1,1).. controls (0.666667,1) and (0.333333,1)
# ..(0,1).. controls (0,0.666667) and (0,0.333333)
# ..cycle
unitsquare.initFromControls([(0,0),(1,0),(1,1),(0,1),'cycle'],[[(0.333333,0),(0.666667,0)],[(1,0.333333),(1,0.666667)],[(0.666667,1),(0.333333,1)],[(0,0.666667),(0,0.333333)]])

class asyLabel(asyObj):
  """A python wrapper for an asy label"""
  def __init__(self,text="",location=(0,0),pen=asyPen()):
    """Initialize the label with the given test, location, and pen"""
    asyObj.__init__(self)
    self.text = text
    self.location = location
    self.pen = pen

  def updateCode(self):
    """Generate the code describing the label"""
    self.asyCode = "Label(\""+self.text+"\","+str((self.location[0],self.location[1]))+","+self.pen.getCode()+",align=SE)"

  def setText(self,text):
    """Set the label's text"""
    self.text = text
    self.updateCode()

  def setPen(self,pen):
    """Set the label's pen"""
    self.pen = pen
    self.updateCode()

  def moveTo(self,newl):
    """Translate the label's location"""
    self.location = newl

class asyImage:
  """A structure containing an image and its format, bbox, and IDTag"""
  def __init__(self,image,format,bbox):
    self.image = image
    self.format = format
    self.bbox = bbox
    self.IDTag = None

class xasyItem:
  """A base class for items in the xasy GUI"""
  def __init__(self,canvas=None):
    """Initialize the item to an empty item"""
    self.transform = identity
    self.asyCode = ""
    self.imageList = []
    self.IDTag = None
    self.asyfied = False
    self.onCanvas = canvas

  def updateCode(self):
    """Update the item's code: to be overriden"""
    pass

  def getCode(self):
    """Return the code describing the item"""
    self.updateCode()
    return self.asyCode

  def handleImageReception(self,file,format,bbox,count):
    """Receive an image from an asy deconstruction. It replaces the default in asyProcess."""
    if bbox[0] == 0 and bbox[1] == 0 and bbox[2] == 0 and bbox[3] == 0:
      image = None
    else:
      image = Image.open(file)
      #os.remove(file)
      #if format == "gif":
        #image = PhotoImage(file=file)#os.path.join(asy.startDir,file))
      #else:
        #image = ImageTk.PhotoImage(file=file)#os.path.join(asy.startDir,file))
    self.imageList.append(asyImage(image,format,bbox))
    if self.onCanvas != None and image != None:
      self.imageList[-1].itk = ImageTk.PhotoImage(image)
      self.imageList[-1].originalImage = image.copy()
      self.imageList[-1].originalImage.theta = 0.0
      self.imageList[-1].originalImage.bbox = bbox
      self.imageList[-1].IDTag = self.onCanvas.create_image(bbox[0],-bbox[3],anchor=NW,tags=("image"),image=self.imageList[-1].itk)
      self.onCanvas.update()

  def asyfy(self):
    """Convert the item to a list of images by deconstructing this item's code"""
    self.removeFromCanvas()
    self.imageList = []
    quickAsy.stdin.write("\nreset;\n")
    quickAsy.stdin.write("initXasyMode();\n")
    quickAsy.stdin.write("atexit(null);\n")
    syncQuickAsyOutput()
    for line in self.getCode().splitlines():
      quickAsy.stdin.write(line+"\n");
    quickAsy.stdin.flush()
    syncQuickAsyOutput()
    try:
      os.remove(".out_0.box")
    except:
      pass
    quickAsy.stdin.write("deconstruct(countonly=true);\n")
    quickAsy.stdin.write("deconstruct();\n")
    quickAsy.stdin.flush()
    numpics = quickAsy.stdout.readline()
    numpics = int(numpics[2:])
    #print "Expecting",numpics
    for i in range(numpics):
      #print "waiting for",i,
      text = quickAsy.stdout.readline()
      #print " got it"
      boxfile = open(".out_0.box","rt")
      boxlines = boxfile.readlines()
      magnification,format = split(boxlines[0])
      l,b,r,t = [float(a) for a in split(boxlines[i+1])]
      self.handleImageReception(".out_%d.%s"%(i,format),format,(l,b,r,t),i)
      boxfile.close()
    try:
      os.remove(".out_0.box")
    except:
      pass
    self.asyfied = True
  def drawOnCanvas(self,canvas):
    pass
  def removeFromCanvas(self):
    pass

class xasyDrawnItem(xasyItem):
  """A base class for GUI items was drawn by the user. It combines a path, a pen, and a transform."""
  def __init__(self,path,pen = asyPen(),transform = identity):
    """Initialize the item with a path, pen, and transform"""
    xasyItem.__init__(self)
    self.path = path
    self.pen = pen
    self.transform = transform

  def appendPoint(self,point,link=None):
    """Append a point to the path. If the path is cyclic, add this point before the 'cycle' node."""
    if self.path.nodeSet[-1] == 'cycle':
      self.path.nodeSet[-1] = point
      self.path.nodeSet.append('cycle')
    else:
      self.path.nodeSet.append(point)
    self.path.computed = False
    if len(self.path.nodeSet) > 1 and link != None:
      self.path.linkSet.append(link)

  def clearTransform(self):
    """Reset the item's transform"""
    self.transform = identity

  def removeLastPoint(self):
    """Remove the last point in the path. If the path is cyclic, remove the node before the 'cycle' node."""
    if self.path.nodeSet[-1] == 'cycle':
      del self.path.nodeSet[-2]
    else:
      del self.path.nodeSet[-1]
    del self.path.linkSet[-1]
    self.path.computed = False

  def setLastPoint(self,point):
    """Modify the last point in the path. If the path is cyclic, modify the node before the 'cycle' node."""
    if self.path.nodeSet[-1] == 'cycle':
      self.path.nodeSet[-2] = point
    else:
      self.path.nodeSet[-1] = point
    self.path.computed = False

class xasyShape(xasyDrawnItem):
  """An outlined shape drawn on the GUI"""
  def __init__(self,path,pen=asyPen(),transform=identity):
    """Initialize the shape with a path, pen, and transform"""
    xasyDrawnItem.__init__(self,path,pen,transform)

  def updateCode(self):
    """Generate the code to describe this shape"""
    self.asyCode = "xformStack.push("+self.transform.getCode()+");\n"
    self.asyCode += "draw("+self.path.getCode()+","+self.pen.getCode()+");"

  def removeFromCanvas(self,canvas):
    """Remove the shape's depiction from a tk canvas"""
    if self.IDTag != None:
      canvas.delete(self.IDTag)

  def drawOnCanvas(self,canvas,asyFy=False,forceAddition=False):
    """Add this shape to a tk canvas"""
    if not asyFy:
      if self.IDTag == None or forceAddition:
        #add ourselves to the canvas
        self.path.computeControls()
        self.IDTag = canvas.create_line(0,0,0,0,tags=("drawn","xasyShape"),fill=self.pen.tkColor(),width=self.pen.width)
        self.drawOnCanvas(canvas)
      else:
        self.path.computeControls()
        pointSet = []
        previousNode = self.path.nodeSet[0]
        nodeCount = 0
        if len(self.path.nodeSet) == 0:
          pointSet = [0,0,0,0]
        elif len(self.path.nodeSet) == 1:
          if self.path.nodeSet[-1] != 'cycle':
            p = self.transform*(self.path.nodeSet[0][0],self.path.nodeSet[0][1])
            pointSet = [p[0],-p[1],p[0],-p[1],p[0],-p[1]]
          else:
            pointSet = [0,0,0,0]
        else:
          for node in self.path.nodeSet[1:]:
            if node == 'cycle':
              node = self.path.nodeSet[0]
            points = CubicBezier.makeBezier(self.transform*previousNode,self.transform*self.path.controlSet[nodeCount][0],self.transform*self.path.controlSet[nodeCount][1],self.transform*node)
            for point in points:
              pointSet += [point[0],-point[1]]
            nodeCount += 1
            previousNode = node
        canvas.coords(self.IDTag,*pointSet)
        canvas.itemconfigure(self.IDTag,fill=self.pen.tkColor(),width=self.pen.width)
    else:
      #first asyfy then add an image list
      pass

  def __str__(self):
    """Create a string describing this shape"""
    return "xasyShape code:%s"%("\n\t".join(self.getCode().splitlines()))

class xasyFilledShape(xasyShape):
  """A filled shape drawn on the GUI"""
  def __init__(self,path,pen=asyPen(),transform=identity):
    """Initialize this shape with a path, pen, and transform"""
    if path.nodeSet[-1] != 'cycle':
      raise Exception,"Filled paths must be cyclic"
    xasyShape.__init__(self,path,pen,transform)

  def updateCode(self):
    """Generate the code describing this shape"""
    self.asyCode = "xformStack.push("+self.transform.getCode()+");\n"
    self.asyCode += "fill("+self.path.getCode()+","+self.pen.getCode()+");"

  def removeFromCanvas(self,canvas):
    """Remove this shape's depiction from a tk canvas"""
    if self.IDTag != None:
      canvas.delete(self.IDTag)

  def drawOnCanvas(self,canvas,asyFy=False,forceAddition=False):
    """Add this shape to a tk canvas"""
    if not asyFy:
      if self.IDTag == None or forceAddition:
        #add ourselves to the canvas
        self.path.computeControls()
        self.IDTag = canvas.create_polygon(0,0,0,0,0,0,tags=("drawn","xasyFilledShape"),fill=self.pen.tkColor(),outline=self.pen.tkColor(),width=1)
        self.drawOnCanvas(canvas)
      else:
        self.path.computeControls()
        pointSet = []
        previousNode = self.path.nodeSet[0]
        nodeCount = 0
        if len(self.path.nodeSet) == 0:
          pointSet = [0,0,0,0,0,0]
        elif len(self.path.nodeSet) == 1:
          if self.path.nodeSet[-1] != 'cycle':
            p = self.transform*(self.path.nodeSet[0][0],self.path.nodeSet[0][1])
            pointSet = [p[0],-p[1],p[0],-p[1],p[0],-p[1]]
          else:
            pointSet = [0,0,0,0,0,0]
        elif len(self.path.nodeSet) == 2:
          if self.path.nodeSet[-1] != 'cycle':
            p = self.transform*(self.path.nodeSet[0][0],self.path.nodeSet[0][1])
            p2 = self.transform*(self.path.nodeSet[1][0],self.path.nodeSet[1][1])
            pointSet = [p[0],-p[1],p2[0],-p2[1],p[0],-p[1]]
          else:
            pointSet = [0,0,0,0,0,0]
        else:
          for node in self.path.nodeSet[1:]:
            if node == 'cycle':
              node = self.path.nodeSet[0]
            points = CubicBezier.makeBezier(self.transform*previousNode,self.transform*self.path.controlSet[nodeCount][0],self.transform*self.path.controlSet[nodeCount][1],self.transform*node)
            for point in points:
              pointSet += [point[0],-point[1]]
            nodeCount += 1
            previousNode = node
        canvas.coords(self.IDTag,*pointSet)
        canvas.itemconfigure(self.IDTag,fill=self.pen.tkColor(),outline=self.pen.tkColor(),width=1)
    else:
      #first asyfy then add an image list
      pass

  def __str__(self):
    """Return a string describing this shape"""
    return "xasyFilledShape code:%s"%("\n\t".join(self.getCode().splitlines()))

class xasyText(xasyItem):
  """Text created by the GUI"""
  def __init__(self,text,location,pen=asyPen(),transform=identity):
    """Initialize this item with text, a location, pen, and transform"""
    xasyItem.__init__(self)
    self.label=asyLabel(text,location,pen)
    self.transform = [transform]
    self.onCanvas = None

  def updateCode(self):
    """Generate the code describing this object"""
    self.asyCode = "xformStack.push("+self.transform[0].getCode()+");\n"
    self.asyCode += "label("+self.label.getCode()+");"

  def removeFromCanvas(self):
    """Removes the label's images from a tk canvas"""
    if self.onCanvas == None:
      return
    for image in self.imageList:
      if image.IDTag != None:
        self.onCanvas.delete(image.IDTag)

  def drawOnCanvas(self,canvas,asyFy = True):
    """Adds the label's images to a tk canvas"""
    if self.onCanvas == None:
      self.onCanvas = canvas
    elif self.onCanvas != canvas:
      raise Exception,"Error: item cannot be added to more than one canvas"
    self.asyfy()

  def __str__(self):
    return "xasyText code:%s"%("\n\t".join(self.getCode().splitlines()))

class xasyScript(xasyItem):
  """A set of images create from asymptote code. It is always deconstructed."""
  def __init__(self,canvas,script="",transforms=[]):
    """Initialize this script item"""
    xasyItem.__init__(self,canvas)
    self.transform = transforms[:]
    self.script = script

  def clearTransform(self):
    """Reset the transforms for each of the deconstructed images""" 
    self.transform = [identity for im in self.imageList]

  def updateCode(self):
    """Generate the code describing this script"""
    self.asyCode = "";
    if len(self.transform) > 0:
      self.asyCode = "xformStack.add("
      isFirst = True
      count = 0
      for xform in self.transform:
        if not isFirst:
          self.asyCode+=",\n"
        self.asyCode += "indexedTransform(%d,%s)"%(count,str(xform))
        isFirst = False
        count += 1
      self.asyCode += ");\n"
    self.asyCode += "startScript();{\n"
    self.asyCode += self.script.replace("\t"," ")
    self.asyCode = self.asyCode.rstrip()
    self.asyCode += "\n}endScript();\n"

  def setScript(self,script):
    """Sets the content of the script item. If the imageList is enlarged, identities are added; if the list is shrunk, transforms are removed."""
    self.script = script
    self.updateCode()

  def removeFromCanvas(self):
    """Removes the script's images from a tk canvas"""
    if self.onCanvas == None:
      return
    for image in self.imageList:
      if image.IDTag != None:
        self.onCanvas.delete(image.IDTag)

  def asyfy(self):
    xasyItem.asyfy(self)
    while len(self.imageList) > len(self.transform):
      self.transform.append(identity)
    while len(self.imageList) < len(self.transform):
      self.transform.pop()
    self.updateCode()

  def drawOnCanvas(self,canvas,asyFy = True):
    """Adds the script's images to a tk canvas"""
    if self.onCanvas == None:
      self.onCanvas = canvas
    elif self.onCanvas != canvas:
      raise Exception,"Error: item cannot be added to more than one canvas"
    self.asyfy()

  def __str__(self):
    """Return a string describing this script"""
    retVal = "xasyScript\n\tTransforms:\n"
    for xform in self.transform:
      retVal += "\t"+str(xform)+"\n"
    retVal += "\tCode Ommitted"
    return retVal

if __name__=='__main__':
  root = Tk()
  t=xasyText("test",(0,0))
  t.asyfy()
