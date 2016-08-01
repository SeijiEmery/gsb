module sb.model_loaders.tk_objfile;
import std.format;
import std.array: join;
import std.string;

extern (C) struct TK_TriangleVert {
    float[3] pos;
    float[2] st;
    float[3] nrm;
}
extern(C) struct TK_Triangle {
    TK_TriangleVert vertA, vertB, vertC;
}
extern(C) struct TK_ObjDelegate {
    void function(size_t, const(char)*, void*) error;
    void function(const(char)*, size_t, void*) material;
    void function(TK_TriangleVert, TK_TriangleVert, TK_TriangleVert, void*) triangle;
    void* scratchMem = null;
    size_t scratchMemSize;

    void* userData;
    size_t currentLineNumber;
    size_t numVerts;
    size_t numNorms;
    size_t numSts;
    size_t numFaces;
    size_t numTriangles;
}

extern(C) void TK_ParseObj (void* objFileData, size_t objFileSize, TK_ObjDelegate* objDelegate);

private struct ParseContext {
    void delegate( const(char)* mtlName, size_t numTriangles ) onMaterial;
    void delegate( TK_Triangle ) onTriangle;
    string[] errors;
    bool     needsMoreMem = false;
}

private extern(C) void errorCallback ( size_t lineNumber, const(char)* message, void* userData ) {
    auto context = cast(ParseContext*)userData;
    import std.stdio;
    writefln("'%s'", message.fromStringz);
    if (message.fromStringz == "Not enough scratch memory.")
        context.needsMoreMem = true;
    else
        context.errors ~= format("line %s: %s", lineNumber, message.fromStringz );
}
private extern(C) void materialCallback ( const(char)* mtlName, size_t numTriangles, void* userData ) {
    auto context = cast(ParseContext*)userData;
    context.onMaterial( mtlName, numTriangles );
}
private extern(C) void triangleCallback ( TK_TriangleVert a, TK_TriangleVert b, TK_TriangleVert c, void* userData ) {
    auto context = cast(ParseContext*)userData;
    context.onTriangle( TK_Triangle(a, b, c) );
}

void tkParseObj ( 
    string data, 
    typeof(ParseContext.onMaterial) onMaterial,
    typeof(ParseContext.onTriangle) onTriangle,
    void delegate(ref TK_ObjDelegate) onFinished,
    void delegate(ref TK_ObjDelegate, string) onError
) {
    auto parseContext = ParseContext( onMaterial, onTriangle );
    auto objDelegate  = TK_ObjDelegate(
        &errorCallback, &materialCallback, &triangleCallback,
        cast(void*)(new ubyte[100_000_000]), 100_000_000,
        //null, 0,
        &parseContext);

    TK_ParseObj( cast(void*)data.ptr, data.length, &objDelegate );
    //if (parseContext.needsMoreMem) {
        import std.stdio;
    //    writefln("Allocating more memory: %s => %s", 16_000_000, objDelegate.scratchMemSize);
    //    objDelegate.scratchMem = cast(void*)new ubyte[ objDelegate.scratchMemSize ];
    //    TK_ParseObj( cast(void*)data.ptr, data.length, &objDelegate );
    //}
    //writefln("Allocating memory: %s", objDelegate.scratchMemSize);
    //objDelegate.scratchMem = cast(void*)new ubyte[objDelegate.scratchMemSize];
    //TK_ParseObj( cast(void*)data.ptr, data.length, &objDelegate );

    if (!parseContext.errors.length)
        onFinished( objDelegate );
    else
        onError( objDelegate, format("%s error(s):\n\t%s\n%s:\t'%s'",
            parseContext.errors.length, 
            parseContext.errors.join("\n\t"), 
            objDelegate.currentLineNumber,
            data.splitLines[objDelegate.currentLineNumber]));
}
