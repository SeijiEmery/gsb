module sb.gl.shader;
import gl3n.linalg;

interface IShader {
    // Load shader contents
    IShader source    (ShaderType, string path);
    IShader rawSource (ShaderType, string contents);

    // Set shader vars (call this only on the graphics thread!)
    IShader setv (string name, float value);
    IShader setv (string name, int   value);
    IShader setv (string name, uint  value);
    IShader setv (string name, vec2  value);
    IShader setv (string name, vec3  value);
    IShader setv (string name, vec4  value);
    IShader setv (string name, mat3  value);
    IShader setv (string name, mat4  value);

    // Set shader subroutine uniforms (call only on graphics thread!)
    IShader useSubroutine (ShaderType type, string name, string value);

    // Release / retain
    void release ();
    void retain  ();
}
enum ShaderType {
    FRAGMENT, VERTEX, GEOMETRY
}



