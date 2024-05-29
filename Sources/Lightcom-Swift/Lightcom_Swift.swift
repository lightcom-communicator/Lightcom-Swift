// The Swift Programming Language
// https://docs.swift.org/swift-book

import LibCrypto
import hsauth_swift
import Foundation

/// Lightcom client object
public class LightcomClient {
    private var requester: Requester
    private var serverUrl: String
    
    /// User ID
    private(set) public var userId: String
    /// Private key encoded in hex
    private(set) public var privateKeyEncoded: String
    /// Public key encoded in hex
    private(set) public var publicKeyEncoded: String
    /// Access token
    private(set) public var accessToken: String = ""
    
    /// Initializes new client object and registers a new account
    ///
    /// - Parameter serverUrl: URL address to the lightcom server
    /// - Returns: `LightcomClient` object instance
    public init(serverUrl: String) async throws {
        self.serverUrl = (serverUrl.hasPrefix("http")) ? String(serverUrl.dropFirst(4)) : serverUrl
        self.requester = Requester(serverUrl: "http" + self.serverUrl)
        
        let privateKey = Data(generateRandomBytesArray())
        self.privateKeyEncoded = Hex.toHexString(privateKey)
        self.publicKeyEncoded = try X25519.fromPrivateKey(privateKey: self.privateKeyEncoded).publicKey
        
        // Registering
        let response: Responses.Register = try await self.requester.parseAndRequestAndParse(
            endpoint: "/register",
            method: "PUT",
            body: Requests.Register(publicKey: self.publicKeyEncoded)
        )
        
        self.userId = response.userId
        
        try await self.logIn()
    }
    
    /// Initializes new client object for an existing account, creates a new access token
    ///
    /// - Parameters:
    ///   - serverUrl: URL address to the lightcom server
    ///   - userId: User's ID
    ///   - privateKeyEncoded: User's private key encoded in hex
    ///
    /// - Returns: `LightcomClient` object instance
    public init(serverUrl: String, userId: String, privateKeyEncoded: String) async throws {
        self.serverUrl = (serverUrl.hasPrefix("http")) ? String(serverUrl.dropFirst(4)) : serverUrl
        self.requester = Requester.init(serverUrl: self.serverUrl)
        self.userId = userId
        self.privateKeyEncoded = privateKeyEncoded
        self.publicKeyEncoded = try X25519.fromPrivateKey(privateKey: self.privateKeyEncoded).publicKey
        
        try await self.logIn()
    }
    
    /// Initializes new client object for an existing account, uses an existing access token
    ///
    /// - Parameters:
    ///   - serverUrl: URL address to the lightcom server
    ///   - userId: User's ID
    ///   - privateKeyEncoded: User's private key encoded in hex
    ///   - accessToken: accessToken
    ///
    /// - Returns: `LightcomClient` object instance
    public init(serverUrl: String, userId: String, privateKeyEncoded: String, accessToken: String) throws {
        self.serverUrl = (serverUrl.hasPrefix("http")) ? String(serverUrl.dropFirst(4)) : serverUrl
        self.requester = Requester.init(serverUrl: self.serverUrl, accessToken: accessToken)
        self.userId = userId
        self.privateKeyEncoded = privateKeyEncoded
        self.publicKeyEncoded = try X25519.fromPrivateKey(privateKey: self.privateKeyEncoded).publicKey
    }
    
    private func logIn() async throws {
        let response: Responses.PublicKey = try await self.requester.requestAndParse(endpoint: "/publicKey", method: "GET", body: nil)
        let serverPublicKey = response.publicKey
        
        let sharedSecret = try KeyV1.init(ourPrivateKey: self.privateKeyEncoded, theirPublicKey: serverPublicKey).getKey()
        let response2: Responses.Login = try await self.requester.parseAndRequestAndParse(
            endpoint: "/login",
            method: "POST",
            body: Requests.Login(userId: self.userId, sharedSecret: sharedSecret)
        )
        
        self.accessToken = response2.accessToken
        self.requester.setAccessToken(accessToken: self.accessToken)
    }
    
    /// Get some info about who sent us some messages
    ///
    /// - Returns: dictionary `[userId : number of new messages]`
    public func newMessages() async throws -> [String: Int] {
        return try await self.requester.requestAndParse(endpoint: "/new", method: "GET", body: nil)
    }
    
    /// Open connection to the server which informs if we got a message
    ///
    /// - Parameter onMessage: callback
    public func newMessages(onMessage: @escaping (_: [String: Int]) -> ()) throws -> Websocket {
        let accessTokenRequest = try JSONEncoder().encode(Requests.AccessToken(accessToken: self.accessToken))
        
        let websocket = Websocket(url: "ws" + self.serverUrl + "/newWS", onReceive: { data, string in
            guard let parsedJSON = try? JSONDecoder().decode(
                [String: Int].self,
                from: data != nil ? data! : string!.data(using: .utf8)!
            ) else {
                return
            }
            
            onMessage(parsedJSON)
        })
        
        websocket.send(message: accessTokenRequest)
        
        return websocket
    }
    
    /// Fetch messages from a specific user
    ///
    /// - Parameter forUser: ID of the user which sent us messages
    /// - Returns: array of `Responses.Message` (encrypted messages)
    public func fetchMessages(forUser userId: String) async throws -> [Responses.Message] {
        return try await self.requester.requestAndParse(endpoint: "/fetch/" + userId, method: "GET", body: nil)
    }
    
    /// Fetch messages from a specific user and decrypt them
    ///
    /// - Parameters:
    ///   - forUser: ID of the user which sent us messages
    ///   - theirPublicKeyEncoded: Public key encoded in hex
    ///
    /// - Returns: array of `Message` objects containg decrypted data
    public func fetchMessagesAndDecrypt(forUser userId: String, theirPublicKeyEncoded: String) async throws -> [Message] {
        let sharedSecret = try X25519.computeSharedSecret(ourPrivate: self.privateKeyEncoded, theirPublic: theirPublicKeyEncoded)
        let response = try await self.fetchMessages(forUser: userId)
        var messages: [Message] = []
        for message in response {
            messages.append(try Message.decrypt(encryptedMessage: message, key: sharedSecret))
        }
        
        return messages
    }
    
    /// Send message to a specific user
    ///
    /// - Parameters:
    ///   - forUser: ID of the user which message will be sent to
    ///   - message: encrypted message presented as `Response.Message`
    public func sendMessage(forUser destination: String, message: Responses.Message) async throws {
        if message.fromUser != self.userId {
            throw LightcomErrors.InvalidMessage
        }
        
        _ = try await self.requester.parseAndRequest(endpoint: "/send", method: "PUT", body: message)
    }
    
    /// Send message to a specific user
    ///
    /// - Parameters:
    ///   - forUser: ID of the user which message will be sent to
    ///   - theirPublicKeyEncoded: user's public key
    ///   - message: unencrypted message
    public func sendMessageAndEncrypt(forUser destination: String, theirPublicKeyEncoded: String, message: Message) async throws {
        let sharedSecret = try X25519.computeSharedSecret(ourPrivate: self.privateKeyEncoded, theirPublic: theirPublicKeyEncoded)
        let encryptedMessage = try message.encrypt(from: self.userId, to: destination, key: sharedSecret)
        
        try await self.sendMessage(forUser: destination, message: encryptedMessage)
    }
    
    public enum LightcomErrors: Error, LocalizedError {
        case InvalidMessage
        
        public var errorDescription: String? {
            switch self {
            case .InvalidMessage:
                return "Invalid message"
            }
        }
    }
}
