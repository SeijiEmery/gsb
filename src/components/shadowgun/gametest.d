
module gsb.shadowgun.gametest;
import gsb.gl.debugrenderer;
import gsb.gl.debugrenderer;
import gsb.core.uimanager;
import gsb.core.uievents;
import gsb.utils.signals;
import gsb.core.log;
import gsb.core.ui.uielements;
import gsb.text.font;
import gsb.core.gamepad;
import gsb.utils.color;
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

immutable float GAME_UNITS_PER_SCREEN = 200.0;
float DEFAULT_AGENT_MOVE_SPEED = 30.0;
float AGENT_JUMP_LENGTH = 12.0;
float AGENT_JUMP_INTERVAL = 0.32;

float AGENT_SIZE = 1.5;
float AGENT_FIRE_INTERVAL = 0.0;
//float AGENT_FIRE_INTERVAL = 0.05;
//float AGENT_FIRE_INTERVAL = 0.04;

float CURRENT_SCALE_FACTOR = 1.0;

float FIRE_OFFSET = 0.01;
float FIRE_LINE_LENGTH = 100.0;  // game units
float FIRE_LINE_WIDTH  = 0.005;    // game units
float FIRE_LINE_CHARGE_DURATION = 0.16;  // seconds
float FIRE_LINE_STATIC_DURATION = 0.035;  // seconds; should equal 3 frames @60 hz

float DAMAGE_FLASH_DURATION = 0.16;

float AGENT_ALIGNMENT_DISTANCE = 40.0;

immutable float INITIAL_PLAYER_HP = 300.0;
immutable float MAX_ENERGY        = 100.0;

float ENERGY_COST_PER_SHOT     = 4.0;
//float ENERGY_COST_PER_SHOT     = 12.0;
float ENERGY_COST_PER_JUMP     = 20.0;
float ENERGY_REGEN_PER_SEC     = 24.0;
float ENERGY_UNDERFLOW_PENALTY = 40.0;

float POINTS_LOST_PER_HP       = 0.5;  // 5 points lost / 10 hp
float POINTS_GAINED_PER_HP     = 1.0;  // 10 points gained / 10 hp
float POINTS_GAINED_PER_KILL   = 100.0;

float PLAYER_KILL_MULTIPLIER   = 2.0;
float SWARMER_KILL_MULTIPLIER  = 0.1;
float ROVER_KILL_MULTIPLIER    = 0.5;
float SPAWNER_KILL_MULTIPLIER  = 3.0;

float PLAYER_INITIAL_HP = 300.0;
float SWARMER_INITIAL_HP = 30.0;
float ROVER_INITIAL_HP   = 50.0;
float SPAWNER_INITIAL_HP = 800.0;

float PLAYER_DAMAGE  = 20.0;
float SWARMER_DAMAGE = 5.0;
float ROVER_DAMAGE   = 15.0;

float PLAYER_LIFE_STEAL  = 0.2;
float SWARMER_LIFE_STEAL = 2.0;
float ROVER_LIFE_STEAL   = 0.5;
float SPAWNER_LIFE_STEAL = 0.0;

float PLAYER_MAX_HP  = 1000;
float SWARMER_MAX_HP = 60;
float ROVER_MAX_HP   = 80;
float SPAWNER_MAX_HP = 800;

float PLAYER_HP_REGEN_PER_SEC = 15.0;
float PLAYER_HP_REGEN_DELAY   = 2.0;  // regen if not hit for X seconds

float PLAYER_RESPAWN_TIME = 5.0;

enum AgentId : ubyte {
    PLAYER_1 = 0,
    PLAYER_2,
    PLAYER_3,
    PLAYER_4,
    ENEMY_SWARMER,
    ENEMY_ROVER,
    ENEMY_SPAWNER,
    GREEN_WALL_OF_DOOM,
    INACTIVE
}


auto TEXT_COLOR_WHITE = Color(1,1,1, 0.85);
auto FONT = "menlo";
auto SMALL_FONT_SIZE = 18.0;
auto PLAYER_NAME_FONT_SIZE = 40.0;
auto PLAYER_INFO_FONT_SIZE = 25.0;

auto HEALTH_BAR_DIMENSIONS = vec2(250, 30);
auto ENERGY_BAR_DIMENSIONS = vec2(150, 18);

private mat3 gameToScreenSpaceTransform (float zoom = 1.0) {
    float s = CURRENT_SCALE_FACTOR = zoom / GAME_UNITS_PER_SCREEN * g_mainWindow.screenDimensions.x;
    return mat3.identity()
        .scale(s, s, 1.0)
        .translate(vec3(vec2(g_mainWindow.screenDimensions) * 0.5, 0.0));

}

interface IGameController { void handleEvent (UIEvent event); }
interface IGameSystem     { void run (GameState state, float dt); }
interface IGameRenderable { void draw (mat3 transform); }

immutable Color[9] AGENT_COLORS = [
    Color(0.28, 0.69, 0.72, 0.63), // PLAYER 1
    Color(1.00, 0.71, 0.00, 0.67), // ...
    Color(1.00, 0.14, 0.89, 0.67), // ...
    Color(0.28, 0.75, 0.26, 0.63), // PLAYER 4
    Color(0.93, 0.07, 0.05, 0.86), // ENEMY
    Color(0.93, 0.07, 0.05, 0.86), // 
    Color(0.93, 0.07, 0.05, 0.86), // 
    Color(0.21, 0.22, 0.23, 0.79), // WALL
    Color(0.44, 0.44, 0.44, 0.63), // INACTIVE
];

// Relative to current window dimensions
immutable vec2[4] PLAYER_SPAWN_POSITIONS = [
    vec2(-0.25 * GAME_UNITS_PER_SCREEN, -0.140625 * GAME_UNITS_PER_SCREEN),
    vec2(+0.25 * GAME_UNITS_PER_SCREEN, -0.140625 * GAME_UNITS_PER_SCREEN),
    vec2(-0.25 * GAME_UNITS_PER_SCREEN, +0.140625 * GAME_UNITS_PER_SCREEN),
    vec2(+0.25 * GAME_UNITS_PER_SCREEN, +0.140625 * GAME_UNITS_PER_SCREEN),
];

auto makeBackgroundColor (Color color) {
    return Color(color.r + 0.1, color.g + 0.1, color.b + 0.1, color.a * 0.5);
}

private class Agent : IGameRenderable {
    AgentId agentId;
    bool isAlive = true;

    float hp     = 1.0;       // current hp
    float maxHp  = 1.0;       // max hp agent has had in this lifetime (affects regen + hp display)
    float maxAllowedHp = 1.0; // max hp agent is allowed to have (defined by <AgentName>_MAX_HP)
    float energy = MAX_ENERGY;
    float points = 0;
    float damage = 0.0;
    float lifeSteal = 0.0;

    vec2 position = vec2(0, 0);
    vec2 dir      = vec2(0, 0);

    vec2 fireDir = vec2(0, 0);
    bool wantsToFire = false;
    bool wantsToJump = false;
    float timeSinceLastFired = 0.0;
    float timeSinceLastJumped = 0.0;

    float timeSinceTookDamage = 0.0;

    @property bool isEnemy () {
        return agentId == AgentId.ENEMY_SPAWNER || 
               agentId == AgentId.ENEMY_ROVER || 
               agentId == AgentId.ENEMY_SWARMER;
    }
    @property bool isPlayer () {
        return agentId >= AgentId.PLAYER_1 && agentId <= AgentId.PLAYER_4;
    }
    @property auto killValue () {
        return isPlayer ? PLAYER_KILL_MULTIPLIER :
            agentId == AgentId.ENEMY_ROVER ? ROVER_KILL_MULTIPLIER :
            agentId == AgentId.ENEMY_SWARMER ? SWARMER_KILL_MULTIPLIER :
            agentId == AgentId.ENEMY_SPAWNER ? SPAWNER_KILL_MULTIPLIER : 1.0;
    }

    this (vec2 pos, AgentId id) {
        this.position = pos;
        this.agentId = id;
        this.hp = this.maxHp = isPlayer ? PLAYER_INITIAL_HP : ROVER_INITIAL_HP;
        this.maxAllowedHp = isPlayer ? PLAYER_MAX_HP  : ROVER_MAX_HP;
        this.damage = isPlayer ? PLAYER_DAMAGE : ROVER_DAMAGE;
        this.lifeSteal = isPlayer ? PLAYER_LIFE_STEAL : ROVER_LIFE_STEAL;
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
            AGENT_COLORS[agentId].r * (1 - colorInterp) + 1.0 * colorInterp,
            AGENT_COLORS[agentId].g * (1 - colorInterp) + 1.0 * colorInterp,
            AGENT_COLORS[agentId].b * (1 - colorInterp) + 1.0 * colorInterp,
            AGENT_COLORS[agentId].a * (1 - colorInterp) + 1.0 * colorInterp,
        );

        auto tpos = transform * vec3(position, 1.0);
        DebugRenderer.drawCircle(tpos.xy, (AGENT_SIZE * CURRENT_SCALE_FACTOR - 2.0), color, circleWidth, 
            cast(uint)numCirclePoints, 2.0);

        //log.write("draw: %s * transform = %s, size: %s * %0.2f = %s", position, tpos, AGENT_SIZE, CURRENT_SCALE_FACTOR, AGENT_SIZE * CURRENT_SCALE_FACTOR);
    }
    void regenHp (float amount) {
        hp = min(hp + amount, maxAllowedHp);
        maxHp = max(hp, maxHp);
    }
    void takeDamage (Agent damager) {
        timeSinceTookDamage = DAMAGE_FLASH_DURATION;
        this.hp    -= damager.damage;
        damager.regenHp(damager.damage * damager.lifeSteal);

        this.points -= damager.damage * POINTS_LOST_PER_HP;
        damager.points += damager.damage * POINTS_GAINED_PER_HP;
        if (this.hp <= 0 && this.hp + damager.damage > 0)
            damager.points += this.killValue * POINTS_GAINED_PER_KILL;
        isAlive = hp > 0;
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
                    player.takeDamage(agent);
                }
            }
        }
        foreach (fireLine; state.fireLines) {
            if (fireLine.t < 0 && !fireLine.wasFired) {
                auto line = Collision2d.LineSegment(
                    fireLine.start, 
                    fireLine.start + fireLine.dir * FIRE_LINE_LENGTH, 
                    FIRE_LINE_WIDTH);
    
                foreach (agent; state.agents) {
                    auto circle = Collision2d.Circle(agent.position, AGENT_SIZE);
                    if (agent.agentId != fireLine.ownerId && Collision2d.intersects(circle, line)) {
                        agent.takeDamage(fireLine.owner);
                    }
                }
                fireLine.wasFired = true;
            }
        }

        foreach (player; state.playerAgents) {
            if (player.timeSinceTookDamage < -PLAYER_HP_REGEN_DELAY && player.hp < player.maxHp) {
                player.regenHp(min(PLAYER_HP_REGEN_PER_SEC * dt, player.maxHp - player.hp));
            }
        }

    }
}

private class FiringSystem : IGameSystem {
    void run (GameState state, float dt) {
        foreach (agent; state.agents) {
            agent.energy = min(MAX_ENERGY, agent.energy + ENERGY_REGEN_PER_SEC * dt);
            if ((agent.timeSinceLastFired -= dt) < 0 && agent.wantsToFire && agent.energy >= ENERGY_COST_PER_SHOT) {
                if (agent.energy - ENERGY_COST_PER_SHOT < 0)
                    agent.energy -= ENERGY_UNDERFLOW_PENALTY;
                agent.energy -= ENERGY_COST_PER_SHOT;

                if (agent.isEnemy)
                    agent.timeSinceLastFired = uniform01!float() * 10.0;
                else
                    agent.timeSinceLastFired = AGENT_FIRE_INTERVAL;
                state.fireBurst(agent.position, agent.fireDir, agent);
            }
            if ((agent.timeSinceLastJumped -= dt) < 0 && agent.wantsToJump && agent.energy >= ENERGY_COST_PER_JUMP) {
                if (agent.energy - ENERGY_COST_PER_JUMP < 0)
                    agent.energy -= ENERGY_UNDERFLOW_PENALTY;
                agent.energy -= ENERGY_COST_PER_JUMP;

                agent.timeSinceLastJumped = AGENT_JUMP_INTERVAL;
                agent.position += agent.dir * AGENT_JUMP_LENGTH;
            }
        }
    }
}

private class EnemyPursuitSystem : IGameSystem {
    void run (GameState state, float dt) {
        // charge at players

        Agent[] players = [];
        foreach (agent; state.agents)
            if (agent.isPlayer)
                players ~= agent;
        if (players.length) {
            foreach (agent; state.agents) {
                if (!agent.isEnemy)
                    continue;

                Agent nearest = players[0];
                foreach (player; players[1..$])
                    if (distance(agent.position, player.position) < distance(agent.position, nearest.position))
                        nearest = player;

                auto futurePos    = nearest.position + nearest.dir * DEFAULT_AGENT_MOVE_SPEED  * (uniform01!float() + 0.5);
                auto futureTarget = nearest.position + nearest.dir * FIRE_LINE_CHARGE_DURATION * DEFAULT_AGENT_MOVE_SPEED * uniform01!float() * 2.0;

                // charge at player
                if (distance(agent.position, nearest.position) > 40.0 || (!agent.dir.x && !agent.dir.y)) {
                    agent.dir = (futurePos - agent.position).normalized();
                }
                // fire at player
                agent.fireDir = (futureTarget - agent.position).normalized();
                agent.wantsToFire = true;
            }
        }

        // Apply separation forces
        foreach (agent; state.agents) {
            if (!agent.isEnemy())
                continue;
            auto sep_force = vec2(0,0);
            foreach (neighbor; state.agents)
                if (neighbor.isEnemy && neighbor.position != agent.position)
                    sep_force += (neighbor.position - agent.position);
            immutable float WEIGHT = 1.0;

            if (sep_force.x != 0 && sep_force.y != 0) {
                sep_force.x = WEIGHT / (sep_force.x * sep_force.x);
                sep_force.y = WEIGHT / (sep_force.y * sep_force.y);

                //auto MAX_FORCE = WEIGHT * 2;
                //sep_force.x = min(MAX_FORCE, max(-MAX_FORCE, sep_force.x));
                //sep_force.y = min(MAX_FORCE, max(-MAX_FORCE, sep_force.y));

                agent.dir += sep_force * 1.5;
            }
            agent.dir.normalize();
        }
    }
}


private class FireLine {
    Agent owner;
    Color color;
    vec2 start, dir;
    float t, chargeDuration, staticDuration;
    bool wasFired = false;

    @property auto ownerId () { return owner.agentId; }

    this (Agent owner, vec2 start, vec2 dir, float chargeDuration, float staticDuration) {
        this.owner = owner;
        this.color = AGENT_COLORS[owner.agentId];

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

        auto c = Color(
            color.r * 0.5 * (1 - colorInterp) + 1.0 * colorInterp,
            color.g * 0.5 * (1 - colorInterp) + 1.0 * colorInterp,
            color.b * 0.5 * (1 - colorInterp) + 1.0 * colorInterp,
            color.a * 0.5 * (1 - colorInterp) + 1.0 * colorInterp,
        );
        DebugRenderer.drawLines([ p1.xy, p2.xy ], c, FIRE_LINE_WIDTH * CURRENT_SCALE_FACTOR, 1.0);
    }
}

private class GameState {
    IGameSystem[] systems;
    Agent[] agents;
    float simSpeed = 1.0;
    float baseSimSpeed = 1.0;
    float zoom = 1.0;

    FireLine[] fireLines;

    @property auto playerAgents () {
        return agents.filter!"a.isPlayer"();
    }
    @property auto enemyAgents () {
        return agents.filter!"a.isEnemy"();
    }

    this () {
        this.systems = [
            cast(IGameSystem)new FiringSystem(),
            cast(IGameSystem)new EnemyPursuitSystem(),
            cast(IGameSystem)new DamageSystem(),
        ];
        this.agents = [];
    }

    void update (float dt) {
        foreach (system; systems)
            system.run(this, simSpeed * dt);
        for (auto i = agents.length; i --> 0; ) {
            if (!agents[i].isAlive) {
                agents[i] = agents[$-1];
                agents.length--;
            } else {
                agents[i].update(simSpeed * dt);
            }
        }

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

    void fireBurst (vec2 pos, vec2 dir, Agent owner) {
        fireLines ~= new FireLine(owner, pos, dir, FIRE_LINE_CHARGE_DURATION, FIRE_LINE_STATIC_DURATION);
    }

    void createEnemy (vec2 pos) {
        auto enemy = new Agent(pos, AgentId.ENEMY_ROVER); 
        agents      ~= enemy;
    }
}

private class PlayerController : IGameController {
    GameState gameState;
    Agent agent;
    AgentId playerId;
    int  gamepadId;
    bool isActive = true;
    private float retainedScore = 0.0;
    float timeUntilRespawn = 0.0;
    float desiredSimSpeed  = 1.0;

    @property float energy () { return agent && agent.isAlive ? agent.energy : 0; }
    @property float hp     () { return agent && agent.isAlive ? agent.hp     : 0; }
    @property float maxHp  () { return agent && agent.isAlive ? agent.maxHp  : PLAYER_INITIAL_HP; }

    @property float score () {
        return retainedScore + (agent && agent.isAlive ? agent.points : 0.0);
    }

    this (Agent agent, GameState gameState, int gamepadId) {
        playerId = agent.agentId;
        this.agent  = agent;
        this.gameState = gameState;
        this.gamepadId = gamepadId;
    }

    void update (float dt) {
        if (agent && !agent.isAlive) {
            retainedScore += agent.points;
            agent = null;
            timeUntilRespawn = PLAYER_RESPAWN_TIME;
        } else if (!agent && (timeUntilRespawn -= dt / gameState.baseSimSpeed) <= 0) {
            agent = new Agent(PLAYER_SPAWN_POSITIONS[playerId - AgentId.PLAYER_1], playerId);
            gameState.agents ~= agent;
        }
    }

    void handleEvent (UIEvent event) {
        event.handle!(
            (GamepadAxisEvent ev) {
                if (ev.id == gamepadId) {
                    if (agent)
                        agent.dir = vec2(ev.AXIS_LX, ev.AXIS_LY);
                    
                    desiredSimSpeed = 1.0 - ev.AXIS_RT + ev.AXIS_LT;

                    if (agent && agent.wantsToFire && (ev.AXIS_LX || ev.AXIS_LY))
                        agent.fireDir = vec2(ev.AXIS_LX, ev.AXIS_LY).normalized();
                }
            },
            (GamepadButtonEvent ev) {
                if (ev.id == gamepadId) {
                    // X: fire, A: jump
                    if (agent && ev.button == BUTTON_X)
                        agent.wantsToFire = ev.pressed;
                    else if (agent && ev.button == BUTTON_A)
                        agent.wantsToJump = ev.pressed;

                    // Y: spawn enemy at origin
                    else if (ev.button == BUTTON_Y && ev.pressed)
                        gameState.createEnemy(vec2(0, 0));

                    // Dpad left,right,down, L/R bumpers: time controls (set baseSimSpeed)
                    else if (ev.pressed && (ev.button == BUTTON_DPAD_LEFT || ev.button == BUTTON_LBUMPER) && gameState.baseSimSpeed >= 0.25)
                        gameState.baseSimSpeed *= 0.5;
                    else if (ev.pressed && (ev.button == BUTTON_DPAD_RIGHT || ev.button == BUTTON_RBUMPER) && gameState.baseSimSpeed <= 8.0)
                        gameState.baseSimSpeed *= 2.0;
                    else if (ev.pressed && ev.button == BUTTON_DPAD_DOWN)
                        gameState.baseSimSpeed = 1.0;

                    // Start: move player to origin
                    else if (ev.pressed && ev.button == BUTTON_START)
                        agent.position = vec2(0, 0);
                }
            },
            () {});
    }
}

private class GameUI {
    UILayoutContainer[] containers;
    UITextElement stats;
    PlayerUI[4]   playerUI;

    class PlayerUI {
        AgentId playerId = AgentId.PLAYER_1;
        PlayerController  player = null;
        UILayoutContainer container;
        UITextElement     score;
        //UIBox             healthBar;
        //UIBox             energyBar;
        StatusBar healthBar, energyBar;
        UITextElement respawnText;


        class StatusBar {
            float width, value;
            Color color, backgroundColor;
            UIBox fbox, bbox;
            UILayoutContainer container;

            this (vec2 dimensions, float value, bool flip, Color color, Color backgroundColor) {
                this.fbox = new UIBox(vec2(), dimensions, color);
                this.bbox = new UIBox(vec2(), dimensions, backgroundColor);
                this.width = dimensions.x;

                this.color = color;
                this.backgroundColor = backgroundColor;

                this.container = flip ?
                    new UILayoutContainer(LayoutDir.HORIZONTAL, Layout.CENTER_RIGHT, vec2(0,0), 0.0, [ this.bbox, this.fbox ]) :
                    new UILayoutContainer(LayoutDir.HORIZONTAL, Layout.CENTER_LEFT,  vec2(0,0), 0.0, [ this.fbox, this.bbox ]);
                update(value, value, value);
                this.container.recalcDimensions();
                this.container.doLayout();
            }
            void update (float value, float max, float maxTotal) {
                fbox.dim.x = width * value / maxTotal;
                bbox.dim.x = width * (max - value) / maxTotal;
                this.container.dim.x = 0; // force relayout / recalc dimensions
            }
        }

        this (AgentId playerId, string name, Layout layoutPos, bool flip) {
            this.playerId = playerId;
            healthBar = new StatusBar(HEALTH_BAR_DIMENSIONS, 1.0, flip, AGENT_COLORS[playerId], makeBackgroundColor(AGENT_COLORS[playerId]));
            energyBar = new StatusBar(ENERGY_BAR_DIMENSIONS, 1.0, flip, AGENT_COLORS[playerId], makeBackgroundColor(AGENT_COLORS[playerId]));

            container = new UILayoutContainer(LayoutDir.VERTICAL, layoutPos, vec2(5,5), 4, [
                new UITextElement(vec2(),vec2(),vec2(0,0), name, new Font(FONT, PLAYER_NAME_FONT_SIZE), AGENT_COLORS[playerId], Color()),
                score = new UITextElement(vec2(),vec2(),vec2(0,0), "score 12355", new Font(FONT, PLAYER_INFO_FONT_SIZE), AGENT_COLORS[playerId], Color()),
                energyBar.container,
                healthBar.container,
            ]);
            this.respawnText = new UITextElement(vec2(1e-3,1e-3),vec2(),vec2(0,0), "", new Font(FONT, 50.0), AGENT_COLORS[playerId], Color());
        }
        void update () {
            if (player && player.isActive) {
                healthBar.update(player.hp, player.maxHp, PLAYER_INITIAL_HP);
                energyBar.update(player.energy, MAX_ENERGY, MAX_ENERGY);
                score.text = format("score %d", cast(int)player.score);

                container.dim = vec2(g_mainWindow.screenDimensions);
                container.pos = vec2(0,0);
                container.recalcDimensions();
                container.doLayout();
                container.render();

                if (!player.agent) {
                    import std.math;

                    vec2 center = g_mainWindow.screenDimensions;
                    switch (playerId) {
                        case AgentId.PLAYER_1: center = vec2(0.25 * center.x, 0.25 * center.y); break;
                        case AgentId.PLAYER_2: center = vec2(0.75 * center.x, 0.25 * center.y); break;
                        case AgentId.PLAYER_3: center = vec2(0.25 * center.x, 0.75 * center.y); break;
                        case AgentId.PLAYER_4: center = vec2(0.75 * center.x, 0.75 * center.y); break;
                        default:
                    }

                    respawnText.text = format("%d", cast(int)(player.timeUntilRespawn + (1 - 1e-6)));
                    auto frac = fmod(player.timeUntilRespawn, 1.0);
                    respawnText.fontSize = 50.0 + 150.0 * frac;

                    respawnText.recalcDimensions();
                    respawnText.pos = center - respawnText.dim * 0.5;
                    respawnText.doLayout();
                } else {
                    if (respawnText.pos.x >= 0 || respawnText.pos.y >= 0) {
                        respawnText.pos = vec2(1e-3, 1e-3);
                        respawnText.doLayout();
                    }
                }
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
        playerUI[0] = new PlayerUI(AgentId.PLAYER_1, "PLAYER 1", Layout.TOP_LEFT, false);
        playerUI[1] = new PlayerUI(AgentId.PLAYER_2, "PLAYER 2", Layout.TOP_RIGHT, true);
        playerUI[2] = new PlayerUI(AgentId.PLAYER_3, "PLAYER 3", Layout.BTM_LEFT, false);
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
    PlayerController[4] players;

    GameState gameState;
    GameUI    ui;

    override void onComponentInit () {
        gameState = new GameState();
        ui = new GameUI();
    }
    override void onComponentShutdown () {
        gameState = null;
        if (ui) {
            ui.release();
            ui = null;
        }
        foreach (i; 0 .. 4)
            players[i] = null;
    }
    override void handleEvent (UIEvent event) {
        if (gameState) {
            event.handle!(
                (GamepadConnectedEvent ev) {
                    foreach (i; 0 .. 4) {
                        if (players[i] && players[i].gamepadId == ev.id) {
                            log.write("gamepad %d is already connected as player %d", ev.id, i+1);
                            return true;
                        }
                        else if (!players[i]) {
                            auto id = cast(AgentId)(AgentId.PLAYER_1 + i);
                            auto agent = new Agent(PLAYER_SPAWN_POSITIONS[i], id);
                            gameState.agents ~= agent;
                            players[i] = ui.playerUI[i].player = new PlayerController(agent, gameState, ev.id);
                            log.write("Welcome player %d! (gamepad %d)", i + 1, ev.id);
                            return true;
                        }
                    }
                    return true;
                },
                (GamepadDisconnectedEvent ev) {
                    foreach (i; 0 .. 4) {
                        if (players[i] && players[i].gamepadId == ev.id) {
                            log.write("Player left: %d (gamepad %d)", i, ev.id);
                            players[i].agent.isAlive = false;
                            ui.playerUI[i].player = players[i] = null;
                            return true;
                        }
                    }
                    //throw new Exception(format("Not connected to gamepad %d", ev.id));
                    return true;
                },
                (FrameUpdateEvent ev) {
                    ev.dt = abs(ev.dt);

                    uint alivePlayers = 0, activePlayers = 0;
                    threadStats.timedCall("gamestate.update()", {
                        gameState.update(ev.dt);

                        float speed = 1.0;
                        foreach (player; players) {
                            if (player) {
                                if (player.agent && player.agent.isAlive)
                                    ++alivePlayers;
                                ++activePlayers;
                                player.update(ev.dt * gameState.simSpeed);

                                if (abs(1.0 - player.desiredSimSpeed) > abs(1.0 - speed)) {
                                    speed = player.desiredSimSpeed;
                                }
                            }
                        }
                        gameState.simSpeed = speed * gameState.baseSimSpeed;
                    });
                    threadStats.timedCall("gamestate.draw()", {
                        gameState.draw();
                    });
                    threadStats.timedCall("gamestate.ui()", {
                        ui.stats.text = format("%d agents\nspeed %0.2f\n%d / %d players", 
                            gameState.agents.length, gameState.simSpeed,
                            alivePlayers, activePlayers);
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
        foreach (player; players)
            if (player)
                player.handleEvent(event);
    }
}












































