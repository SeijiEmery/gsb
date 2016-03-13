
module gsb.components.console;
import gsb.gl.debugrenderer;
import gsb.core.uimanager;
import gsb.core.uievents;
import gsb.core.log;
import gsb.core.stats;
import gsb.core.window;
import gsb.text.textrenderer;
import gsb.text.font;

import gl3n.linalg;
import gsb.core.color;
import core.time;
import std.utf;
import std.array;

private immutable string FONT = "menlo";


shared static this () {
    UIComponentManager.runAtInit({
        UIComponentManager.registerComponent(new ConsoleModule(), "console", true);
    });
}

private bool inBounds (vec2 pos, vec2 p1, vec2 p2) {
    return !(pos.x < p1.x || pos.x > p2.x || pos.y < p1.y || pos.y > p2.y);
}

private class TextInputField {
    TextFragment tf;
    dchar[] textContent;
    uint   textCursor;
    vec2 padding = vec2(10, 10);

    @property auto pos () { return tf.position / 2.0 - padding; }
    @property void pos (vec2 p) { tf.position = p * 2.0; }
    @property auto dim () { return tf.bounds / 2.0 + padding * 2.0; }

    @property auto fontSize () { return tf.font.size; }
    @property void fontSize (float size) {
        tf.font = new Font(tf.font.name, size);
    }

    this (string text, Font font, vec2 pos) {
        this.tf = new TextFragment(text, font, Color("#82fe7f"), pos * 2.0);
        this.textContent = text.byDchar.array;
    }

    void render () {
        //drawLine(pos * 2.0, (pos + dim) * 2.0, Color("#df2f4f"));
    }

    void insert (string text) {
        textContent ~= text.byDchar.array;
        tf.text = textContent.toUTF8;
    }
    void deleteOnce () {
        if (textContent.length > 0) {
            textContent.length -= 1;
            tf.text = textContent.toUTF8;
        }
    }
}

private void drawLine (vec2 p1, vec2 p2, Color color) {
    DebugRenderer.drawLines([ p1, p2 ], color, 1.0, 4);
}

private class ConsoleModule : UIComponent {
    TextInputField textfield;

    bool dragging = false;
    bool mouseover = false;
    bool hasFocus  = false;
    vec2 dragOffset;

    override void onComponentInit () {
        textfield = new TextInputField("hello world!", new Font(FONT, 22.0), vec2(100, 100));
    }
    override void onComponentShutdown () {}
    override void handleEvent (UIEvent event) {
        event.handle!(
            (MouseMoveEvent ev) {
                if (!dragging) {
                    vec2 a = textfield.pos, b = textfield.pos + textfield.dim;
                    mouseover = inBounds(ev.position, a, b);
                    dragOffset = ev.position - textfield.pos;
                } else {
                    textfield.pos = ev.position - dragOffset;
                }
            },
            (MouseButtonEvent ev) {
                if (ev.pressed && mouseover) { 
                    dragging = true; 
                    hasFocus = true;
                } else if (ev.released) {
                    dragging = false;          
                } else if (ev.pressed && !mouseover) {
                    hasFocus = false;
                }
            },
            (ScrollEvent ev) {
                if (mouseover)
                    textfield.fontSize = textfield.fontSize + ev.dir.y;
            },
            (TextEvent ev) {
                textfield.insert(to!string(ev.text));
            },
            (KeyboardEvent ev) {
                log.write(ev.keystr);
                if (ev.keystr == "DELETE") {
                    textfield.deleteOnce();
                }
            },
            (FrameUpdateEvent ev) {
                drawLine(textfield.pos, (textfield.pos + textfield.dim),
                    mouseover ? Color("#4ffe3f") : hasFocus ? Color("#2f2fff") : Color("#fe3f4f"));


                textfield.render();
            },
            () {}
        )();
    }
}











