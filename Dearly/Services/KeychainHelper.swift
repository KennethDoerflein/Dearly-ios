import Foundation
import Security

/// A simple wrapper for securely storing Codable data in the iOS Keychain.
final class KeychainHelper {
    static let shared = KeychainHelper()
    
    private init() {}
    
    func save<T: Codable>(_ item: T, service: String, account: String) {
        do {
            let data = try JSONEncoder().encode(item)
            let query = [
                kSecValueData: data,
                kSecClass: kSecClassGenericPassword,
                kSecAttrService: service,
                kSecAttrAccount: account
            ] as CFDictionary
            
            // Delete any existing item
            SecItemDelete(query)
            
            // Add new item
            SecItemAdd(query, nil)
        } catch {
            print("KeychainHelper: Failed to encode item for saving - \(error)")
        }
    }
    
    func read<T: Codable>(service: String, account: String, type: T.Type) -> T? {
        let query = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ] as CFDictionary
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query, &dataTypeRef)
        
        if status == errSecSuccess, let data = dataTypeRef as? Data {
            do {
                let item = try JSONDecoder().decode(type, from: data)
                return item
            } catch {
                print("KeychainHelper: Failed to decode item - \(error)")
                return nil
            }
        }
        return nil
    }
    
    func delete(service: String, account: String) {
        let query = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ] as CFDictionary
        
        SecItemDelete(query)
    }
}
