all: libs/libstb.a

libs/libstb.a: build/stb.o
	ar rcs $@ $^

build/stb.o: stb/stb.c
	gcc -Wall -O2 -c -o $@ $<

clean:
	rm -f build/*.o libs/*.a

