
module gsb.coregl.batchpool;
import gsb.coregl.batch;
import core.sync.mutex;
import std.format;

private class BatchPool {
    private immutable auto THRESHOLD = 10; // 10 commands before batch sent
    private GLBatch currentBatch = null;
    private GLBatch[] pool;
    private Mutex mutex;
    private static ushort poolId = 0;
    private string poolName = null;
    private ushort next = 0;
    private ushort remaining = 0;
    private ushort pushCount = 0;
    private bool setupEof = false;

    this () {
        mutex = new Mutex();
    }
    abstract void submitBatch (GLBatch batch);
    abstract void processPostFrame ();

    void push (GLCommand cmd) {
        synchronized (mutex) {
            if (!currentBatch) {
                if (remaining) {
                    currentBatch = pool[next++];
                    remaining--;
                } else {
                    if (!poolName) {
                        poolName = format("pool %d", ++poolId);
                    }
                    currentBatch = new GLBatch(poolName);
                    pool ~= currentBatch;

                    if (!setupEof) {
                        setupEof = true;
                        GLCommandBuffer.instance.addEndOfFrameTask(0, &this.onEndFrame);
                    }
                }
                currentBatch.push(cmd);
            } else {
                currentBatch.push(cmd);
                if (++pushCount >= THRESHOLD) {
                    submitBatch(currentBatch);
                    currentBatch = null;
                    pushCount = 0;
                }
            }
        }
    }

    void onEndFrame () {
        synchronized (mutex) {
            processPostFrame();
            currentBatch = null;
            remaining = cast(ushort)pool.length;
            pushCount = 0;
            next = 0;
        }
    }
}

private BatchPool immedPool;
private @property auto localImmedPool () {
    return immedPool ? immedPool : immedPool = new class BatchPool {
        override void submitBatch (GLBatch batch) {
            GLCommandBuffer.instance.pushImmediate(batch);
        }
        override void processPostFrame () {
            if (currentBatch) {
                currentBatch.run();
            }
        }
    };
}

private BatchPool nextFramePool;
private @property auto localNextFramePool () {
    return nextFramePool ? nextFramePool : nextFramePool = new class BatchPool {
        override void submitBatch (GLBatch batch) {
            GLCommandBuffer.instance.pushNextFrame(batch);
        }
        override void processPostFrame () {
            if (currentBatch) {
                GLCommandBuffer.instance.pushImmediate(currentBatch);
            }
        }
    };
}

public void pushImmediate (GLCommandBuffer cbuf, GLCommand command) {
    localImmedPool.push(command);
}
public void pushNextFrame (GLCommandBuffer cbuf, GLCommand command) {
    localNextFramePool.push(command);
}











