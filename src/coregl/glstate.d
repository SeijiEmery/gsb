
module gsb.coregl.glstate;
import gsb.coregl.glerrors;

public __gshared GLState glState;
struct GLState {
    private bool depthTestEnabled = false;
    private GLenum depthTestFunc  = GL_LESS;
    private bool transparencyEnabled = false;
    private GLuint lastBoundBuffer = 0;
    private GLuint lastBoundShader = 0;
    private GLuint lastBoundVao = 0;
    private GLuint lastBoundTexture = 0;
    private uint lastActiveTexture = 0;

    void enableDepthTest (bool enabled, GLenum depthTest = GL_LESS) {
        if (depthTestEnabled != enabled || depthTestFunc != depthTest) {
            if ((depthTestEnabled = enabled) == true) {
                depthTestFunc = depthTest;
                //log.write("Enabling glDepthTest (GL_LESS)");
                glchecked!glEnable(GL_DEPTH_TEST);
                glchecked!glDepthFunc(depthTest);
            } else {
                //log.write("Disabling glDepthTest");
                glchecked!glDisable(GL_DEPTH_TEST);
            }
        }
    }
    void enableTransparency (bool enabled) {
        if (transparencyEnabled != enabled) {
            if ((transparencyEnabled = enabled) == true) {
                //log.write("Enabling alpha transparency blending");
                glchecked!glEnable(GL_BLEND);
                glchecked!glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
            } else {
                //log.write("Disabling alpha transparency");
                glchecked!glDisable(GL_BLEND);
            }
        }
    }

    void bindShader (GLuint shader) {
        //log.write("glState: binding shader %s", shader);
        if (shader != lastBoundShader) {
            glchecked!glUseProgram(shader);
            lastBoundShader = shader;
        }
    }
    void bindVao (GLuint vao) {
        //log.write("glState: binding vao %s", vao);
        if (vao != lastBoundVao) {
            glchecked!glBindVertexArray(vao);
            lastBoundVao = vao;
        }
    }
    void bindBuffer (GLenum type, GLuint vbo) {

        //log.write("glState: binding vbo %s", vbo);
        if (vbo != lastBoundBuffer) {
            glchecked!glBindBuffer(type, vbo);
            lastBoundBuffer = vbo;
        }
    }
    void bindTexture (GLenum type, GLuint texture) {
        //log.write("glState: binding texture %s", texture);
        if (texture != lastBoundTexture) {
            glchecked!glBindTexture(type, texture);
            lastBoundTexture = texture;
        }
    }
    void activeTexture (uint textureUnit) {
        //log.write("glState: activating texture %d", textureUnit - GL_TEXTURE0);
        if (textureUnit != lastActiveTexture)
            glchecked!glActiveTexture(lastActiveTexture = textureUnit);
    }
}


