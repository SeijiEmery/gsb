module sb.threading.interface.thread_enums;

enum SbThreadId : uint {
    MAIN_THREAD = 0, GRAPHICS_THREAD = 1, AUDIO_THREAD = 2,
    WORK_THREAD_0 = 3, WORK_THREAD_1, WORK_THREAD_2, WORK_THREAD_3, 
    WORK_THREAD_4,     WORK_THREAD_5, WORK_THREAD_6, WORK_THREAD_7 
}
enum SbThreadMask : uint {
    MAIN_THREAD     = 1 << SbThreadId.MAIN_THREAD,
    GRAPHICS_THREAD = 1 << SbThreadId.GRAPHICS_THREAD,
    AUDIO_THREAD    = 1 << SbThreadId.AUDIO_THREAD,
    WORK_THREAD_0   = 1 << SbThreadId.WORK_THREAD_0,
    WORK_THREAD_1   = 1 << SbThreadId.WORK_THREAD_1,
    WORK_THREAD_2   = 1 << SbThreadId.WORK_THREAD_2,
    WORK_THREAD_3   = 1 << SbThreadId.WORK_THREAD_3,
    WORK_THREAD_4   = 1 << SbThreadId.WORK_THREAD_4,
    WORK_THREAD_5   = 1 << SbThreadId.WORK_THREAD_5,
    WORK_THREAD_6   = 1 << SbThreadId.WORK_THREAD_6,
    WORK_THREAD_7   = 1 << SbThreadId.WORK_THREAD_7,
    ANY_WORK_THREAD = ~(MAIN_THREAD | GRAPHICS_THREAD | AUDIO_THREAD),
}
enum SbThreadStatus : uint { NOT_RUNNING, INITIALIZING, RUNNING, EXIT_OK, EXIT_ERROR }
