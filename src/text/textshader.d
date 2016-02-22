
module gsb.text.textshader;

import gsb.core.window;
import gsb.glutils;
import derelict.opengl3.gl3;
import dglsl;

class TextVertexShader: Shader!Vertex {
    @layout(location=0)
    @input vec3 textPosition;

    @layout(location=1)
    @input vec2 bitmapCoords;

    @output vec2 texCoord;

    @uniform mat4 transform;
    @uniform vec3 backgroundColor;

    void main () {
        gl_Position = transform * vec4(textPosition, 1.0);
        texCoord = bitmapCoords;
    }
}
class TextFragmentShader: Shader!Fragment {
    @input vec2 texCoord;
    @output vec4 fragColor;

    @uniform sampler2D textureSampler;
    @uniform vec3 backgroundColor;

    void main () {
        vec4 color = texture(textureSampler, texCoord);
        fragColor = vec4(color.r);
        //fragColor = color.r > 0.02 ?
        //    vec4(color.r) :
        //    vec4(backgroundColor + vec3(texCoord, 0.0), 1.0) * 0.5;
    }
}

class TextShader {
    static TextShader instance;    // threadlocal

    TextFragmentShader fs = null;
    TextVertexShader vs = null;
    Program!(TextVertexShader, TextFragmentShader) prog = null;

    void lazyInit ()
    in { assert(prog is null); }
    body {
        fs = new TextFragmentShader(); fs.compile(); CHECK_CALL("compiling text fragment shader");
        vs = new TextVertexShader();   vs.compile(); CHECK_CALL("compiling text vertex shader");
        prog = makeProgram(vs, fs); CHECK_CALL("compiling/linking text shader program");

        checked_glUseProgram(prog.id);
        prog.textureSampler = 0; CHECK_CALL("set textShader texture sampler");
        checked_glUseProgram(0);
    }

    void bind () {
        if (prog is null)
            lazyInit();
        checked_glUseProgram(prog.id);
    }

    @property void transform (mat4 transformMatrix) {
        checked_glUseProgram(prog.id);
        prog.transform = transformMatrix; CHECK_CALL("set textShader transform");
    }
    @property void backgroundColor (vec3 backgroundColor) {
        checked_glUseProgram(prog.id);
        prog.backgroundColor = backgroundColor; CHECK_CALL("set backgroundColor");
    }
}








