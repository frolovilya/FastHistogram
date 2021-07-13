import XCTest
@testable import FastHistogram

fileprivate final class TestPoolResource: PoolResource {
    let number: Int
    
    init(_ number: Int) {
        self.number = number
    }
    
    public weak var pool: SharedResourcePool<TestPoolResource>?

    public func release() -> Void {
        pool?.release(resource: self)
    }
}

final class SharedResourcePoolTests: XCTestCase {
    
    private var pool: SharedResourcePool<TestPoolResource>!
    
    override func setUpWithError() throws {
        pool = SharedResourcePool(resources: [
                                        TestPoolResource(1),
                                        TestPoolResource(2),
                                        TestPoolResource(3)
        ])
    }
    
    func testTakeAll() {
        XCTAssertEqual(pool.nextResource.number, 1)
        XCTAssertEqual(pool.nextResource.number, 2)
        XCTAssertEqual(pool.nextResource.number, 3)
    }
    
    func testTakeAndRelease() {
        _ = pool.nextResource
        let two = pool.nextResource
        _ = pool.nextResource
        
        two.release()
        XCTAssertEqual(pool.nextResource.number, 2)
    }
    
    func testTakeAndBlock() {
        _ = pool.nextResource
        _ = pool.nextResource
        _ = pool.nextResource
        
        let nextResourceObtained = expectation(description: "next resource obtained")
        nextResourceObtained.isInverted = true
        
        DispatchQueue.global().async {
            _ = self.pool.nextResource
            nextResourceObtained.fulfill()
        }
        
        wait(for: [nextResourceObtained], timeout: 1)
    }
    
    func testTakeAndReleaseAndUnblock() {
        _ = pool.nextResource
        _ = pool.nextResource
        let three = pool.nextResource
        
        let nextResourceObtained = expectation(description: "next resource obtained")
        nextResourceObtained.expectedFulfillmentCount = 1
        
        DispatchQueue.global().async {
            let next = self.pool.nextResource
            XCTAssertEqual(next.number, 3)
            nextResourceObtained.fulfill()
        }
        
        three.release()
        
        wait(for: [nextResourceObtained], timeout: 1)
    }
    
    static var allTests = [
        ("testTakeAll", testTakeAll),
        ("testTakeAndRelease", testTakeAndRelease),
        ("testTakeAndBlock", testTakeAndBlock),
        ("testTakeAndReleaseAndUnblock", testTakeAndReleaseAndUnblock),
    ]
}
