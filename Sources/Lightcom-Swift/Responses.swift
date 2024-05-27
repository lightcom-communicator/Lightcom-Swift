import Foundation

public class Responses {
    public struct PublicKey: Codable {
        public var publicKey: String
    }
    
    public struct Register: Codable {
        public var userId: String
    }
    
    public struct Login: Codable {
        public var accessToken: String
        public var validUntil: Int64
    }
    
    public struct Message: Codable {
        public var fromUser: String
        public var toUser: String
        public var content: String
    }
}
