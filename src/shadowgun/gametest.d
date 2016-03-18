
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

class Player {
    vec2 position;

    this () {
        position = vec2(g_mainWindow.screenDimensions) * 0.5;
    }

    bool handleEvent (UIEvent event) {
        return false;
    }
    void draw () {
        DebugRenderer.drawCircle(position, 20.0, PLAYER_COLOR, circleWidth, 
            cast(uint)numCirclePoints, 2.0);
    }
}

private class GameModule : UIComponent {

    Player player;

    override void onComponentInit () {
        player = new Player();
    }
    override void onComponentShutdown () {
        player = null;
    }
    override void handleEvent (UIEvent event) {
        if (!player)
            return;

        event.handle!(
            (FrameUpdateEvent ev) {
                player.draw();
            },
            (ScrollEvent ev) {
                //numCirclePoints = max(3, numCirclePoints + ev.dir.y);
                //log.write("set circle points = %d", cast(uint)numCirclePoints);
                log.write("set circle width = %0.2f", circleWidth = max(0.0, circleWidth + ev.dir.y * 0.05));

                player.handleEvent(event);
            },
            () {
                player.handleEvent(event);
            }
        );
    }
}












































