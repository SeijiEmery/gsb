import sb.model_loaders.tk_objfile;
import std.stdio;
import std.typecons;
import std.string;

string fmtBytes (double bytes) {
    if (bytes < 1e3) return format("%s bytes", bytes);
    if (bytes < 1e6) return format("%s kb", bytes * 1e-3);
    if (bytes < 1e9) return format("%s mb", bytes * 1e-6);
    return format("%s gb", bytes * 1e-9);
}

void main (string[]) {
    import std.path;
    import std.file;
    import std.datetime;
    import std.conv;

    void testObjLoad () {
        import std.file;
        import std.zip;

        Tuple!(string, double, TickDuration, TickDuration)[] loadTimes;
        string readFile (string path) {
            if (path.endsWith(".zip")) {
                auto archive = new ZipArchive(read(path));
                auto file = path[0..$-4].baseName;
                assert(file.endsWith(".obj"), file);
                assert(file in archive.directory, file);
                return cast(string)archive.expand(archive.directory[file]);
            }
            return readText(path);
        }
        void testObj (string path) {
            if (!path.exists)
                writefln("Could not open '%s'!", path);
            else {
                auto fileName = path.baseName;

                StopWatch sw; sw.start();
                auto contents = readFile(path);
                auto fileReadTime = sw.peek;

                writefln("Loading %s", fileName);
                tkParseObj(contents,
                    (const(char)* mtl, size_t num_tris) {},
                    (TK_Triangle) {},
                    (ref TK_ObjDelegate) {},
                    (ref TK_ObjDelegate, string err) {
                        writefln("Error while parsing '%s': %s", fileName, err);
                    });
                auto objLoadTime = sw.peek - fileReadTime;

                loadTimes ~= tuple(path.baseName, cast(double)contents.length, fileReadTime, objLoadTime);
            }
        }
        StopWatch sw; sw.start();
        testObj("/Users/semery/misc-projects/GLSandbox/assets/cube/cube.obj");
        testObj("/Users/semery/misc-projects/GLSandbox/assets/teapot/teapot.obj");
        testObj("/Users/semery/misc-projects/GLSandbox/assets/dragon/dragon.obj");
        testObj("/Users/semery/misc-projects/GLSandbox/assets/dragon/dragon.obj.zip");

        writefln("Loaded %s models in %s:", loadTimes.length, sw.peek.msecs * 1e-3);
        foreach (kv; loadTimes) {
            writefln("'%s' %s | read %s ms | load %s ms | %s / sec", 
                kv[0], kv[1].fmtBytes, kv[2].msecs, kv[3].msecs, (kv[1] / (kv[3].msecs * 1e-3)).fmtBytes);
        }
    }

    testObjLoad();
}



