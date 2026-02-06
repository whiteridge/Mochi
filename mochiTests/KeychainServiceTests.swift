import Testing
import Foundation
@testable import mochi

struct KeychainServiceTests {
    
    let service = KeychainService.shared
    
    @Test func testSaveAndRead() {
        let key = "test_key_\(UUID().uuidString)"
        let value = "test_secret_value"
        
        // Test Save
        try? service.delete(key: key) // Cleanup just in case
        try? service.save(value, for: key)
        
        // Test Read
        let retrieved = service.read(key: key)
        #expect(retrieved == value)
        
        // Cleanup
        try? service.delete(key: key)
    }
    
    @Test func testUpdate() {
        let key = "test_update_key_\(UUID().uuidString)"
        let originalValue = "original"
        let updatedValue = "updated"
        
        try? service.save(originalValue, for: key)
        
        try? service.update(updatedValue, for: key)
        
        let retrieved = service.read(key: key)
        #expect(retrieved == updatedValue)
        
        // Cleanup
        try? service.delete(key: key)
    }
    
    @Test func testDelete() {
        let key = "test_delete_key_\(UUID().uuidString)"
        let value = "to_be_deleted"
        
        try? service.save(value, for: key)
        
        try? service.delete(key: key)
        
        let retrieved = service.read(key: key)
        #expect(retrieved == nil)
    }
}
