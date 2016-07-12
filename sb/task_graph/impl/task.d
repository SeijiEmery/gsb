module sb.taskgraph.impl.task;
import core.atomic;

private enum TaskStatus : ubyte { UNASSIGNED = 0, RUNNING, EXIT_OK, EXIT_FAILURE }

struct Task (T...) {
    void delegate(T) action;
    TaskStatus       state = TaskStatus.UNASSIGNED;

    // Try to claim ownership over this item; may not be run until/if this succeeds.
    // Uses an atomic CAS operation to maintain correct state across multiple threads.
    bool tryClaim () {
        return state == TaskStatus.UNASSIGNED &&
            cas(&state, TaskStatus.UNASSIGNED, TaskStatus.RUNNING);
    }
    bool unclaimed () { return state == TaskStatus.UNASSIGNED; }
    bool finished  () { return finished_ok || finished_with_error; }
    bool finished_ok () { return state == TaskStatus.EXIT_OK; }
    bool finished_with_error () { return state == TaskStatus.EXIT_FAILURE; }

    // Try running this item by executing it in a try-catch block. Returns null on
    // success (no thrown exceptions), or a Throwable if an error was caught while
    // executing. Modifies internal state using atomic operations.
    //
    // INVALID unless task was obtained using tryClaim and task has not yet been run.
    Throwable tryRun (T args) {
        assert(state == TaskStatus.RUNNING, 
            format("Invalid task state: %s (expected RUNNING)", state));
        try {
            action(args);
            atomicStore(state, TaskStatus.EXIT_OK);
            return null;
        } catch (Throwable e) {
            atomicStore(state, TaskStatus.EXIT_FAILURE);
            return e;
        }
    }

    // Reset this task's state so it can be run again. Uses atomic operations.
    void reset () {
        atomicStore(state, TaskStatus.UNASSIGNED);
    }
}





