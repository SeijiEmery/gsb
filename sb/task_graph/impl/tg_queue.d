module sb.taskgraph.impl.tg_queue;
import sb.taskgraph.impl.task;
import core.atomic;

private immutable size_t SEGMENT_SIZE = 256;
private class Segment (T...) {
    // Task range indices.
    //  next_insert: head insert index. May be atomically incremented or reset to 0, but not decremented.
    //  acquired:    number of tasks that have been acquired by fetchTask; used to detect when segment 
    //       may be dropped/recycled, and when to update the fetch_head hint.
    //  fetch_head:  hint indicating the _minimum_ index to start searching for items with fetchTask()
    //       (all items before this will be skipped). Added for efficiency's sake: searching through
    //       [0, next_insert) is perfectly valid, but inefficient; if we can __guarantee__ that all items
    //       up to N have been acquired, then it's obviously more efficient to just search [N, next_insert),
    //       where N <= next_insert.
    //  
    uint next_insert = 0, acquired = 0, fetch_head = 0;

    @property auto remainingInserts () { return SEGMENT_SIZE - next_index; }
    @property auto remainingFetches () { 
        assert(next_insert >= acquired);
        return next_insert - acquired; 
    }
    void reset () {
        atomicStore(next_insert, 0);
        atomicStore(acquired, 0);
    }

    alias CTask = Task!T;

    // Task storage
    CTask[SEGMENT_SIZE] items;

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
    /// fullfills pred(task) and can be aquired using task.tryClaim. Essentially
    /// does a filtered reduce operation in a threadsafe manner using atomic ops; 
    /// returns either a pointer to a Task (if successful) or null (segment is empty 
    /// or pred did not match any tasks). 
    ///
    CTask* fetchTask (alias pred)() {
        CTask* fetchRange (uint start, uint end) {
            for (auto i = start; i < end; ++i) {
                if (items[i].unclaimed && pred(items[i]) && items[i].tryClaim) {

                    // Update acquire count and fetch_head
                    uint count;
                    do { count = atomicLoad(acquired);
                    } while (!cas(&acquired, count, count+1));

                    // If our acquire count matches our insert count, meaning that
                    // we're guaranteed NOT to have any claimable items before this one,
                    // then update our next_take hint so that all previous items are skipped.
                    //
                    // if (count == next_insert) fetch_head = i;
                    while (
                        count == atomicLoad(next_insert) &&
                        !cas( &fetch_head, fetch_head, i )) {}

                    return &items[i];
                }
            }
            return null;
        }

        // Try acquiring task; this may take multiple calls to fetchRange() as
        // multiple insertions + fetches may be running concurrently, and our start
        // index (unimportant) and end index (critical!) of the task segment may be
        // changing between calls.
        auto front = fetch_head, last = next_insert;
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





















