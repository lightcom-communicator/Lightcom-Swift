import Foundation

class Requests {
    public struct Register: Codable {
        public var publicKey: String
    }
    
    public struct Login: Codable {
        public var userId: String
        public var sharedSecret: String
    }
    
    public struct AccessToken: Codable {
        public var accessToken: String
    }
}
