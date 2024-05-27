import XCTest
@testable import Lightcom_Swift

final class Lightcom_SwiftTests: XCTestCase {
    func testExample() async throws {
        let client1 = try await LightcomClient(serverUrl: "http://localhost:8080")
        let client2 = try await LightcomClient(serverUrl: "http://localhost:8080")
        
        try await client1.sendMessageAndEncrypt(
            forUser: client2.userId,
            theirPublicKeyEncoded: client2.publicKeyEncoded,
            message: Message(content: "Hello world", mediaUrls: [])
        )
        
        try await client2.sendMessageAndEncrypt(
            forUser: client1.userId,
            theirPublicKeyEncoded: client1.publicKeyEncoded,
            message: Message(content: "Hello world2", mediaUrls: [])
        )
        
        let messages1 = try await client1.fetchMessagesAndDecrypt(forUser: client2.userId, theirPublicKeyEncoded: client2.publicKeyEncoded)
        let messages2 = try await client2.fetchMessagesAndDecrypt(forUser: client1.userId, theirPublicKeyEncoded: client1.publicKeyEncoded)
        
        XCTAssert(messages1[0].content == "Hello world2" && messages2[0].content == "Hello world")
    }
}
