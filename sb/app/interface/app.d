module sb.app.app;
public import sb.gl.context: GLVersion;

IApplication sbCreateApp (SbAppConfig);
interface IApplication {
    void run ();
}
struct SbAppConfig {
    uint numWorkerThreads = 4;
    GLVersion glVersion   = GLVersion.GL_410;
    string appdataDir, projectDir;
}
SbAppConfig sbCreateAppConfig (string[] args) {
    version (OSX)
        string appdataDir = "~/Library/Application Support/gsb/";
    else
        string appdataDir = "~/.config/gsb/";

    string projectDir = args[0] ~ "/../";
    SbAppConfig config = {
        .appdataDir = appdataDir,
        .projectDir = projectDir,
    };
    return config;
}
