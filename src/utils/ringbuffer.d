
module gsb.utils.ringbuffer;


private size_t toBase2 (size_t sz) {
    return sz;
}


struct RingBuffer (T, size_t SIZE) {
    immutable size_t size = toBase2(SIZE);
    T[size] buffer;

    void push (ref T value) {
        buffer[getNext()] = value;
    }

    void consume (uint from) {

    }
}






































