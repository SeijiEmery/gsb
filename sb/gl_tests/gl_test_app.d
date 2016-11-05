import sb.threading;
import sb.platform;
import sb.gl;
import sb.fs;
import sb.log;
import sb.dyn_rt;

void main (string[] args) {
    auto threading = sbCreateThreadingInstance();
    auto events    = sbCreateEventInstance();
    auto log       = sbCreateLogger();
    auto moduleMgr = sbCreateModuleManagerInstance();

    SbPlatformConfig platformConfig = {
        .glVersion = SbPlatform_GlVersion.GL_410,
        .platform  = SbPlatform_Backend.GLFW3,
    };
    SbWindowConfig   windowConfig = {
        .fullscreen = false,
        .resizable  = true,
        .showFramerate = true,
        .size_x = 1260, .size_y = 700,
    };
    auto platform = sbCreatePlatform(platformConfig);

    SbFsConfig fsConfig = {
        .srcProjectDir = sbRelPath(args[0], ".."),
        .appdataDir    = "~/Library/Application Support/gsb/",

        .cachePath  = "${APPDATA_DIR}/cache",
        .d_buildDir = "${CACHE}/build/d/",
        .d_libDir   = "${CACHE}/lib/d/",
        .d_srcDirs  = [
            "${PROJECT_DIR}/src/gl_tests/modules"
        ],
        .scanInterval = dur!"ms"(100),
    };
    auto fs = sbCreateFs(fsConfig);

    try {
        platform.init();
        platform.preInitGl();

        auto window = platform.createWindow(windowConfig, "main-window");

        platform.bindEvents(window, events);

        auto mt = threading.createThreadWorker( SbThreadId.MAIN_THREAD );
        auto gt = threading.createThreadWorker( SbThreadId.GRAPHICS_THREAD );
        threading.setWorkerCount(0);

        auto app = sbCreateAppHandle(
            platform, threading, events, moduleMgr, fs, log
        );
        app.bindMainWindow(window);

        gt.onInit({
            platform.initGl();
        });
        gt.onNextFrame({
            // swap buffers + reset internal gl state (including clear color, etc)
            platform.swapBuffers();
        });
        gt.blockEvent_nextFrame(true);
        gt.launchThread();

        mt.onInit({
            gt.blockEvent_nextFrame(false);
        });
        mt.onNextFrame({
            moduleMgr.onEndFrame();
            events.poll();
        });
        
        fs.scheduleWork( threading );
        events.scheduleMiscWork( threading );
        events.setGamepadPollInterval( dur!"seconds"(1) );   // rate at which does full scan for new joysticks, etc
        moduleMgr.bindApp( app, fs, threading );

        // Load module(s)
        auto test = rtm.loadModule("gl_test_01.d");
        test.setActive(true);

        // Enter main thread, staring application
        mt.enterThread();

        threading.shutdownAllThreads();
        moduleMgr.shutdownModules();

    } catch (Throwable err) {
        log.write_critical(err.to!string);
        threading.shutdownAllThreads();
        moduleMgr.shutdownModules();

        import core.stdc.stdlib: exit;
        exit(-1);
    }
}

































