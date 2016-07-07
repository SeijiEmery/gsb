module sb.threading.thread_enums;

enum SbThreadId : uint {
    NONE = 0,
    MAIN_THREAD = 1, GRAPHICS_THREAD = 2, AUDIO_THREAD = 3,
    WORK_THREAD_0 = 4, WORK_THREAD_1, WORK_THREAD_2, WORK_THREAD_3, 
    WORK_THREAD_4,     WORK_THREAD_5, WORK_THREAD_6, WORK_THREAD_7 
}
SbThreadMask toMask (SbThreadId threadId) {
    return cast(SbThreadMask)(1 << (threadId - 1));
}
enum SbThreadMask : uint {
    MAIN_THREAD     = 1 << (SbThreadId.MAIN_THREAD - 1),
    GRAPHICS_THREAD = 1 << (SbThreadId.GRAPHICS_THREAD - 1),
    AUDIO_THREAD    = 1 << (SbThreadId.AUDIO_THREAD - 1),
    WORK_THREAD_0   = 1 << (SbThreadId.WORK_THREAD_0 - 1),
    WORK_THREAD_1   = 1 << (SbThreadId.WORK_THREAD_1 - 1),
    WORK_THREAD_2   = 1 << (SbThreadId.WORK_THREAD_2 - 1),
    WORK_THREAD_3   = 1 << (SbThreadId.WORK_THREAD_3 - 1),
    WORK_THREAD_4   = 1 << (SbThreadId.WORK_THREAD_4 - 1),
    WORK_THREAD_5   = 1 << (SbThreadId.WORK_THREAD_5 - 1),
    WORK_THREAD_6   = 1 << (SbThreadId.WORK_THREAD_6 - 1),
    WORK_THREAD_7   = 1 << (SbThreadId.WORK_THREAD_7 - 1),
    ANY_WORK_THREAD = ~(MAIN_THREAD | GRAPHICS_THREAD | AUDIO_THREAD),
}
enum SbThreadStatus : uint { NOT_RUNNING, INITIALIZING, RUNNING, EXIT_OK, EXIT_ERROR }

unittest {
    assert(SbThreadId.NONE != SbThreadId.MAIN_THREAD);
    assert(SbThreadId.MAIN_THREAD != SbThreadId.GRAPHICS_THREAD);
    assert(SbThreadId.MAIN_THREAD != SbThreadId.AUDIO_THREAD);
    assert(SbThreadId.MAIN_THREAD != SbThreadId.WORK_THREAD_0);
    assert(SbThreadId.AUDIO_THREAD != SbThreadId.WORK_THREAD_0);

    assert(SbThreadMask.MAIN_THREAD     == SbThreadId.MAIN_THREAD.toMask);
    assert(SbThreadMask.GRAPHICS_THREAD == SbThreadId.GRAPHICS_THREAD.toMask);
    assert(SbThreadMask.AUDIO_THREAD    == SbThreadId.AUDIO_THREAD.toMask);
    assert(SbThreadMask.WORK_THREAD_0   == SbThreadId.WORK_THREAD_0.toMask);

    assert((SbThreadMask.ANY_WORK_THREAD & SbThreadId.NONE)            == 0);
    assert((SbThreadMask.ANY_WORK_THREAD & SbThreadId.MAIN_THREAD)     == 0);
    assert((SbThreadMask.ANY_WORK_THREAD & SbThreadId.GRAPHICS_THREAD) == 0);
    assert((SbThreadMask.ANY_WORK_THREAD & SbThreadId.AUDIO_THREAD)    == 0);

    assert((SbThreadMask.ANY_WORK_THREAD & SbThreadId.WORK_THREAD_0) != 0);
    assert((SbThreadMask.ANY_WORK_THREAD & SbThreadId.WORK_THREAD_7) != 0);
}
