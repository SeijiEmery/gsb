
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
float DEFAULT_AGENT_MOVE_SPEED = 20.0;
float AGENT_SIZE = 1.0;


float CURRENT_SCALE_FACTOR = 1.0;

private mat3 gameToScreenSpaceTransform (float zoom = 1.0) {
    float s = CURRENT_SCALE_FACTOR = zoom / GAME_UNITS_PER_SCREEN * g_mainWindow.screenDimensions.x;
    return mat3.identity()
        .scale(s, s, 1.0)
        .translate(vec3(vec2(g_mainWindow.screenDimensions) * 0.5, 0.0));

}





interface IGameController { void handleEvent (UIEvent event); }
interface IGameSystem     { void run (GameState state); }
interface IGameRenderable { void draw (mat3 transform); }

private class Agent : IGameRenderable {
    Color color = ENEMY_COLOR;

    vec2 position = vec2(0, 0);
    vec2 dir;

    void update (float speed) {
        //log.write("update: %s + %s * %0.2f (%s) = %s", position, dir, speed * DEFAULT_AGENT_MOVE_SPEED, dir * speed * DEFAULT_AGENT_MOVE_SPEED, 
        //    position + dir * speed * DEFAULT_AGENT_MOVE_SPEED);
        position += dir * speed * DEFAULT_AGENT_MOVE_SPEED;
    }
    void draw (mat3 transform) {
        auto tpos = transform * vec3(position, 1.0);
        DebugRenderer.drawCircle(tpos.xy, AGENT_SIZE * CURRENT_SCALE_FACTOR, PLAYER_COLOR, circleWidth, 
            cast(uint)numCirclePoints, 2.0);

        log.write("draw: %s * transform = %s, size: %s * %0.2f = %s", position, tpos, AGENT_SIZE, CURRENT_SCALE_FACTOR, AGENT_SIZE * CURRENT_SCALE_FACTOR);
    }
}



private class GameState {
    IGameSystem[] systems;
    Agent   player;
    Agent[] agents;
    float simSpeed = 1.0;
    float zoom = 1.0;

    this (IGameSystem[] systems, Agent player, Agent[] agents) {
        this.systems = systems;
        this.agents = [ player ] ~ agents;
        this.player = player;
    }

    void update (float dt = 1 / 60.0) {
        foreach (system; systems)
            system.run(this);
        foreach (agent; agents)
            agent.update(simSpeed * dt);
    }

    void draw () {
        auto transform = gameToScreenSpaceTransform(zoom);
        foreach (agent; agents)
            agent.draw(transform);
    }
}

private class PlayerController : IGameController {
    Agent player;
    this (Agent agent) {
        agent.color = PLAYER_COLOR;
        this.player = agent;
    }

    void handleEvent (UIEvent event) {
        event.handle!(
            (GamepadAxisEvent ev) {
                player.dir = vec2(ev.AXIS_LX, ev.AXIS_LY);
            },
            () {});
    }
}

private class GameModule : UIComponent {
    IGameController[] controllers;
    GameState gameState;

    override void onComponentInit () {
        auto player = new Agent();
        controllers ~= new PlayerController(player);

        gameState = new GameState([], player, []);
    }
    override void onComponentShutdown () {
        controllers.length = 0;
        gameState = null;
    }
    override void handleEvent (UIEvent event) {
        if (controllers.length) {
            event.handle!(
                (FrameUpdateEvent ev) {
                    gameState.update();
                    gameState.draw();
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












































