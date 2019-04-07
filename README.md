# GSB (GLSandbox)

This is an old game engine / testbed that I wrote to teach myself graphics programming, and a bunch of systems programming stuff, like multithreading.

It's written in D, because my initial attempt at this ended up bogged down by slow compile times, and D turned out to be an excellent alternative (the standard library, in particular, is fantastic).

I'll probably need to write an article about this at some point, b/c D brought both some unique advantages (for the most part, it's a better-c++), and some disandvantages (D has some... quirks, and is -not- c++ in some very annoying and hard to fix ways).

It's built on glfw3, opengl4.1, and libstb for fonts / image loading / etc.

If I were doing this over again I'd have used nanovg instead of rolling my own text + graphics implementation, and I obviously would've used Assimp for asset importing. I probably should've integrated box2d and/or bullet (currently, there is no built in physics engine), and I probably should've either added lua support or finished my work on D hotloading (technically, you can use D as a hotloaded scripting language; it's just kinda hard...)

Obviously, GSB is missing a lot of features, and has some weird ones: I was deadset on making the engine multithreaded, for instance (despite the fact that opengl is notoriously singlethreaded – I got around this by basically reimplementing command buffers (ie. the ones in vulkan / metal / directx 12), but this made things horrifically complicated). It has probably the world's worst GUI library, pretty good gamepad support (that's one of the few things in this project that I'm somewhat proud of), and pretty good automatic resolution switching for high-dpi displays, implemented ofc using GLFW callbacks and some basic logic off of the framebuffer / window size.

This project should be as crossplatform as D is, and glfw / opengl 4.1. There is one crappy hack (see ext/), since I apparently didn't want to write proper bindings for stb, tk_objfile, and a few other things. I doubt you could compile this for mobile though, first because of the opengl 4.1 dependency, and secondly b/c I'm pretty sure that D's core.atomic has a bunch of x86 assembly in it and no ARM version :/


## Build Instructions:

    git clone https://github.com/SeijiEmery/gsb.git
    cd gsb
    cd ext && make && cd ..

To run demos:

    dub run :gsb
    dub run :flycam-test
    dub run :modelviewer-test

## Screenshots:

flycam-test:      <https://imgur.com/a/nLa02>

modelviewer-test: <http://imgur.com/a/u7ByN>

gsb:              <https://imgur.com/a/AV9lQ>

## Demo controls:

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

#### 2d game test (dub run :gsb):

Basic 1-4 player coop / competitive game built out of what I had working at the time. Wrote this over a weekend, so it's pretty simple. 

Requires gamepad(s), which should be plug / play. Supports xbox, DS3, and DS4 input mappings. Apparently I didn't bother to add mouse / keyboard input bindings, sorry :/

Controls / gameplay:
 – you control a circle thingy, and have health and energy. The second regens, and is used for abilities.
 – move (and aim) with LS
 - xbox "X" to shoot lasers
 - xbox "A" to jump (teleport) a short distance
 - xbox "Y" spawns one enemy (red) in the center of the screen. xbox "B" does the same thing, but can be held continuously
 - the enemies have swarming behavior, which makes things interesting
 - the simulation rate can be sped up / slowed down (to zero) by pressing the left / right triggers. This is cool, and could probably have been worked into an interesting game mechanic; as is, it makes dodging lasers more feasible as there is a visible half second delay before actually firing. Bumpers changes the base time rate up / down.
 - if you die, you have a 5 second countdown before respawning. Goal is to murder all other players and not die.
 - super basic, but can be kinda fun w/ friends.
 - source code is in gametest.d
