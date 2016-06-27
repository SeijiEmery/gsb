module gsb.core.text2.glyphtexture;
import std.typecons: Tuple, tuple;
import gsb.core.text2.font;
import gl3n.linalg;


class GlyphTextureInstance {
    SuperCrappyPacker packer;

    void clear () { packer.reset(); }
    void insert (GlyphInfo*[] glyphs, float totalAreaHint) {
        packer.insert(glyphs, totalAreaHint);
    }
}

private struct SuperCrappyPacker {
    auto immutable      SIZE = 1024;
    immutable float  SIZE_INV = 1.0 / SIZE;
    immutable double SIZE_2_INV = 1.0 / (SIZE * SIZE);
    immutable double SIZE_2     = SIZE * SIZE;

    struct PTexture {
        uint         tx = 0, ty = 0, maxh = 0;
        ubyte[]      bitmap;
        Tuple!(GlyphInfo*,vec2i)[] toRender;
        ushort       texid;
        double       areaPct = 0.0;   // percent area used

        this (ushort texid) {
            this.texid = texid;
            bitmap.length = SIZE * SIZE;
        }

        bool insert (GlyphInfo* glyph) {
            if (glyph.dim.x > SIZE || glyph.dim.y > SIZE) {
                glyph.texid = 0;
                return true;
            }
            if (tx + glyph.dim.x > SIZE)
                (tx = 0), (ty += maxh), (maxh = 0);
            if (ty + glyph.dim.y > SIZE)
                return false;

            glyph.uv0   = vec2(tx * SIZE_INV, ty * SIZE_INV);
            glyph.texid = texid;
            toRender ~= tuple(glyph, vec2i(tx,ty));
            tx += glyph.dim.x + 1;
            if (glyph.dim.y > maxh)
                maxh = glyph.dim.y;
            areaPct += SIZE_2_INV * glyph.dim.x * glyph.dim.y;

            return true;
        }
        void reset () {
            tx = ty = maxh = 0;
            toRender.length = 0;
            areaPct = 1.0;
        }
    }
    PTexture[] m_textures;
    float      m_optTau = 0; // optimal texture area usage

    void insert (GlyphInfo*[] glyphs, float areaHint) {
        glyphs.sort!"a.dim.y > b.dim.y";

        uint i = 0;
        foreach (glyph; glyphs) {
            if (!m_textures[i].insert(glyph) && ++i >= m_textures.length)
                m_textures ~= PTexture(cast(ushort)m_textures.length);
        }
        float tau = 0;
        foreach (ref texture; m_textures) {
            tau += texture.areaPct;
            if (texture.toRender.length) {
                foreach (vpair; texture.toRender) {
                    auto glyph = vpair[0];
                    auto pos   = vpair[1];
                    glyph.renderBitmap(pos, texture.bitmap, vec2i(SIZE,SIZE));
                }
                texture.toRender.length = 0;
            }
        }

        m_optTau += areaHint * SIZE_2_INV;
        log.write("Using %s / %s area: %s efficiency", tau, m_optTau, m_optTau / tau);
    }
    void clear () {
        m_optTau = 0;
        foreach (texture; m_textures)
            texture.reset();
    }
}





