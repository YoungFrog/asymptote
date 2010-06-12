/****
 * memory.h
 *
 * Interface to the Boehm Garbage Collector.
 *****/

#ifndef MEMORY_H
#define MEMORY_H

#include <list>
#include <vector>
#include <stack>
#include <map>
#include <string>
#include <sstream>

#ifndef NOHASH
#ifndef __GNUC_PREREQ
#define __GNUC_PREREQ(maj, min) (0)
#endif
#if __GNUC_PREREQ(4,3) || defined(__CYGWIN__)
#include <tr1/unordered_map>
#define EXT std::tr1
#else
#define EXT __gnu_cxx
#include <ext/hash_map>
#define unordered_map hash_map
#define unordered_multimap hash_multimap
#endif
#endif

#ifdef __DECCXX_LIBCXX_RH70
#define CONST
#else
#define CONST const  
#endif
  
#ifdef USEGC

#define GC_THREADS
#include <gc.h>

#ifdef GC_DEBUG
extern "C" {
#include <gc_backptr.h>
}
#endif

inline void *asy_malloc(size_t n)
{
#ifdef GC_DEBUG
  if(void *mem=GC_debug_malloc_ignore_off_page(n, GC_EXTRAS))
#else
    if(void *mem=GC_malloc_ignore_off_page(n))
#endif
      return mem;
  throw std::bad_alloc();
}

inline void *asy_malloc_atomic(size_t n)
{
#ifdef GC_DEBUG
  if(void *mem=GC_debug_malloc_atomic_ignore_off_page(n, GC_EXTRAS))
#else
    if(void *mem=GC_malloc_atomic_ignore_off_page(n))
#endif
      return mem;
  throw std::bad_alloc();
}

#undef GC_MALLOC
#undef GC_MALLOC_ATOMIC

#define GC_MALLOC(sz) asy_malloc(sz)
#define GC_MALLOC_ATOMIC(sz) asy_malloc_atomic(sz)

#include <gc_allocator.h>
#include <gc_cpp.h>

#else // USEGC

using std::allocator;
#define gc_allocator allocator

class gc {};
class gc_cleanup {};

enum GCPlacement {UseGC, NoGC, PointerFreeGC};

inline void* operator new(size_t size, GCPlacement) {
  return operator new(size);
}

inline void* operator new[](size_t size, GCPlacement) {
  return operator new(size);
}

template<class T>
struct GC_type_traits {};

#define GC_DECLARE_PTRFREE(T)                   \
  template<> struct GC_type_traits<T> {}

#endif // USEGC

namespace mem {

#define GC_CONTAINER(KIND)                                              \
  template <typename T>                                                 \
  struct KIND : public std::KIND<T, gc_allocator<T> >, public gc {      \
    KIND() : std::KIND<T, gc_allocator<T> >() {}                        \
    KIND(size_t n) : std::KIND<T, gc_allocator<T> >(n) {}               \
    KIND(size_t n, const T& t) : std::KIND<T, gc_allocator<T> >(n,t) {} \
  }

GC_CONTAINER(list);
GC_CONTAINER(vector);

template <typename T, typename Container = vector<T> >
struct stack : public std::stack<T, Container>, public gc {
};

#undef GC_CONTAINER

#define GC_CONTAINER(KIND)                                              \
  template <typename Key, typename T, typename Compare = std::less<Key> > \
  struct KIND : public                                                  \
  std::KIND<Key,T,Compare,gc_allocator<std::pair<Key,T> > >, public gc { \
    KIND() : std::KIND<Key,T,Compare,gc_allocator<std::pair<Key,T> > > () {} \
  }

GC_CONTAINER(map);
GC_CONTAINER(multimap);

#undef GC_CONTAINER

#ifndef NOHASH
#define GC_CONTAINER(KIND)                                              \
  template <typename Key, typename T,                                   \
            typename Hash = EXT::hash<Key>,                             \
            typename Eq = std::equal_to<Key> >                          \
  struct KIND : public                                                  \
  EXT::KIND<Key,T,Hash,Eq,gc_allocator<std::pair<Key, T> > >, public gc { \
    KIND() : EXT::KIND<Key,T,Hash,Eq,gc_allocator<std::pair<Key, T> > > () {} \
    KIND(size_t n)                                                      \
      : EXT::KIND<Key,T,Hash,Eq,gc_allocator<std::pair<Key, T> > > (n) {} \
  }

GC_CONTAINER(unordered_map);
GC_CONTAINER(unordered_multimap);

#undef GC_CONTAINER
#undef EXT
#endif

#ifdef USEGC
typedef std::basic_string<char,std::char_traits<char>,
                          gc_allocator<char> > string;
typedef std::basic_stringstream<char,std::char_traits<char>,
                                gc_allocator<char> > stringstream;
typedef std::basic_istringstream<char,std::char_traits<char>,
                                 gc_allocator<char> > istringstream;
typedef std::basic_ostringstream<char,std::char_traits<char>,
                                 gc_allocator<char> > ostringstream;
typedef std::basic_stringbuf<char,std::char_traits<char>,
                             gc_allocator<char> > stringbuf;
#else
typedef std::string string;
typedef std::stringstream stringstream;
typedef std::istringstream istringstream;
typedef std::ostringstream ostringstream;
typedef std::stringbuf stringbuf;
#endif // USEGC

} // namespace mem

#endif
