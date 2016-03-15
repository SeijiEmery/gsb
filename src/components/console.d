
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
    uint   textCursor, selectionLength = 0;
    vec2 padding = vec2(0, 0);
    float minWidth = 500.0;

    @property auto pos () { return tf.position - padding; }
    @property void pos (vec2 p) { tf.position = p; }
    @property auto dim () { 
        vec2 bounds = tf.bounds;
        if (bounds.x < minWidth)
            bounds.x = minWidth;
        return bounds + padding; 
    }

    @property auto fontSize () { return tf.font.size; }
    @property void fontSize (float size) {
        tf.font = new Font(tf.font.name, size);
    }

    this (string text, Font font, vec2 pos) {
        this.tf = new TextFragment(text, font, Color("#82fe7f"), pos);
        this.textContent = text.byDchar.array;
    }

    void insert (string text) {
        if (selectionLength)
            doDelete();
        textContent ~= text.byDchar.array;
        tf.text = textContent.toUTF8;
    }
    void doDelete () {
        if (textContent.length > 0) {
            textContent.length = max(0, textContent.length - (selectionLength ? selectionLength : 1));
            selectionLength = 0;

            tf.text = textContent.toUTF8;
        }
    }

    void moveCursor (int dir, bool keepSelection = false) {
        if (keepSelection) {
            selectionLength = max(0, selectionLength + dir);
        }
    }

    void selectAll () {
        textCursor = 0;
        selectionLength = cast(uint)textContent.length;
    }
}

private void drawLine (vec2 p1, vec2 p2, Color color) {
    DebugRenderer.drawLines([ p1, p2 ], color, 1.0, 4);
}

private class ConsoleModule : UIComponent {
    TextInputField textfield;
    TextFragment   autocompleteList;

    bool dragging = false;
    bool mouseover = false;
    bool hasFocus  = true;
    vec2 dragOffset;

    override void onComponentInit () {
        textfield = new TextInputField("hello world!", new Font(FONT, 30.0), vec2(100, 50));
        autocompleteList = new TextFragment("", new Font(FONT, 22.0), Color("#fe4f2f"), textfield.pos + vec2(0, textfield.dim.y));
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
                if (ev.pressed && mouseover) 
                    hasFocus = true;

                if (ev.pressed && ev.isRMB && mouseover)
                    dragging = true;
                else if (ev.released && ev.isRMB)
                    dragging = false;
            },
            (ScrollEvent ev) {
                if (mouseover)
                    textfield.fontSize = textfield.fontSize + ev.dir.y;
            },
            (TextEvent ev) {
                if (hasFocus)
                    textfield.insert(to!string(ev.text));
            },
            (KeyboardEvent ev) {
                if (!hasFocus)
                    return;

                if (ev.keystr == "DELETE")
                    textfield.doDelete();
                if (ev.keystr == "ESC")
                    hasFocus = false;
                if ((ev.cmd || ev.ctrl) && (ev.keystr == "a"))
                    textfield.selectAll();

                if (ev.keystr == "LEFT")
                    textfield.moveCursor(-1, ev.shift);
                if (ev.keystr == "RIGHT")
                    textfield.moveCursor(+1, ev.shift);


            },
            (FrameUpdateEvent ev) {
                auto color = hasFocus ? Color("#fefefe") : Color("#9f9f9f");
                auto a = textfield.pos, b = a + textfield.dim;

                drawLine(vec2(a.x, a.y), vec2(b.x, a.y), color);
                drawLine(vec2(b.x, a.y), vec2(b.x, b.y), color);
                drawLine(vec2(b.x, b.y), vec2(a.x, b.y), color);
                drawLine(vec2(a.x, b.y), vec2(a.x, a.y), color);
            },
            () {}
        )();
    }
}











