all: libs/libstb.a libs/libtk_objfile.a libs/libstb_image.a

libs/libstb.a: build/stb.o
	mkdir -p libs
	ar rcs $@ $^

build/stb.o: stb/stb.c
	mkdir -p build
	gcc -Wall -O2 -c -o $@ $<

libs/libtk_objfile.a: build/tk_objfile.o
	mkdir -p libs
	ar rcs $@ $^

build/tk_objfile.o: tk_objfile/tk_objfile.c tk_objfile/tk_objfile.h
	mkdir -p build
	gcc -Wall -O2 -c -o $@ $<

libs/libstb_image.a: build/stb_image.o
	mkdir -p libs
	ar rcs $@ $^

build/stb_image.o: stb/stb_image.c stb/stb_image.h
	mkdir -p build
	gcc -Wall -O2 -c -o $@ $<

clean:
	rm -f build/*.o libs/*.a

