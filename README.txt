
This is my pretty crappy + horribly incomplete attempt to write a game engine / framework thing from scratch in D.

Background: this started as a rewrite of a project called GLSandbox, which was my attempt to
build a minimalistic graphics / game engine I could use to experiment with rendering techniques
and AI. Obviously, I ended up getting massively side-tracked and stuck on implemenation details 
-- plus endless rewrites -- so the result is not terribly interesting on a graphical or technical
level, and there are no cool AI / crowd / flocking demos as I had originally intended (though one
demo/game does have simple flocking in it...)

--

There's pretty much only a few things going for it as is:
– Pretty much everything was built from scratch on top of glfw3, opengl4.1, stb, and the D standard 
library. The results are kinda shitty, b/c this was built by one dev over a few months, and countless
rewrites, but it was interesting to figure out to to implement eg. a gui system from scratch (including
text rendering + layout, gui layouting frames + event handling, etc).
– Proves that D can be used for game development (PRO: much nicer than c++ / java, CON: no major
game libraries, and effectively incompatible w/ most major c++ libraries, like glm, boost, etc)
– Uses multithreaded opengl rendering
– Has better gamepad and multiresolution support than most game engines (eg. unity 5) :P

--

Naming: "gsb" = GlSandBox. "sb" = sandbox (an internal revision where I rewrote almost everything;
both code paths are still active b/c "sb" never got to feature parity w/ "gsb" and I didn't want
to throw away my original demo). sb was also supposed to abstract the graphics layer so I could
hotswap between opengl, metal, and vulkan at runtime, but that never got implemented (and was sorta
a stupid and impractical idea to begin with).

Origin: as mentioned before, this is a reimplementation of https://github.com/SeijiEmery/glsandbox.

Switched to D b/c:
– Compile times are _significantly_ faster than c++ (on par w/ java / dynamic languages)
– Has a modern build system (c++ build systems are STILL a complete clusterf***)
– Language is pretty similar to c++ (and python, and java, and c, and haskell).
– much higher-level than c++ / java (lots of metaprogramming, etc)
– Development is nearly as fast as python; code is just as terse, but is statically typed. Python
doesn't scale to large projects w/ out tons of unit tests; D does (and has unittests builtin)
– is binary compatible w/ C
– standard library is written by alexandrescu (the c++ template metaprogramming guy)
– could take code minimalism + DRY to its logical extreme 

On DRY: this was one of my overriding design principles on this project (I hate large, inefficient
codebases; D was a great langauge for this b/c you can _completely_ eliminate boilerplate + abstract repeated control flow structures via metaprogramming + fp).

Was I successful?
    gsb = 9k loc + 2k comments (65 files)
    sb  = 6k loc + 2k comments (60 files)
    http://imgur.com/vHHA1Fd
(note: these both include files w/ dead code + unfinished features)
    

Regretted switching to D b/c:
– is NOT c++ in a hundred irritating little ways
– 2 different object systems: GC-ed java-style classes, or C / C++ style structs with RAII.
The former don't have RAII; the latter are a complete PITA to use compared to c++ classes.
– D is _binary_ compatible w/ C, but can't parse C header files. This makes linking to existing
C libraries a complete PITA, and makes it effectively impossible to integrate w/ existing c++ 
projects, unless they have minimalistic C bindings or something.
– c++ lambdas > d delegates (delegates are much more flexible, but less performant; no RAII
by default makes capturing semantics _really_ difficult in some cases)
– D is competing w/ c++ + boost. Modern c++ + libraries, frameworks, etc >>> D (unfortunately).

Things that turned out sorta ok...?
– GC in a realtime game engine is fine. Admittedly, there wasn't much I was doing that really
pushed limits, but I suspect that 98% of the performance problems linked to GCs is due to OO.
– Which is a wierd statement to make, but yes, you can avoid 95% of memory allocations + 
deallocations by adopting data-oriented techniques (ie. variants, fixed-size objects, and
recycled arrays) -- if you don't constantly allocate + throw away memory, you won't hit GC.
– Though the benefit of c++, obviously, is you can use full OOP, then optimize everything
under the hood to recycle memory + fit in caches; you can't do that with GC-based languages
(C#, Java, D).

--

So is this cross-platform?

Yes and no. Yes, in the sense that it's built on cross-platform libraries (mostly GLFW3 + opengl4.1),
and D itself is completely cross-platform and comes with a package manager that prevents most problems.

No, in the sense that I built this project almost entirely on a mac (Yosemite / El Capitan), and
while designed to be as cross-platform as possible, it's only been minimally tested on linux, and 
wasn't interested in building on windows (not posix, etc).

With that said, if you did want to port / run this on windows, theoretically you'd only need to do 2 things:
– a) rewrite the makefile in ext/ or build the (very simple) libraries there manually. libstb.a, 
libtk_objfile.a, and libstb_image.a are just minimalistic ghetto-bindings to some open-source c
libraries (remember D has binary compatiblity), and are pretty easy to build by hand – but these do 
exist outside the normal D build system and will cause wierd build errors if not created first
– b) add windows fonts (and a few other things...?). gsb uses system fonts, specifically 2 of them 
(monospaced "menlo" and default / unicode "arial"). These are *hardcoded*, but very easy to add: just
edit the 2 windows-specific lines ("version(Windows){") in the method "registerDefaultFonts" in 
gsb/src/core/text/font.d
– And, uh, fix all/any compile errors b/c it hasn't been tested... 
– And there might be some wierd path stuff too; I don't think I'm using *that* much POSIX-specific stuff...

GAMEPADS

While we're on the subject, gsb has a really nice gamepad setup, and supports the DS4 + Xbox360 
gamepads out of the box. This is fully extensible; if you want to add more gamepads (or see how to
implement gamepads properly in glfw, see gsb/src/core/input/gamepad.d)

--

Features:
– Text rendering (and really crappy gui system), both implemented pretty much from scratch (for 
better or worse). Text system is extremely buggy since I broke things w/ a render desync a while ago,
and does seriously need to be replaced at this point, b/c the impl is pretty horrible
(um... see the updateFramgents() method in gsb/src/core/text/textrenderer.d. Yeah...)
– Text rendering is however dynamic (not pre-baked; can draw any renderable unicode character at
runtime), and has full unicode support (thanks to the D stdlib + stbtt). Renders bitmaps only at
this point, but I had planned on adding SDF at some point...
– Resolution-independent text + GUI (in gsb; text / gui hasn't been ported to / rewritten in sb yet)
– Smooth, arbitrary-width line rendering w/out using AA (draws lines as gradients using an 
over-complicated method involving a custom shader and lots of CPU-bounds stuff. Can still render
(full CPU rebuild) 10k lines in ~3 ms).
– Multithreaded OpenGL rendering, ...sort of. Old impl is awful and extremely buggy, but all GL calls
are run on a completely differnet thread (and can theoretically support arbitrary numbers of worker 
threads for CPU-bound work).
– Newer impl is a multithreaded task-queue that would be combined with a command-buffer GL layer, but 
is somewhat unfinished (and is complete overkill for what I'm using it for now anyways).
– Really nice gamepad support + input handling support. Much better than Unity anyway; don't really 
want to compare it with unreal 4...
– About 3 different opengl wrappper implementations in the same project (wait that's not a good feature...)
– Bunch of eclectic half-finished things that could be useful somewhere...

--

BUILD INSTRUCTIONS:
– Install the D runtime and its package system (dub).
– If you're on OSX / Linux, run the following (if you're on linux, pray):
    
    cd <some temp directory>
    git clone https://github.com/SeijiEmery/gsb
    cd gsb
    
    unzip assets.zip              (unzip asset pack)
    cd ext; make; cd ..           (build external C libs)

To run the sample programs:
    
    dub run :flycam-test        (displays a field of triangles to test flycam controls + camera)
    dub run :modelviewer-test   (loads some obj files in a scene + displays w/ simple lighting)
    dub run :tq-test            (taskqueue / threading test)
    dub run :gsb                (demo for old codepath -- see below)


Controls -- flycam-test / modelviewer-test:
    WASD / LS:                          move x/y
    Right click + mouse / RS:           look
    Shift / LB:                         move down
    Space / RB:                         move up
    Scrollwheel / Triggers:             zoom fov in/out (trippy visuals in flycam-test)
    press LS / RS:                      recenter / reorient camera (jump to origin / clear angles)

modelviewer-test:
    Number Keys (top row):              set lighting model
    Gamepad "B":                        toggle light model

    Keyboard "R" / Gamepad "A":         set directional light @ current position w/ current facing
    Keyboard "T" / Gamepad "X":         set directional light @ current position
    Gamepad Dpad Up/Down:               increase / decrease light intensity
    Gamepad Dpad Left/Right:            increase / decrease material shininess

    Gamepad "Y":                        toggle rotating triangle grid (the thing drawn in flycam-test)


Controls + UI, gsb:
    – The ugly rectangley things are UI frames (drawn in debug mode). Generally:
        – Clicking + dragging at border will resize
        – Clicking + dragging inside will move

    – the thing saying "main-thread", "graphics-thread", etc., is the performance tracker / "stat-graph" module
        – pink text is 
            1) recent average run time (in ms), 
            2) recent maximum run time (in ms), 
            3) routine / procedure name (most of these are nested)
        – green line = graphics thread, red line = main thread
        – horizontal lines mark:
            – 40hz (orange)  (target: < 25 ms)
            – 60hz (yellow)  (target: < 16 ms)
            – 120hz (green)  (target: < 8  ms)

    – if you resize the window, there's a thing saying "x components" (number is wrong):
        – clicking disables / enables various modules (like the performance tracker)
        – and shows how incredibly f***ed up the text-rendering system has become as I've incrementally
        broken things... Ghosting / leftover text framents is a known bug that I haven't had time to fix
        – as are random crashes (if you get them). The threading backend got completely rewritten at
        one point, fwiw, and it created a bunch of new bugs via random subsystem desyncs in gsb...

    – color test: has 4 sliders, mapped to RGBA / HSVA. Can select RGB / HSV; HUSL is broken and was disabled.

    – widget test: can drag + resize content frame. Right click on the frame changes internal element
    alignment; shift + right click toggles between horizontal + vertical layout

    – collision test: interactive test for some _really_ basic collision detection algorithms used to implement
    game-test. Select test from the box at upper right, and mouseover, etc. For line-circle test, scroll wheel
    changes line width, right click toggles between free, clamp-x, and clamp-y lines (to test edge cases).

    – gamepad test: Shows gamepad info (if you have any plugged in), and values for all inputs. Used
    to test gamepad detection (connect / disconnect), and bindings. If you want to get a DS3 working, for
    example, duplicate the DS4 bindings and use this utility to determine what the proper button + axes
    mappings are.

    – game test: really basic 1-4-player game built out of what I had working at the time;
    was basically written over a weekend, so it's pretty simple.

    Gameplay:
        – You control a colored circle (matching "Player 1" / "Player 2" / etc), and you avoid red circles.
        – You move (and aim) with LS, and shoot colored lines with "square" (dualshock) / "X" (xbox)
        – You can jump / teleport a short distance with "X" (dualshock) / "A" (xbox)
        – There are two bars below your player name, representing health (big bar) and energy (small bar)
        – Teleporting + shooting requires energy (which replenishes automatically)
        – Health replenishes after not getting hit for a few seconds
        – Pressing "triangle" / "Y" spawns one red enemy; "circle" / "B" spawns a continuous stream.
        These enemies / red circles swarm towards players (inflicting damage on hit), and will randomly
        shoot at the players. They fire using motion prediction, which can be avoided using random movement.
        – If you die, the game displays a countdown (text rendering is currently bugged), and you respawn after ~5 seconds.
        – Goal is to murder all other players and not die.

    Time Scale:
        – Pressing left / right triggers slows down / speeds up game time, up to 0%-200%.
        – The lines you shoot out take a fraction of a second to flash + do damage (and are avoidable)
        – pressing left / right dpad slows down / speeds up the base game time, which is displayed at 
        the top of the screen.

    – It's unfinished, but surprisingly fun if you can find 4 people + gamepads -- or just spawn a bunch
    of enemies and try to survive. The core gameplay mechanic is the time element, which could be interesting
    in a more fleshed out top-down shooter.
    – It's been left as is b/c I wasn't sure how to advance the gameplay w/out removing the fun factor --
    and my 'engine' was too primitive to do much more anyways.
    – Note: this was basically inspired by "Just Shapes + Beats" at PAX 2015 (which surprisingly, still
    hasn't come out yet...)

--

Screenshots:
    flycam-test:      https://imgur.com/a/nLa02
    modelviewer-test: http://imgur.com/a/u7ByN
    gsb:              https://imgur.com/a/AV9lQ

--

Project structure, interesting files, etc:

– This project (unfortunately) has essentially 2 different code paths in it:
– The old codepath ("gsb" / glsandbox), and a new codepath ("sb" / sandbox), added as (yet another) rewrite
of gsb in the "sb-rewrite" branch. Unfortunately that branch / rewrite was never finished, or at least didn't
reach feature parity with gsb, so I'm left with a wierd situation where:
    – gsb demos the old font rendering, threading, and 2d rendering, but doesn't do 3d rendering
    – sb demos the new threading system (in part), and 3d rendering, but doesn't have a gui system...
– And unfortunatlely, they're sort of fundamentally incompatible as I rewrote the gl layer to build sb; If I had
time, I'd merge them (and finish sb), but unforutnately I don't, so here's the project structure as it currently
stands:

    ext/                    External C libraries to be built + linked w/ D interfaces

    GSB (old) core libraries:

    gsb/src/core/           (shared instances of stuff: logging system, window, events, etc)
    gsb/src/core/coregl     (old opengl implementation)
    gsb/src/core/gl         (DEAD)
    gsb/src/core/text       (old text rendering impl)
    gsb/src/core/ui         (old ui impl)
    gsb/src/core/task       (old task impl)
    gsb/src/core/input      (gamepad impl)

    gsb/src/engine          ("engine" impl: basically the stuff that constitutes the main application; includes threading, etc)

    gsb/src/utils           (shared stuff like color, HUSL support, a signals/slot implementation, etc)

    gsb/src/ext             (bindings to C libraries)

    GSB Components:
        Note on (original) GSB application structure:
        – Implemented as a _monolithic_ application that loads applet-like "components" / "modules" at runtime.
        Eventually these were supposed to be hotloadable (and I prototyped a file watcher for automatic hotloading
        in GLSandbox), but this proved to be difficult to implement and eventually the idea got scrapped.

        Note, however, that running "dub run :gsb" launches the application shell, and then loads _everything_ in
        src/components, and can load / unload modules using the module_manager component (which implements a simple
        menu to load / unload other components...).

        See the component/ source files to see how they work.

        Note that "component" does NOT mean component as in ECS; they were originally named "modules" in GLSandbox,
        but this conflicted w/ the D keyword "module" (and an actual module system). A better name would probably be
        "applet" or "plugin", since that's basically what they are (or in other words the original design was for a
        game engine where all gameplay and behavior is isolated into interacting plugins running on arbitrary threads...
        This turned out to be unrealistic and unecessary).

    src/component/module_manager.d:         (implements component to enable / disable other components)
    src/component/statgraph.d:              (implements performance monitor w/ graph of timing info on main/graphcs thread
                                             and specific engine sub-processes)
    src/component/collisiontest.d:          (visual tests for some simple hit detection algorithms)
    src/component/colortest.d:              (implements gui to test color system + HUSL implementation)
    src/component/widgettest.d:             (implements basic tests for gui system + layout options. 
                                                note: right clicking changes layout)
    src/component/shadowgun/gametest.d:     (simple game prototype built in a weekend using what I had at the time)
            Note: this is a simple shooter w/ an (I think) interesting time element: pressing triggers slows down time +
            wpn effects. Is playable as is w/ 2-4 player coop, but requires 2-4 gamepads (gui does not show up + just
            says "0 / 0 players" until you plug in gamepads).

--
    SB / New code:

    sb/gl/              (new GL implemenation! Sort of unfinished; full impl is in gl_41_lib_impl.d)
    sb/app/             (Core application infrastructure; analogous to gsb/core/engine/)
    sb/image_loaders/   (wraps stb_image; could include other loaders as / if needed)
    sb/model_loaders/   (.obj file loaders)
    sb/model_loaders/tk_objfile             (wraps tk_objfile -- note: inefficient / slow!)
    sb/model_loaders/loadobj/loadobj2.d     (handwritten .obj parser / loader written in d. much faster than tk_objfile...)
    sb/taskgraph/       (taskgraph impl + tests)
    sb/threading/       (threading impl; implements workers that run taskgraph)
                        (note: under sb arch once/if finished, app is just a collection of taskgraph nodes that connect to / create other nodes...)

    sb/platform/        (wraps glfw3; built so _in theory_ could have other "platform" backends (eg. native osx)).
                        (And note that ALL of sb was overengineered like this; in retrospect, this was pretty stupid / 
                        misguided, and reason I didn't finish sb on time...)

    sb/shared/          (lots of useful code shared between all other subsystems; loosely analogous to gsb/src/core)
    sb/shared/src/events/   (events + state; wraps glfw3)
    sb/shared/src/input/    (gamepad AND mouse / keyboard wrappers. Wraps glfw3.
                          Note: gampad.d has been split into gamepad.d (defns), gamepad_device.d (logic))
    sb/shared/src/keybindings/
    sb/shared/src/mesh/     (mesh defns + data structures)

    sb/gl_tests/        (implements gl / sb demos!)
    sb/gl_tests/window_test.d       (see for minimalistic window demo)
    sb/gl_tests/flycam_test.d       (see for minimalistic flycam app; run w/ "dub run :flycam-test"; needs gamepad (?))
    sb/gl_tests/model_viewer_test.d (see for full fledged (but crappy) 3d renderer + controls)


For sort-of-decent examples of GSB / SB code (at a glance), see the component / demo files:

    gsb/src/components/shadowgun/gametest.d    (be aware this was written over a few days!)
    gsb/src/components/colortest.d             (example of old, super-crappy gui + module system)
    gsb/src/components/gamepadtest.d           (example of old, super-crappy gui + module system)
    gsb/src/components/widgettest.d            (example of old, super-crappy gui + module system)

    sb/gl_tests/flycam_test.d           (equivalent to my original GLSandbox project in MUCH less code: < 200 lines)
    sb/gl_tests/model_viewer_test.d     (more complete + complex example. Not really the best way to do things, but eh...)

    sb/taskgraph/tests/task_queue_test.d    (taskqueue unittests. NOT really used in the above 2 demos, but infrastructure
                                            exists so that it could be...)
