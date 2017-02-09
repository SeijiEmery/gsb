module sb.gla.commandbuffer;
import sb.gla.resourcemanager;

class GLAResourceManager {
    GLAResource[] resources;
    uint[]        freeList;
    uint          nextId = 0;
    Mutex         mutex;

    this () { mutex = new Mutex(); }
    void gc () {
        synchronized (mutex) {
            foreach (i, ref resource; resources) {
                if (resource.type != GLAResourceType.None && resource.refCount < 0) {
                    freeList ~= i;
                    resource.deinit();
                    assert(resource.type == GLAResourceType.None);
                }
            }
        }
    }
    ~this () {
        synchronized (mutex) {
            foreach (ref resource; resources) {
                if (resource.type != GLAResourceType.None) {
                    resource.deinit();
                }
            }
        }
    }
    uint allocResource (GLAResourceType type) {
        synchronized (mutex) {
            if (freeList.length) {
                auto i = freeList[$-1];
                --freeList.length;
                resources[i].initAs(type);
                return i;
            } else {
                auto i = nextId++;
                if (i > resources.length)
                    resources.length += (i - resources.length);
                return i;
            }
        }
    }
};

private class GLACommandBuffer {
    GLACommand[] commandQueue;
    this (GLAResourceManager resourceManager) { this.resourceManager = resourceManager; }

    final void pushCommand (T)(T value) if (__traits(compiles, GLACommand(value))) {
        commandQueue ~= GLACommand(value);
    }
    final void execQueue (GLAContext context) {
        foreach (command; commandQueue) {
            command.visit!(
                (Cmd_ShaderDothing cmd) { cmd.exec(context); },
                (Cmd_DoOtherThing cmd)  { cmd.exec(context); },
            );
        }
        commandQueue.length = 0;
    }
}




