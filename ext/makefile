all: libs/libstb.a

libs/libstb.a: build/stb.o
	mkdir -p libs
	ar rcs $@ $^

build/stb.o: stb/stb.c
	mkdir -p build
	gcc -Wall -O2 -c -o $@ $<

clean:
	rm -f build/*.o libs/*.a

