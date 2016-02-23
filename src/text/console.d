
module gsb.text.console;
import gsb.text.font;
import gl3n.linalg;
import std.math;
import std.utf;

class TextGeometryBuffer{}

// Really basic; we can worry about mvc later
class ConsoleRenderer {
    private string[] m_lines;
    private Font     m_font;
    private vec2     m_viewBounds;
    private vec2     m_viewPos;
    private vec2     m_scrollPos;
    TextGeometryBuffer[string] m_buffers;

    this (Font font, vec2 pos, vec2 bounds) {
        m_font = font;
        m_viewPos = pos;
        m_viewBounds = bounds;
        m_scrollPos = vec2(0, 0);
    }

    @property auto lineHeight () { return m_font.data.lineHeight; }
    size_t firstVisibleLine (float pixelTolerance) {
        auto n = (m_scrollPos.y - pixelTolerance) / lineHeight;
        return cast(size_t)(floor(max(n, 0)));
    }
    size_t lastVisibleLine (float pixelTolerance) {
        auto m = (m_scrollPos.y + m_viewBounds.y + pixelTolerance) / lineHeight;
        return cast(size_t)(ceil(min(m, m_lines.length - 1)));
    }

    void pushLines (string[] lines) {
        auto first = m_lines.length, last = first + lines.length - 1;
        m_lines ~= lines;
        // lines maybe need to be added...
    }
    @property void font (Font font) {
        m_font = font;
        // font changed -- rerender everything
    }
    @property void scrollPos (vec2 scroll) {
        // view changed -- add stuff or maybe rerender
    }
    @property void viewBounds (vec2 newBounds) {
        // view changed -- add stuff or maybe rerender
    }
    @property void viewPos (vec2 pos) {
        // view did not change, but we'll still need to update the graphics view so
        // it's drawing in the right position
    }

    void renderline (string line, vec2 position) {
        foreach (chr; line.byDchar) {

        }
    }





}



























