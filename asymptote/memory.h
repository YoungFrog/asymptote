/****
 * memory.h
 *
 * Interface to the Boehm Garbage Collector.
 *****/

#ifndef MEMORY_H
#define MEMORY_H

#include <list>
#include <vector>
#include <deque>
#include <stack>
#include <map>
#include <string>

#ifndef NOHASH
#include <ext/hash_map>
#endif

#if defined(__DECCXX_LIBCXX_RH70)
#define CONST
#else
#define CONST const  
#endif
  
#ifdef USEGC

#include <gc.h>

// WARNING: This is copied from gc6.8/include/gc.h and will conceivably change
// in future versions of gc.
# ifdef GC_DEBUG
#   define GC_OLD_MALLOC(sz) GC_debug_malloc(sz, GC_EXTRAS)
# else
#   define GC_OLD_MALLOC(sz) GC_malloc(sz)
#endif

extern "C" {
#include <gc_backptr.h>
}

#undef GC_MALLOC
inline void *GC_MALLOC(size_t n) { \
  if (void *mem=GC_OLD_MALLOC(n))  \
    return mem;                    \
  GC_generate_random_backtrace();  \
  throw std::bad_alloc();          \
}
  
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

#define GC_MALLOC(size) ::operator new(size)
#define GC_FREE(ptr) ::operator delete(ptr)

#endif // USEGC

namespace mem {

#define GC_CONTAINER(KIND)                                               \
  template <typename T>                                                  \
  struct KIND : public std::KIND<T, gc_allocator<T> > {                  \
    KIND() : std::KIND<T, gc_allocator<T> >() {}                         \
    KIND(size_t n) : std::KIND<T, gc_allocator<T> >(n) {}                \
    KIND(size_t n, const T& t) : std::KIND<T, gc_allocator<T> >(n,t) {}  \
  }

GC_CONTAINER(list);
GC_CONTAINER(vector);
GC_CONTAINER(deque);

template <typename T, typename Container = deque<T> >
struct stack : public std::stack<T, Container> {
};

#undef GC_CONTAINER

#define GC_CONTAINER(KIND)                                                    \
  template <typename Key, typename T, typename Compare = std::less<Key> >     \
  struct KIND : public                                                        \
  std::KIND<Key,T,Compare,gc_allocator<std::pair<Key,T> > > {                 \
    KIND() : std::KIND<Key,T,Compare,gc_allocator<std::pair<Key,T> > > () {}  \
  }

GC_CONTAINER(map);
GC_CONTAINER(multimap);

#undef GC_CONTAINER

#ifndef NOHASH
#define EXT __gnu_cxx
#define GC_CONTAINER(KIND)                                                    \
  template <typename Key, typename T,                                         \
            typename Hash = EXT::hash<Key>,                                   \
            typename Eq = std::equal_to<Key> >                                \
  struct KIND : public                                                        \
  EXT::KIND<Key,T,Hash,Eq,gc_allocator<std::pair<Key, T> > > {                \
    KIND() : EXT::KIND<Key,T,Hash,Eq,gc_allocator<std::pair<Key, T> > > () {} \
  }

GC_CONTAINER(hash_map);
GC_CONTAINER(hash_multimap);

#undef GC_CONTAINER
#undef EXT
#endif

#ifdef USEGC
#define GC_STRING \
  std::basic_string<char,std::char_traits<char>,gc_allocator<char> >
struct string : public GC_STRING
{
  string () {}
  string (const char* str) : GC_STRING(str) {}
  string (const std::string& str) : GC_STRING(str.c_str(),str.size()) {}
  string (const GC_STRING& str) : GC_STRING(str) {}
  operator std::string () const { return std::string(c_str(),size()); }
};
#undef GC_STRING
#else
using std::string;
#endif // USEGC


} // namespace mem

#endif 
