obj_files = buf.obj getopt.obj hash.obj list.obj option.obj strtod.obj strtol.obj sys.obj
o_files = buf.o getopt.o hash.o list.o option.o strtod.o strtol.o sys.o

.c.obj
	wcc386 -bt=nt -i="$(%WATCOM)/h" -i="$(%WATCOM)/h/nt" -i="../../src/lib/include" -i="../../../include" -i="../../src/lib/lst" -fo=$*.obj $<
.c.o
		wcc386 -bt=linux -d_LINUX -i="$(%WATCOM)/h" -i="$(%WATCOM)/h/nt" -i="../../src/lib/include" -i="../../../include" -i="../../src/lib/lst" -fo=$*.o $<

sprite.lib: $(obj_files)
  wlib $@ +buf.obj +getopt.obj +hash.obj +list.obj +option.obj +strtod.obj +strtol.obj +sys.obj

libsprite.a: $(o_files)
	wlib $@ +buf.o +getopt.o +hash.o +list.o +option.o +strtod.o +strtol.o +sys.o

all: sprite.lib libsprite.a
	
