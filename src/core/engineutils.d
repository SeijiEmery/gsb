
module gsb.core.engineutils;
import gsb.core.pseudosignals;

private struct ThreadLocalSignals {
    Signal!() onFrameBegin;
}
ThreadLocalSignals gsb_threadLocalSignals;

@property auto gsb_onFrameBegin () {
    return gsb_threadLocalSignals.onFrameBegin;
}







