module sb.fs.fs_context;

IFileContext sbCreateFileContext ();

enum SbResourceType {
    ASSET_DIR,
    FRAGMENT_SHADER_SRC, VERTEX_SHADER_SRC, GEOM_SHADER_SRC,
    D_MODULE_SRC, D_MODULE_BUILD,
}

interface IFileContext {
    // Init + config
    void   setPathVar (string name, string value);
    string getPathVar (string name);

    void addResourcePath (SbResourceType, string path);
    void setResourceExt  (SbResourceType, string glob);

    // D API
    IFileAction loadFile (string path, 
        void delegate(string, ubyte[]) onLoaded,
        void delegate(string, SbFileException) onError);

    IFileAction loadFiles (string glob,
        bool delegate(string) filter,
        void delegate(string,ubyte[]) onLoaded,
        void delegate(string, SbFileException) onError);

    // misc api
    bool exists (string path);
    // ...

    // C++ API
    IFileAction loadFile  (const(char)* path, IFileLoadContext);
    IFileAction loadFiles (const(char)* glob, IFileLoadContext);
}

interface IFileLoadContext {
    bool filter   (const(char)* path, size_t pathLen);
    void onLoaded (const(char)* path, size_t pathLen, const(ubyte)* fileContents, size_t fileSize);
    void onError  (const(char)* path, size_t pathLen, const(char)* reason, size_t rlen);
}

enum FileLoadStatus : uint {
    WAITING = 0, LOADED, ERROR
}
interface IFileAction {
    FileLoadStatus status ();
    void reload (); // force reload
    void release (); // kill action (stop file reloading)
}













