module rev3.core.opengl;
public import rev3.core.math;
public import derelict.opengl.gl3;
public import format: format;

class GLRuntimeException : Exception {
    this (string message, string context, string file = __FILE__, ulong line = __LINE__, string fcn = __PRETTY_FUNCTION__) {
        super(format("%s while calling %s in %s", message, context, fcn), file, line);
    }
}

final class GLContext {
    // Nicely wraps all GL operations with error checking code, etc.
    // We can further "override" by defining functions like "bind" (called as "gl.bind(...)"), etc. 
    public auto opDispatch (string fcn, Args...)(Args args, string caller_file = __FILE__, ulong caller_line = __LINE__, string caller_fcn = __PRETTY_FUNCTION__) 
        if (__traits__(compiles, mixin("gl"~fcn~"(args)"))
    {
        // Call function / execute operation. If call returns a result, save it.
        static if (!is(typeof(F(args)) == void))    auto result = mixin("gl"~fcn~"(args)");
        else                                        mixin("gl"~fcn~"(args)");

        // If value in enum to track call #s, update that call value
        static if (__traits__(compiles, mixin("GLTracedCalls."~fcn))) {
            mixin("callTraceCount[GLTracedCalls."~fcn~"]++");
        }

        // Check for errors.
        checkError(fcn, caller_file, caller_line, caller_fcn);

        // Return result (if any).
        static if (!is(typeof(F(args)) == void))    return result;
    }

    // Internal call used to check errors after making GL calls.
    public void checkError (string fcn, string caller_file = __FILE__, ulong caller_line = __LINE__, string caller_fcn = __PRETTY_FUNCTION__) {
        static if (GL_RUNTIME_ERROR_CHECKING_ENABLED) {
            auto err = glGetError();
            if (err != GL_NO_ERROR) {
                throw new GLRuntimeException(glGetMessage(err), F.stringof, args.joinArgs(), externalFunc, file, line);
            }
        }
    }

    // Flushes / Ignores all errors
    public void flushErrors () {
        while (glGetError()) {}
    }

    // Records GL Call count for specified calls (defined in GLTracedCalls)
    private int[GLTracedCalls] callTraceCount;
    public auto ref getCallCounts () { return callTraceCount; }
    public void   resetCallCounts () { callTraceCount[0..$] = 0; }


    //
    // Resource management
    //

    private import rev3.core.resource;
    private ResourceManager!(GLResource, GLResourceType) resourceManager;
    public auto create (T, Args...)(Args args) {
        return resourceManager.create!T(this, args);
    }
    public void gcResources () {
        resourceManager.gcResources();
    }
    public auto ref getActiveResources () {
        return resourceManager.getActive();
    }
}

// Traced calls...
enum GLTracedCalls {
    
};

//public auto GLCall (alias F, string file = __FILE__, ulong line = __LINE__, string externalFunc = __PRETTY_FUNCTION__, Args...)(Args args)
//    if (__traits__(compiles, F(args)))
//{
//    static if (!is(typeof(F(args)) == void))    auto result = F(args);
//    else                                        F(args);

//    static if (GL_RUNTIME_ERROR_CHECKING_ENABLED) {
//        auto err = glGetError();
//        if (err != GL_NO_ERROR) {
//            throw new GLRuntimeException(glGetMessage(err), F.stringof, args.joinArgs(), externalFunc, file, line);
//        }
//    }
//    static if (!is(typeof(F(args)) == void))    return result;
//}

//
// Resources...
//

// Base resource class

private class GLResource : ManagedResource {
    protected GLContext context;
    protected this (GLContext context) { this.context = context; assert(context != null); }
}
enum GLResourceType {
    GLShader, GLTexture, GLBuffer, GLVertexArray
}
public class GLShader : GLResource {
    this (GLContext context) { super(context); }
    void resourceDtor () {

    }
}
public class GLTexture : GLResource {
    this (GLContext context) { super(context); }
    void resourceDtor () {

    }
}
public class GLBuffer : GLResource {
    this (GLContext context) { super(context); }
    void resourceDtor () {

    }
}
public class GLVertexArray : GLResource {
    this (GLContext context) { super(context); }
    void resourceDtor () {

    }
}











