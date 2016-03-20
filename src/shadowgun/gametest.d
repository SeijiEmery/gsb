
module gsb.shadowgun.gametest;
import gsb.gl.debugrenderer;
import gsb.gl.debugrenderer;
import gsb.core.uimanager;
import gsb.core.uievents;
import gsb.core.pseudosignals;
import gsb.core.log;
import gsb.core.ui.uielements;
import gsb.text.font;
import gsb.core.gamepad;
import gsb.core.color;
import gsb.core.window;
import gl3n.linalg;

import gsb.core.stats;
import gsb.core.collision2d;

import std.random;
import std.algorithm;


shared static this () {
    UIComponentManager.runAtInit({
        UIComponentManager.registerComponent(new GameModule(), "game-test", true);
    });
}

auto immutable ENEMY_COLOR  = Color(0.93, 0.07, 0.05, 0.86);
auto immutable PLAYER_COLOR = Color(0.28, 0.69, 0.72, 0.63);
auto immutable INACTIVE_COLOR = Color(0.21, 0.22, 0.23, 0.79);

private float numCirclePoints = 25;
private float circleWidth = 0.04;

float GAME_UNITS_PER_SCREEN = 100.0;
float DEFAULT_AGENT_MOVE_SPEED = 30.0;
float AGENT_JUMP_LENGTH = 12.0;
float AGENT_JUMP_INTERVAL = 0.32;

float AGENT_SIZE = 1.0;
//float AGENT_FIRE_INTERVAL = 0.08;
float AGENT_FIRE_INTERVAL = 0.04;

float CURRENT_SCALE_FACTOR = 1.0;

float FIRE_OFFSET = 0.01;
float FIRE_LINE_LENGTH = 100.0;  // game units
float FIRE_LINE_WIDTH  = 0.01;    // game units
float FIRE_LINE_CHARGE_DURATION = 0.16;  // seconds
float FIRE_LINE_STATIC_DURATION = 0.035;  // seconds; should equal 3 frames @60 hz

float DAMAGE_FLASH_DURATION = 0.16;

float AGENT_ALIGNMENT_DISTANCE = 40.0;

auto TEXT_COLOR_WHITE = Color(1,1,1, 0.85);
auto FONT = "menlo";
auto SMALL_FONT_SIZE = 18.0;
auto PLAYER_NAME_FONT_SIZE = 40.0;
auto PLAYER_INFO_FONT_SIZE = 25.0;

private mat3 gameToScreenSpaceTransform (float zoom = 1.0) {
    float s = CURRENT_SCALE_FACTOR = zoom / GAME_UNITS_PER_SCREEN * g_mainWindow.screenDimensions.x;
    return mat3.identity()
        .scale(s, s, 1.0)
        .translate(vec3(vec2(g_mainWindow.screenDimensions) * 0.5, 0.0));

}

interface IGameController { void handleEvent (UIEvent event); }
interface IGameSystem     { void run (GameState state, float dt); }
interface IGameRenderable { void draw (mat3 transform); }

enum AgentId : ubyte {
    ENEMY = 0,
    PLAYER_1 = 1,
    PLAYER_2 = 2,
    PLAYER_3 = 3,
    PLAYER_4 = 4,
    INACTIVE = 5,
    WALL     = 6,
}
immutable Color[] AGENT_COLORS = [
    Color(0.93, 0.07, 0.05, 0.86), // ENEMY
    Color(0.28, 0.69, 0.72, 0.63), // PLAYER 1
    Color(1.00, 0.71, 0.00, 0.67), // ...
    Color(1.00, 0.14, 0.19, 0.67), 
    Color(0.28, 0.75, 0.26, 0.63), // PLAYER 4
    Color(0.44, 0.44, 0.44, 0.63), // INACTIVE
    Color(0.21, 0.22, 0.23, 0.79), // WALL
];




private class Agent : IGameRenderable {

    AgentId owner = AgentId.ENEMY;
    bool dead = false;

    vec2 position = vec2(0, 0);
    vec2 dir      = vec2(0, 0);

    vec2 fireDir = vec2(0, 0);
    bool wantsToFire = false;
    bool wantsToJump = false;
    float timeSinceLastFired = 0.0;
    float timeSinceLastJumped = 0.0;

    float timeSinceTookDamage = 0.0;

    @property bool isEnemy () {
        return owner == AgentId.ENEMY;
    }
    @property bool isPlayer () {
        return owner >= AgentId.PLAYER_1 && owner <= AgentId.PLAYER_4;
    }

    void update (float speed) {
        //log.write("update: %s + %s * %0.2f (%s) = %s", position, dir, speed * DEFAULT_AGENT_MOVE_SPEED, dir * speed * DEFAULT_AGENT_MOVE_SPEED, 
        //    position + dir * speed * DEFAULT_AGENT_MOVE_SPEED);
        position += dir * speed * DEFAULT_AGENT_MOVE_SPEED;
    }
    void draw (mat3 transform) {

        auto t = (timeSinceTookDamage / DAMAGE_FLASH_DURATION - 0.5) * 2;

        //float colorInterp = timeSinceTookDamage > 0 ? 1 - t * t : 0;
        float colorInterp = timeSinceTookDamage > 0 ? (timeSinceTookDamage / DAMAGE_FLASH_DURATION) : 0.0;

        auto color = Color(
            AGENT_COLORS[owner].r * 0.5 * (1 - colorInterp) + 1.0 * colorInterp,
            AGENT_COLORS[owner].g * 0.5 * (1 - colorInterp) + 1.0 * colorInterp,
            AGENT_COLORS[owner].b * 0.5 * (1 - colorInterp) + 1.0 * colorInterp,
            AGENT_COLORS[owner].a * 0.5 * (1 - colorInterp) + 1.0 * colorInterp,
        );

        auto tpos = transform * vec3(position, 1.0);
        DebugRenderer.drawCircle(tpos.xy, AGENT_SIZE * CURRENT_SCALE_FACTOR, color, circleWidth, 
            cast(uint)numCirclePoints, 2.0);

        //log.write("draw: %s * transform = %s, size: %s * %0.2f = %s", position, tpos, AGENT_SIZE, CURRENT_SCALE_FACTOR, AGENT_SIZE * CURRENT_SCALE_FACTOR);
    }
    void takeDamage () {
        timeSinceTookDamage = DAMAGE_FLASH_DURATION;
    }
    bool collidesWith (Agent other) {
        return Collision2d.intersects(Collision2d.Circle(position, AGENT_SIZE), Collision2d.Circle(other.position, AGENT_SIZE));
    }
}

private class DamageSystem : IGameSystem {
    void run (GameState state, float dt) {
        foreach (agent; state.agents) {
            agent.timeSinceTookDamage -= dt;
        }
        foreach (agent; state.enemyAgents) {
            foreach (player; state.playerAgents) {
                if (agent.collidesWith(player)) {
                    player.takeDamage();
                }
            }
        }
        foreach (fireLine; state.fireLines) {
            if (fireLine.t < 0 && !fireLine.wasFired) {
                auto line = Collision2d.LineSegment(fireLine.start, fireLine.dir * FIRE_LINE_LENGTH, FIRE_LINE_WIDTH);
                foreach (agent; state.agents) {
                    if (agent.owner != fireLine.owner && Collision2d.intersects(Collision2d.Circle(agent.position, AGENT_SIZE), line)) {
                        agent.takeDamage();
                    }
                }
                fireLine.wasFired = true;
            }
        }
    }
}

private class FiringSystem : IGameSystem {
    void run (GameState state, float dt) {
        foreach (agent; state.agents) {
            if ((agent.timeSinceLastFired -= dt) < 0 && agent.wantsToFire) {
                if (agent.isEnemy)
                    agent.timeSinceLastFired = uniform01!float() * 10.0;
                else
                    agent.timeSinceLastFired = AGENT_FIRE_INTERVAL;
                state.fireBurst(agent.position, agent.fireDir, agent.owner);
            }
            if ((agent.timeSinceLastJumped -= dt) < 0 && agent.wantsToJump) {
                agent.timeSinceLastJumped = AGENT_JUMP_INTERVAL;
                agent.position += agent.dir * AGENT_JUMP_LENGTH;
            }
        }
    }
}

private class EnemyPursuitSystem : IGameSystem {
    void run (GameState state, float dt) {
        auto futurePlayerDir = state.player.position + state.player.dir * DEFAULT_AGENT_MOVE_SPEED * 1.0;
        auto futurePlayerTarget = state.player.position + state.player.dir * (FIRE_LINE_CHARGE_DURATION) * DEFAULT_AGENT_MOVE_SPEED; // this is evil, lol

        //log.write("%s", state.agents.map!("a.position.toString()").join(", "));
        foreach (agent; state.agents) {
            if (agent.owner != AgentId.ENEMY)
                continue;

            if (distance(agent.position, state.player.position) > 40.0 || (!agent.dir.x && !agent.dir.y)) {
                agent.dir = (futurePlayerDir - agent.position).normalized();
            }

            auto sep_force = vec2(0,0);
            foreach (neighbor; state.agents)
                if (neighbor.owner == AgentId.ENEMY && neighbor.position != agent.position)
                    sep_force += (neighbor.position - agent.position);

            immutable float WEIGHT = 1.0;

            //agent.dir += sep_force * 1e-2;

            if (sep_force.x != 0 && sep_force.y != 0) {
                sep_force.x = WEIGHT / (sep_force.x * sep_force.x);
                sep_force.y = WEIGHT / (sep_force.y * sep_force.y);

                //auto MAX_FORCE = WEIGHT * 2;
                //sep_force.x = min(MAX_FORCE, max(-MAX_FORCE, sep_force.x));
                //sep_force.y = min(MAX_FORCE, max(-MAX_FORCE, sep_force.y));

                agent.dir += sep_force * 1.5;
            }
            agent.dir.normalize();

            //log.write("%s, %s", sep_force, agent.dir);
            //agent.dir += sep_force * -1.0e-3;

            //agent.fireDir = (state.player.position - agent.position).normalized();
            agent.fireDir = (futurePlayerTarget - agent.position).normalized();
            //agent.wantsToFire = uniform01() <= 1.0 / 120.0;
            agent.wantsToFire = true;
        }
    }
}


private class FireLine {
    AgentId owner;
    Color color;
    vec2 start, dir;
    float t, chargeDuration, staticDuration;
    bool wasFired = false;

    this (AgentId owner, vec2 start, vec2 dir, float chargeDuration, float staticDuration) {
        this.owner = owner;
        this.start = start;
        this.dir = dir;

        this.t = chargeDuration;
        this.chargeDuration = chargeDuration;
        this.staticDuration = staticDuration;
    }
    bool update (float dt) {
        return !((t -= dt) < 0 && abs(t) > staticDuration);
    }
    void draw (mat3 transform) {


        //vec3 p1 = transform * vec3(start + dir * FIRE_OFFSET * CURRENT_SCALE_FACTOR, 1.0);
        vec3 p1 = transform * vec3(start + dir * FIRE_OFFSET, 1.0);
        vec3 p2 = transform * vec3(start + dir * FIRE_LINE_LENGTH, 1.0);

        //log.write("Drawing: %s, %s (t = %s)", p1, p2, t);

        auto colorInterp = t > 0 ?
            (chargeDuration - t) / chargeDuration * 0.5 :
            1.0 + 0.2 * t / staticDuration;

        colorInterp = colorInterp * colorInterp;

        auto color = Color(
            AGENT_COLORS[owner].r * 0.5 * (1 - colorInterp) + 1.0 * colorInterp,
            AGENT_COLORS[owner].g * 0.5 * (1 - colorInterp) + 1.0 * colorInterp,
            AGENT_COLORS[owner].b * 0.5 * (1 - colorInterp) + 1.0 * colorInterp,
            AGENT_COLORS[owner].a * 0.5 * (1 - colorInterp) + 1.0 * colorInterp,
        );
        DebugRenderer.drawLines([ p1.xy, p2.xy ], color, FIRE_LINE_WIDTH * CURRENT_SCALE_FACTOR);
    }
}

private class GameState {
    IGameSystem[] systems;
    Agent   player;
    Agent[] agents;
    float simSpeed = 1.0;
    float zoom = 1.0;

    FireLine[] fireLines;

    @property auto playerAgents () {
        return agents.filter!"a.isPlayer"();
    }
    @property auto enemyAgents () {
        return agents.filter!"a.isEnemy"();
    }

    this (Agent player) {
        this.systems = [
            cast(IGameSystem)new FiringSystem(),
            cast(IGameSystem)new EnemyPursuitSystem(),
            cast(IGameSystem)new DamageSystem(),
        ];
        this.agents = [ player ];
        this.player = player;
    }

    void update (float dt = 1 / 60.0) {
        foreach (system; systems)
            system.run(this, simSpeed * dt);
        foreach (agent; agents)
            agent.update(simSpeed * dt);

        for (auto i = fireLines.length; i --> 0; ) {
            if (!fireLines[i].update(simSpeed * dt)) {
                fireLines[i] = fireLines[$-1];
                fireLines.length -= 1;
            }
        }
    }

    void draw () {
        auto transform = gameToScreenSpaceTransform(zoom);
        foreach (thing; fireLines)
            thing.draw(transform);
        foreach (agent; agents)
            agent.draw(transform);
    }

    void fireBurst (vec2 pos, vec2 dir, AgentId owner) {
        fireLines ~= new FireLine(owner, pos, dir, FIRE_LINE_CHARGE_DURATION, FIRE_LINE_STATIC_DURATION);
    }

    void createEnemy (vec2 pos) {
        auto enemy = new Agent(); 
        enemy.position = pos;        
        agents      ~= enemy;
    }
}

private class PlayerController : IGameController {
    Agent player;
    GameState gameState;

    this (Agent agent, AgentId owner, GameState gameState) {
        agent.owner  = owner;
        this.player = agent;
        this.gameState = gameState;
    }

    void handleEvent (UIEvent event) {
        event.handle!(
            (GamepadAxisEvent ev) {
                player.dir = vec2(ev.AXIS_LX, ev.AXIS_LY);
                gameState.simSpeed = 1.0 - ev.AXIS_RT;

                if (player.wantsToFire && (ev.AXIS_LX || ev.AXIS_LY))
                    player.fireDir = vec2(ev.AXIS_LX, ev.AXIS_LY).normalized();
            },
            (GamepadButtonEvent ev) {
                if (ev.button == BUTTON_X)
                    player.wantsToFire = ev.pressed;
                else if (ev.button == BUTTON_A)
                    player.wantsToJump = ev.pressed;
                else if (ev.button == BUTTON_Y && ev.pressed)
                    gameState.createEnemy(vec2(0, 0));
            },
            () {});
    }
}

private class GameUI {
    UILayoutContainer[] containers;
    UITextElement stats;
    PlayerUI[4]   playerUI;

    class PlayerUI {
        AgentId owner = AgentId.PLAYER_1;
        UILayoutContainer container;
        UITextElement     score;
        bool              isActive = false;

        this (AgentId owner, string name, Layout layoutPos, bool isActive) {
            this.owner = owner;
            this.isActive = isActive;
            container = new UILayoutContainer(LayoutDir.VERTICAL, layoutPos, vec2(5,5), 4, [
                new UITextElement(vec2(),vec2(),vec2(5,5), name, new Font(FONT, PLAYER_NAME_FONT_SIZE), AGENT_COLORS[owner], Color()),
                score = new UITextElement(vec2(),vec2(),vec2(5,5), "", new Font(FONT, PLAYER_INFO_FONT_SIZE), AGENT_COLORS[owner], Color()),
            ]);
        }
        void update () {
            if (isActive) {
                container.dim = vec2(g_mainWindow.screenDimensions);
                container.pos = vec2(0,0);
                container.recalcDimensions();
                container.doLayout();
                container.render();
            } else {
                // hack: move offscreen to not render. Will add caching / state retention, etc later.
                container.pos = vec2(g_mainWindow.screenDimensions) * 2;
                container.doLayout();
            }
        }
        void release () { if (container) { container.release(); container = null; } }
    }

    this () {
        containers ~= new UILayoutContainer(LayoutDir.VERTICAL, Layout.TOP_CENTER, vec2(5,5), 3, [
            stats = new UITextElement(vec2(),vec2(),vec2(1,1),"", new Font(FONT, SMALL_FONT_SIZE), TEXT_COLOR_WHITE, Color())
        ]);
        playerUI[0] = new PlayerUI(AgentId.PLAYER_1, "PLAYER 1", Layout.TOP_LEFT,  true);
        playerUI[1] = new PlayerUI(AgentId.PLAYER_2, "PLAYER 2", Layout.TOP_RIGHT, false);
        playerUI[2] = new PlayerUI(AgentId.PLAYER_3, "PLAYER 3", Layout.BTM_LEFT,  true);
        playerUI[3] = new PlayerUI(AgentId.PLAYER_4, "PLAYER 4", Layout.BTM_RIGHT, true);
    }
    void release () {
        if (containers.length) {
            foreach (player; playerUI)
                player.release();
            foreach (container; containers)
                container.release();
            containers.length = 0;
        }
    }
    void update () {
        foreach (player; playerUI)
            player.update();
        foreach (container; containers) {
            container.dim = vec2(g_mainWindow.screenDimensions);
            container.recalcDimensions();
            container.doLayout();
            container.render();
        }
    }
}

private class GameModule : UIComponent {
    IGameController[] controllers;
    GameState gameState;
    GameUI    ui;

    override void onComponentInit () {
        auto player = new Agent();
        gameState = new GameState(player);
        ui = new GameUI();

        controllers ~= new PlayerController(player, AgentId.PLAYER_1, gameState);
    }
    override void onComponentShutdown () {
        controllers.length = 0;
        gameState = null;
        ui = null;
    }
    override void handleEvent (UIEvent event) {
        if (controllers.length) {
            event.handle!(
                (FrameUpdateEvent ev) {
                    threadStats.timedCall("gamestate.update()", {
                        gameState.update();
                    });
                    threadStats.timedCall("gamestate.draw()", {
                        gameState.draw();
                    });
                    threadStats.timedCall("gamestate.ui()", {
                        ui.stats.text = format("%d agents\nspeed %0.2f", gameState.agents.length, gameState.simSpeed);
                        ui.update();
                    });
                    return true;
                },
                (ScrollEvent ev) {
                    log.write("set zoom = %0.2f", gameState.zoom += ev.dir.y * 0.05);
                    return false;
                },
                () { return false; }
            ) || fireControllerEvents(event);
        }
    }
    void fireControllerEvents (UIEvent event) {
        foreach (controller; controllers)
            controller.handleEvent(event);
    }
}












































