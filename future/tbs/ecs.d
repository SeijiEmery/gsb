

// A pseudo-allocator for struct objects that:
// - allocates from a chain of fixed size blocks
// - keeps a freelist to reuse released object memory
// - has the ability to iterate over all allocated objects
// - does NOT mutate memory addresses, so the allocated obj can be safely
//   passed around as a pointer so long as the BCL remains in scope.
//
// Or in other words, it's an object pool that allows iterating over its contents.
// 
// And as it happens, it's near perfect for implementing the component portion
// of an entity component system: the entity keeps lazily initialized pointers
// to its components, that free themselves on exit, and the components get stored
// in tightly packed arrays to be iterated over by ECS systems.
// 
class BlockChainList (T, size_t BUCKET_COUNT) {
    private static class Bucket {
        Bucket          prev;
        size_t          next = 0;
        T[BUCKET_COUNT] elements;

        this (Bucket prev) { this.prev = prev; }
    }
    auto front = new Bucket(null);
    T*[] freelist;

    T* alloc () {
        if (freelist.length) {
            auto v = freelist[$-1]; freelist.length--;
            return v;
        }
        if (front.next >= BUCKET_COUNT)
            front = new Bucket(front);
        return &front.elements[front.next++];
    }
    void free (T* v) { freelist ~= v; }
    void releaseAll () {
        front.prev = null;
        front.next = 0;
        freelist.length = 0;
    }

    // Range interface
    private static struct FwdRange {
        Bucket bucket; size_t index;

        T* front () { return &bucket.elements[index]; }
        void popFront () {
            if (++index >= bucket.next) {
                index = 0;
                bucket   = bucket.prev;
            }
        }
        bool empty () { return bucket is null; }
        auto save  () { return FwdRange(bucket, index); }
    }
    auto iter () { return FwdRange(front.next ? front : front.prev, 0); }
}

class ECSComponentManager (T) {
    mixin LowLockSingleton;
    BlockChainList!(T,2048) componentList;

    T* create () {
        auto component = emplace(componentList.alloc);
        component.id   = 1;
        return component;
    }
    void remove (T* component) { component.id = 0; componentList.free(component); }
    auto iter () { return componentList.iter.filter!"a.id"; }
}
mixin template ECSBaseComponent (EntityId = uint) {
    EntityId id = 0;
}
struct ECSComponent (T) {
    T* ptr = null;

    bool exists () { return ptr !is null; }
    T*   get    () { return ptr ? ptr : ptr = ECSComponentManager!(T).instance.create(); }
    void remove () { if (ptr) ECSComponentManager!(T).instance.remove(ptr); ptr = null; }
    auto iter   () { return ECSComponentManager!(T).instance.iter(); }
}

void example () {
    struct TransformComponent {
        mixin ECSBaseComponent;
        float x, y, z, theta;

        void set (float x, float y, float z, float theta) {
            this.x = x; this.y = y; this.z = z; theta = theta;
        }
    }
    struct PhysicsComponent {
        mixin ECSBaseComponent;
        float dx, dy, dz, damping;
    }
    struct MyEntity {
        this (float x, float y, float z, float theta, float damping) {
            transform.get.set(x, y, z, theta)
            physics.get.damping = damping;
        }
        ECSComponent!TransformComponent transform;
        ECSComponent!PhysicsComponent   physics;

        ~this () { transform.remove(); physics.remove(); }
    }
    class PhysicsSystem () {
        void execFrame (MyEntity[] entities, float dt) {
            foreach (entity; entities) {
                auto transform = entity.transform.get();
                auto physics   = entity.physics.get();

                transform.x += physics.dx * dt; 
                transform.y += physics.dy * dt; 
                transform.z += physics.dz * dt;

                auto damp = physics.damping * dt;
                physics.dx *= damp;
                physics.dy *= damp;
                physics.dz *= damp;
            }
        }
    }

    MyEntity[] entities;
    auto physics = new PhysicsSystem();

    entities ~= MyEntity(1, 2, 4, 0, 0.9);
    entities[$-1].physics.get.dx = 10;

    entities ~= MyEntity(2, 4, 8, 0, 0.1);

    physics.execFrame(entities, 1.0 / 60.0);
    physics.execFrame(entities, 1.0 / 35.0);
    assert(abs(entities[0].transform.get.x - 1.70952) < 1e-4);
}








