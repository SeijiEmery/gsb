module gsb.core.task.task_graph;
import gsb.core.task.task_listener;


private template mixin TGNode(T) {
    T* child;
    T* prev, next;  // prev / next siblings

    void appendChild (T* node) {
        if (!child) {
            child = node;
        } else {
            auto p = child;
            while (p.next)
                p = p.next;
            p.next = node;
            node.prev = p;
            node.next = null;
        }
    }
}













