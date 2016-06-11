module gsb.utils.checksum;

struct Checksum {
    static struct None {
        alias HashType = typeof(hash([]));
        static auto hash (ubyte[] bytes) { return 0; }
    }
    static struct Adler32 {
        alias HashType = typeof(hash([]));
        static ulong hash (ubyte[] bytes) {
            immutable uint mod = 65521;

            uint s0 = 1, s1 = 0;

            uint* data = cast(uint*)(bytes.ptr);
            for (auto i = bytes.length / 4; i --> 0; ) {
                s0 = (s0 + data[i]) % mod;
                s1 = (s0 + s1) % mod;
            }
            if (bytes.length % 4) {
                for (auto i = bytes.length % 4; i --> 0; ) {
                    s0 += bytes[$-i] << (i * 8);
                }
                s0 %= mod;
                s1 = (s1 + s0) % mod;
            }
            return cast(ulong)s0 + (cast(ulong)s1 << 32);
        }
    }
    static struct Xor64 {
        alias HashType = typeof(hash([]));
        static ulong hash (ubyte[] bytes) {
            ulong s = 0;
            ulong* data = cast(ulong*)(bytes.ptr);
            for (auto i = bytes.length / 8; i --> 0; ) {
                s ^= data[i];
            }

            if (bytes.length % 8) {
                ulong k = 0;
                for (auto i = bytes.length % 8; i --> 0; ) {
                    k = (k << 8) | bytes[$-i];
                }
                s ^= k;
            }
            return s;
        }
    }
    static struct CRC32 {    
        import std.digest.crc;

        alias HashType = typeof(hash([]));
        static auto hash (ubyte[] bytes) {
            return crc32Of(bytes);
        }
    }
}

static bool hashDiff (alias Hash : Checksum.None)(ref Hash.HashType prev, ubyte[] data) {
    return true;
}

static bool hashDiff (alias Hash)(ref Hash.HashType prev, ubyte[] data) {
    auto hash = Hash.hash(data);
    return hash != prev ?
        (prev = hash, true) : false;
}





