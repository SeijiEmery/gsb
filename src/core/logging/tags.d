
module gsb.core.logging.tags;



private alias TagIdType = ushort;

// Global tag db / registry. Associates each unique string tag w/ a unique integer
// id, allowing us to store the id instead of the tag itself. We also store this in
// thread-local data structures (lock-free), but we also need a global, shared structure 
// to ensure uniqueness and consistency of tag ids across all threads.
private struct TagDb {
    private Mutex mutex;
    private TagIdType[string] tagIds;
    private string[TagIdType] registeredTags;

    TagIdType getTagId (string tag) {
        synchronized (mutex) {
            if (tag !in tagIds) {
                tagIds[tag] = nextId;
                registeredTags[nextId] = tag;
                return nextId++;
            }
            return tagIds[tag];
        }
    }
    string getTagString (TagIdType id) {
        synchronized (mutex) {
            if (id in registeredTags)
                return registeredTags[id];
        }
        throw new Exception("No matching id store for %d! (internal error; fixme!)", id);
    }
}



// Thread-local tag storage + retrieval. Provides two functions:
// - symmetric push / pop interface for storing nested tag contexts (ie. you push 'graphics',
//   since this is the graphics thread, and then 'gl', since you're logging gl stuff, so your
//   tags are '[graphics][gl]').
// - stores a list of all encountered tags (and phones home to the global tag db object when
//   it encounters something new), and has the ability to convert string tags to / from integer
//   ids, and format lists of tags into a tag string (eg. '[graphics][gl]').
//
// Implementation-wise, we store two symmetric hashtables of string -> id and id -> string,
// with leave id creation to the global db (but cache it locally so we don't have to lock).
// We also store an additional 'level' integer in the id table, which is the nested level of its
// respective tag (a tag could be pushed / popped multiple times, so we need to support that
// behavior; in our impl, level == 0 => inactive tag, level > 0 => active tag, level < 0 => bug).
//
// We also store a bunch of cached data (the hashtables hold the real state), and this gets
// guarded by a dirty flag that gets set whenever push / pop is called.
//
// Finally, it's worth noting that this structure has no mutexes / locks whatsoever, as it's
// intended to be used purely in a thread-local context (hence the name).
//
private struct ThreadLocalTagTracker {
    struct TagInfo {
        TagIdType id;
        short level = 0;
    }
    private TagInfo[string]   trackedTagInfo;
    private string[TagIdType] registeredTags;

    private string[] cachedTagList;
    private TagIdType[] cachedTagIdList;
    private string cachedTagString = "";
    private bool dirtyTagList = false;

    void push (string tag) {
        if (tag in trackedTagInfo) {
            if (trackedTagInfo[tag].level++ <= 1)
                dirtyTagList = true;
        } else {
            auto id = globalTagDb.getTagId(tag);
            trackedTagInfo[tag] = TagInfo(id, 1);
            registeredTags[id]  = tag;
        }
    }
    void pop (string tag) {
        assert(tag in trackedTagInfo);
        if (--trackedTagInfo[tag] == 0)
            dirtyTagList = true;
    }

    void push (string[] tags) {
        foreach (tag; tags) push(tag);
    }
    void pop (string[] tags) {
        foreach (tag; tags) pop(tag);
    }

    private void updateTagList () {
        assert(dirtyTagList);
        dirtyTagList = false;

        cachedTagList.length = 0;
        cachedTagIdList.length = 0;
        foreach (info, tag; trackedTagInfo) {
            if (info.level > 1) {
                cachedTagList ~= tag;
                cachedTagIdList ~= tag.id;
            }
        }
    }

    string[] getTags () {
        if (dirtyTagList) 
            updateTagList();
        return cachedTagList;
    }
    TagIdType[] getTagIds () {
        if (dirtyTagList)
            updateTagList();
        return cachedTagIdList;
    }
    string getTagString () {
        return dirtyTagList ?
            cachedTagString = formatTagString(getTags()) :
            cachedTagString;
    }
    string getTagStringFromIds (TagIdType[] tagIds) {
        return formatTags(tagIds.map!((id) => registeredTags[id]; ));
    }
    private string formatTagString (string[] tags) {
        return tags.map!((t) => format("[%s]", t)).join("");
    }
}

