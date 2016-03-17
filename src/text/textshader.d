
module gsb.text.textshader;
import gsb.gl.state;
import gsb.core.window;
import gsb.glutils;
import derelict.opengl3.gl3;
import dglsl;

import gl3n.linalg;




class TextVertexShader: Shader!Vertex {
    @layout(location=0)
    @input vec3 inPos;

    @layout(location=1)
    @input vec2 inCoords;

    @layout(location=2)
    @input vec4 inColor;

    @output vec2 texCoord;
    @output vec4 shadingColor;

    @uniform mat4 transform;
    @uniform vec3 backgroundColor;

    void main () {
        gl_Position = transform * vec4(inPos, 1.0);
        texCoord = inCoords;
        shadingColor = inColor;
    }
}
class TextFragmentShader: Shader!Fragment {
    @input vec2 texCoord;
    @input vec4 shadingColor;
    @output vec4 fragColor;

    @uniform sampler2D textureSampler;
    @uniform vec3 backgroundColor;

    void main () {
        vec4 color = texture(textureSampler, texCoord);
        //fragColor = vec4(color.r) * shadingColor;
        // have to do this component-wise, b/c the fuckwad who wrote gl3n
        // DIDN'T IMPLEMENT COMPONENTWISE VECTOR MULTIPLICATION. Seriously, WTF.
        // (and if this library doesn't even use sse... -_-)

        //fragColor = vec4(color.r, 0, 0, shadingColor.a);

        fragColor.r = shadingColor.r;
        fragColor.g = shadingColor.g;    
        fragColor.b = shadingColor.b;
        fragColor.a = color.r * shadingColor.a;

        //fragColor.a = 1.0;//shadingColor.a;    
        //fragColor.a = color.r;// 1.0 - (1.0 - color.r) * shadingColor.a;//(1.0 - color.r) * (1.0 - shadingColor.a);
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

        glState.enableDepthTest(true);
        glState.enableTransparency(true);
        glState.bindShader(prog.id);
        prog.textureSampler = 0; CHECK_CALL("set textShader texture sampler");
    }

    void bind () {
        if (prog is null)
            lazyInit();
        glState.bindShader(prog.id);
    }

    @property void transform (mat4 transformMatrix) {
        glState.bindShader(prog.id);
        prog.transform = transformMatrix; CHECK_CALL("set textShader transform");
    }
    @property void backgroundColor (vec3 backgroundColor) {
        glState.bindShader(prog.id);
        prog.backgroundColor = backgroundColor; CHECK_CALL("set backgroundColor");
    }
}








