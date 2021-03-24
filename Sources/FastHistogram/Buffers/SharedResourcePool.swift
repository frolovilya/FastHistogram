import Foundation

public protocol PoolResource {
    var pool: SharedResourcePool<Self>? { get set }
    func release() -> Void
}

public class SharedResourcePool<T> where T: PoolResource {
    
    private let semaphore: DispatchSemaphore
    private var resources: [T]
    private let syncQueue = DispatchQueue(label: "SharedResourcePoolQueue", qos: .userInteractive)
    
    public init(resources: [T]) {
        self.semaphore = DispatchSemaphore(value: resources.count)

        self.resources = resources
        for var resource in self.resources {
            resource.pool = self
        }
    }
    
    public var nextResource: T {
        semaphore.wait()
        
        return syncQueue.sync {
            let resource = resources.removeFirst()
            return resource
        }
    }
    
    func release(resource: T) {
        syncQueue.sync {
            resources.append(resource)
            semaphore.signal()
        }
    }
    
}
