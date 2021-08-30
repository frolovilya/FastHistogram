import Foundation

/**
 An object that can be stored in a shared resource pool.
 */
public protocol PoolResource {
    var pool: SharedResourcePool<Self>? { get set }
    func release() -> Void
}

/**
 Pool of shared objects to be used synchronously by both GPU and CPU.
 */
public class SharedResourcePool<T> where T: PoolResource {
    
    private let semaphore: DispatchSemaphore
    private var resources: [T]
    // keep references to all resources
    private let allResources: [T]
    private let syncQueue = DispatchQueue(label: "SharedResourcePoolQueue", qos: .userInteractive)
    
    /**
     Init pool with given objects to share.
     
     - Parameter resources: array or objects this pool holds.
     */
    init(resources: [T]) {
        self.semaphore = DispatchSemaphore(value: resources.count)

        self.allResources = resources
        self.resources = resources
        for var resource in self.resources {
            resource.pool = self
        }
    }
    
    deinit {
        // signal to avoid dispatch_semaphore_dispose crash
        for _ in 0..<(allResources.count - resources.count) {
            self.semaphore.signal()
        }
    }
    
    /**
     Get next available object from the pool.
     
     If no objects avaiable at this moment, this method waits for some object to be released back to the pool.
     
     - Returns available object instance.
     */
    public var nextResource: T {
        semaphore.wait()
        
        return syncQueue.sync {
            let resource = resources.removeFirst()
            return resource
        }
    }
    
    /// Release object back to the pool.
    func release(resource: T) {
        syncQueue.sync {
            resources.append(resource)
            semaphore.signal()
        }
    }
    
}
