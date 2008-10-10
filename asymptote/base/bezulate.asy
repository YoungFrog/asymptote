// Bezier triangulation routines written by Orest Shardt, 2008.

path[] patch(path p)
{
  path[] result;
  if(length(p) == 2) {
    result=subpath(p,0.0,0.5)&subpath(p,0.5,1.5)&subpath(p,1.5,2.0)&cycle;
  }
  else if(length(p) == 3) {
    // if possible, break up into three quads
    bool splitup = false;
    pair[] pt = {point(p,0),point(p,1),point(p,2)};
    pair[] m = {pt[1]+pt[2],pt[2]+pt[0],pt[0]+pt[1]};
    m = 0.5*m;
    pair c = m[0]+(1/3)*(pt[0]-m[0]);
    if(inside(p,c))
    {
      real L = abs(max(p)-min(p));
      // check intersections with sides
      real[] times;

      for(int i = 0; i < 3; ++i)
      {
        pair t = m[i]-c;
        real[][] ints = intersections(c--c+L*t/abs(t),p);
        if(ints.length > 0) times.push(ints[0][1]);
      }

      if(times.length == 3 
         && times[0] > 1 && times[0] < 2 
         && times[1] > 2 && times[1] < 3
         && times[2] > 0 && times[2] < 1)
      {
        splitup = true; // all checks passed
        // now do the split
        result = c--subpath(p,times[2],times[0])--cycle
            ^^c--subpath(p,times[0],times[1])--cycle
            ^^c--subpath(p,times[1],3+times[2])--cycle;
      }
    }
    // otherwise split the longest side
    if(!splitup)
    {
      real splitTime=0.5;
      real length1=arclength(subpath(p,0,1));
      real length2=arclength(subpath(p,1,2));
      real length3=arclength(subpath(p,2,3));
      if(length2 > length1 && length2 > length3)
        splitTime=1.5;
      if(length3 > length1 && length3 > length2)
        splitTime=2.5;
      result=subpath(p,0.0,splitTime)&subpath(p,splitTime,3.0)&cycle;
    }
  }
  else
    result = p;
  return result;
}

// sort so that later paths in the array are contained in previous paths
void sortByInside(path[] p)
{
  for(int i=p.length-1; i > 0; --i) {
    for(int j=0; j < i; ++j) {
      if(inside(p[j+1],p[j]) == 1) {
	path temp=p[j+1];
	p[j+1]=p[j];
	p[j]=temp;
      }
    }
  }
}

int countIntersections(path[] p, pair start, pair end)
{
  int intersects=0;
  for(path q : p)
    intersects += intersections(q,start--end).length;
  return intersects;
}

path[][] containmentTree(path[] paths)
{
  path[][] result;
  for(int i=0; i < paths.length; ++i) {
    bool classified=false;
    for(int j=0; !classified && j < result.length; ++j) {
      for(int k=0; !classified && k < result[j].length; ++k) {
	if(inside(paths[i],result[j][k]) != 0) {
	  result[j].push(paths[i]);
	  classified=true;
	}
      }
    }
    if(!classified)
      result.push(new path[] {paths[i]});
  }
  for(int i=0; i < result.length; ++i)
    sortByInside(result[i]);

  return result;
}

private real fuzz=10*realEpsilon;

bool isDuplicate(pair a, pair b)
{
  return abs(a-b) <= fuzz*max(abs(a),abs(b));
}

path removeDuplicates(path p)
{
  bool cyclic=cyclic(p);
  for(int i=0; i < length(p); ++i) {
    if(isDuplicate(point(p,i),point(p,i+1))) {
      p=subpath(p,0,i)&subpath(p,i+1,length(p));
      --i;
    }
  }
  return cyclic ? p&cycle : p;
}

path section(path p, real t1, real t2, bool loop=false)
{
  if(t2 < t1 || loop && t1 == t2)
    t2 += length(p);
  return subpath(p,t1,t2);
}

path uncycle(path p, real t)
{
  return subpath(p,t,t+length(p));
}

// TODO: check if fillrule is respected
// returns outer paths
path[] connect(path[] paths, path[] result, path[] patch, int depth=0)
{
  bool flag=depth%2 == 0;
  path[][] tree=containmentTree(paths);
  path[] outers;
  for(path[] group : tree) {
    if(group.length == 1) {
      if(flag)
	result.push(group[0]);
      else
	outers.push(group[0]);
    } else { // optimize case where group.length == 2 to avoid call to connect
      path[][] tree=containmentTree(group[1:]);
      path[] inners;
      for(path[] subgroup : tree) {
	//connect outer to result of connecting inner
	if(!flag) {
	  outers.append(connect(subgroup,result,patch,depth+1));
	} else {
	  path[] conn=connect(subgroup,result,patch,depth+1);
	  inners.append(conn);
	}
      }
      path outer=group[0];
      if(flag) {
	real d=2*abs(max(outer)-min(outer));
	for(int i=0; i < inners.length; ++i) {
	  path[] allCurves={outer};
	  allCurves.append(inners[i:]);

	  path inner=inners[i];
	  pair direction=I*dir(inner,0);
	  pair start=point(inner,0);
	  real starttime=0.0;
	  // find an outer point on inner curve in the chosen direction
	  starttime=intersections(start+d*direction--start,inner)[0][1];
	  start=point(inner,starttime);

	  // find earliest intersection
	  real[][] ints=intersections(start--start+d*direction,outer);
	  assert(ints.length != 0);
	  real endtime=ints[0][1];
	  real earliestTime=intersections(start--start+d*direction,outer)[0][0];
	  int curveIndex=0;
	  for(int j=i+1; j < inners.length; ++j) {
	    real[][] ints=intersections(start--start+d*direction,inners[j]);
	    if(ints.length > 0 && ints[0][0] < earliestTime) {
	      earliestTime=ints[0][0];
	      endtime=ints[0][1];
	      curveIndex=j+1;
	    }
	  }
	  pair end;
	  end=point(allCurves[curveIndex],endtime);

	  real timeoffset=2;
	  bool found=false;
	  while(!found && timeoffset > fuzz) {
	    timeoffset /= 2;
	    if(countIntersections(allCurves,start,
				  point(allCurves[curveIndex],
					endtime+timeoffset)) == 2)
	      found=true;
	  }
	  if(!found)timeoffset=-2;
	  while(!found && timeoffset > fuzz) {
	    timeoffset /= 2;
	    if(countIntersections(allCurves,start,
				  point(allCurves[curveIndex],
					endtime+timeoffset)) == 2)
	      found=true;
	  }
	  assert(found);
	  endtime=min(endtime,endtime+timeoffset);
	  timeoffset=abs(timeoffset);

	  path remainder=section(allCurves[curveIndex],endtime+timeoffset,
				 endtime)--uncycle(inner,starttime)--cycle;
	  if(curveIndex == 0)
	    outer=remainder;
	  else
	    inners[curveIndex-1]=remainder;
	  patch.append(patch(start--section(allCurves[curveIndex],endtime,
					    endtime+timeoffset)--cycle));
	}
      }
      outers.push(outer);
    }
  }
  return outers;
}

int countIntersections(path g, pair p, pair q)
{
  int ints=0;
  int l=length(g);
  for(int i=1; i <= l; ++i)
    ints += intersections(subpath(g,i-1,i),p--q).length;
  return ints;
}

bool checkSegment(path g, pair p, pair q)
{
  pair mid=(p+q)/2;
  return(countIntersections(g,p,q) == 4) && inside(g,mid) && 
    intersections(g,mid).length == 0;
}

path subdivide(path p)
{
  path q;
  int l=length(p);
  for(int i=0; i < l; ++i)
    q=q&subpath(p,i,i+0.5)&subpath(p,i+0.5,i+1);
  return cyclic(p) ? q&cycle : q;
}

path[] bezulate(path[] p)
{
  path[] patch;
  path[] result;
  result.append(connect(p,result,patch));
  for(int i=0; i < result.length; ++i) {
    path p=result[i];
    int refinements=0;
    static int maxR=ceil(-log(realEpsilon)/log(2))+1;
    if(!cyclic(p)) {
      abort("path must be cyclic and non-self-intersecting.");
    }
    p=removeDuplicates(p);
    if(length(p) > 4) {
      for(int i=0; length(p) > 4 && i < length(p); ++i) {
	bool found=false;
	pair start=point(p,i);
	//look for quadrilaterals and triangles with one line, 4 | 3 curves
	for(int desiredSides=4; !found && desiredSides >= 3; --desiredSides) {
	  if(desiredSides == 3 && length(p) <= 3)
	    break;
	  pair end;
	  int endi=i+desiredSides-1;
	  end=point(p,endi);
	  found=checkSegment(p,start,end);
	  if(found) {
	    path p1=subpath(p,endi,i+length(p))--cycle;
	    patch.append(patch(subpath(p,i,endi)--cycle));
	    p=removeDuplicates(p1);
            p = subpath(p,1,length(p)+1)&cycle; //shift indices
	    i=-1; // increment will make i be 0
	  }
	}
	if(!found && length(p) > 4 && i == length(p)-1) {
	  // avoid infinite recursion
	  ++refinements;
	  if(refinements > maxR) {
	    write("warning: too many subdivisions");
	  } else {
	    p=subdivide(p);
	    i=-1;
	  }
	}
      }
    }
    if(length(p) <= 4)
      patch.append(patch(p));
  }
  return patch;
}
