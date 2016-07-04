module sb.threading.interface.thread_worker;
module sb.threading.interface.thread_enums;

/// Abstraction of a thread worker implementation, assigned + run by the a threading context.
/// Examples include the sb main thread, graphics thread, audio thread, and various worker threads.
/// Inter-thread messaging is done via the thread context and that and the inner thread loop,
/// exception catching, thread termination, etc., is handled by the threading implementation,
/// not user code.
///
/// An IThreadWorker implementation should NOT include the following:
/// - a run loop inside doThreadWork (this will potentially block the thread and break 
///   most sb.threading features)
/// - stateful and/or memory sharing code to interface with other threads
/// - non-recoverable error handling code
/// - thread pause / start / yield code
/// (the last 3 are handled by the sb.threading impl)
///
interface IThreadWorker {
    /// Called when thread / thread worker starts up.
    void onThreadStart (SbThreadId thisThreadId);

    /// Called when thread / thread worker terminates (includes caught exceptions)
    void onThreadEnd   ();

    /// Called when thread may process work.
    /// Thread should execute a single work item + return; run loop is handled
    /// by threading infrastructure and a long or many work cycles will interrupt
    /// the threading message system. (messages are polled automatically)
    void doThreadWork  ();

    /// Called when thread enters a new frame.
    /// Thread should not execute work items, but wait for next doThreadWork() call.
    void onThreadNextFrame ();
}
