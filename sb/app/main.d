import sb.app;

void main (string[] args) {
    auto config = sbLoadAppConfig(args);
    config.glVersion = GLVersion.GL_410;

    sbCreateApp(config).run();
}
