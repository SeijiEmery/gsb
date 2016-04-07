
module gsb.coregl.sharedimpl;
import gsb.coregl.batch;
public import gsb.coregl.glerrors;
public import gsb.coregl.interfaces;

bool isGraphicsThread () {
    return false;
}

void gl_execImmediate (lazy void expr) {
    if (isGraphicsThread())
        expr();
    else
        GLCommandBuffer.instance.pushImmediate({ expr(); });
}
void gl_execNextFrame (lazy void expr) {
    if (isGraphicsThread())
        expr();
    else
        GLCommandBuffer.instance.pushNextFrame({ expr(); });
}





















