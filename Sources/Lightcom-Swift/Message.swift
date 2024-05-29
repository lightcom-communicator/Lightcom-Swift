import Foundation
import LibCrypto
import Crypto

/// Object containing message
public class Message: Codable {
    /// Content of the message
    private(set) public var content: String
    /// Timestamp
    private(set) public var timestamp: Int64
    /// URLs to medias
    private(set) public var mediaUrls: [String]
    
    /// Initializes new message
    ///
    /// - Parameters:
    ///   - content: Message content
    ///   - mediaUrls: array containg URLs to medias
    ///
    /// - Returns: `Message` object instance
    public init(content: String, mediaUrls: [String]) {
        self.content = content
        self.timestamp = Int64(Date().timeIntervalSince1970)
        self.mediaUrls = mediaUrls
    }
    
    /// Decrypts message obtained from the lightcom server
    ///
    /// - Parameters:
    ///   - encryptedMessage: message from the server
    ///   - key: encryption key
    ///
    /// - Returns: `Message` object instance
    public static func decrypt(encryptedMessage: Responses.Message, key: SymmetricKey) throws -> Self {
        let decrypted = try AesGcm.decrypt(encryptedMessage.content, key: key)
        return try JSONDecoder().decode(Self.self, from: decrypted.data(using: .utf8)!)
    }
    
    /// Encrypts message
    ///
    /// - Parameters:
    ///   - from: User ID of the user which send message
    ///   - to: User ID of the user which this message will be sent to
    ///
    /// - Returns: `Responses.Message`
    public func encrypt(from: String, to: String, key: SymmetricKey) throws -> Responses.Message {
        return try Responses.Message(
            fromUser: from,
            toUser: to,
            content: AesGcm.encrypt(
                String(decoding: JSONEncoder().encode(self), as: UTF8.self),
                key: key
            )
        )
    }
}
