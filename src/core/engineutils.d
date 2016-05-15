
module gsb.core.engineutils;
import gsb.utils.signals;

private struct ThreadLocalSignals {
    Signal!() onFrameBegin;
}
ThreadLocalSignals gsb_threadLocalSignals;

@property auto gsb_onFrameBegin () {
    return gsb_threadLocalSignals.onFrameBegin;
}







