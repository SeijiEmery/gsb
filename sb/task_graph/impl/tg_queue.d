module sb.taskgraph.impl.tg_queue;
import sb.taskgraph.impl.task;
import core.atomic;

private immutable size_t SEGMENT_SIZE = 256;
private class Segment (T...) {
    // Task range indices.
    //  next_insert: head insert index. May be atomically incremented or reset to 0, but not decremented.
    //  next_take:   first known index we may take from. Acts as a hint to prevent needless iteration cycles,
    //               but is non-critical and iterating from [0,next_insert) is still valid.
    //               May be incremented / reset; valid iff next_take <= next_insert < SEGMENT_SIZE.
    uint next_insert = 0, next_take = 0;

    // Task storage
    Task!T[SEGMENT_SIZE] items;

final:
    /// Try inserting a task. Succeeds iff capacity, etc.,
    bool insertTask (Task item) {
        uint ins;

        // Acquire index
        do {
            ins = next_insert;
            if (ins >= SEGMENT_SIZE)
                return false;
        } while (!cas(&next_insert, ins, ins+1));

        // And write task
        items[ins] = item;
        return true;
    }

    /// Try fetching a task to execute, finding the next available task that
    /// fullfills pred(task) and can be aquired using tryClaim. Essentially
    /// does a filtered reduce operation in a threadsafe manner and using
    /// atomic ops; returns either a pointer to a Task (if successful) or
    /// null (queue segment is empty or pred did not match any tasks). 
    ///
    Task* fetchTask (alias pred)() {
        Task* fetchRange (uint start, uint end) {
            for (auto i = start; i < end; ++i) {
                if (items[i].unclaimed && pred(items[i]) && items[i].tryClaim) {
                    // Update next_take index iff applicable
                    // TODO: better algorithm for this!
                    auto prev = atomicLoad(next_take);
                    if (i == prev+1)
                        atomicStore(next_take, i);
                    return &items[i];
                }
            }
            return null;
        }

        // Try acquiring task; this may take multiple calls to fetchRange() as
        // multiple insertions + fetches may be running concurrently, and our start
        // index (unimportant) and end index (critical!) of the task segment may be
        // changing between calls.
        auto front = next_take, last = next_insert;
        do {
            auto task = fetchRange(front, last);
            if (task)
                return task;

            // check insert index (may have changed while checking!)
            auto l2 = atomicLoad(next_insert);
            if (l2 == last)
                return null; // did not change

            // If did change (insertion), try checking subrange again
            front = last;
            last  = l2;
        } while (1);
    }
}

class TaskQueue (T...) {
    alias TS = Segment!T;




}





















