import Foundation

class Requester {
    private var accessToken: String?
    private var serverUrl: String
    
    public init(serverUrl: String) {
        self.serverUrl = serverUrl
    }
    
    public func setAccessToken(accessToken: String) {
        self.accessToken = accessToken
    }
    
    public convenience init(serverUrl: String, accessToken: String) {
        self.init(serverUrl: serverUrl)
        self.accessToken = accessToken
    }
    
    public func request(endpoint: String, method: String, body: Data?) async throws -> Data {
        guard let url = URL(string: self.serverUrl + endpoint) else {
            throw RequesterErrors.InvalidUrl
        }
        
        var request = URLRequest(url: url)
        if let accessToken = self.accessToken {
            request.setValue(accessToken, forHTTPHeaderField: "Authorization")
        }
        request.httpMethod = method
        request.httpBody = body
        
        let (body, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse else {
            throw RequesterErrors.UnknownResponse
        }
        
        guard response.statusCode >= 200 && response.statusCode < 300 else {
            guard let error = try? JSONDecoder().decode(RequesterErrors.ApiError.self, from: body) else {
                throw RequesterErrors.UnknownResponse
            }
            
            throw RequesterErrors.Not20XStatusCode(statusCode: response.statusCode, body: error)
        }
        
        return body
    }
    
    public func parseAndRequest<T: Encodable>(endpoint: String, method: String, body: T) async throws -> Data {
        let body = try JSONEncoder().encode(body)
        return try await self.request(endpoint: endpoint, method: method, body: body)
    }
    
    public func parseAndRequestAndParse<T: Decodable, D: Encodable>(endpoint: String, method: String, body: D) async throws -> T {
        let body = try JSONEncoder().encode(body)
        return try await self.requestAndParse(endpoint: endpoint, method: method, body: body)
    }
    
    public func requestAndParse<T: Decodable>(endpoint: String, method: String, body: Data?) async throws -> T {
        let response = try await self.request(endpoint: endpoint, method: method, body: body)
        return try JSONDecoder().decode(T.self, from: response)
    }
}

public enum RequesterErrors: Error, LocalizedError {
    public struct ApiError: Codable {
        public var error: String
    }
    
    case Not20XStatusCode(statusCode: Int, body: ApiError)
    case UnknownResponse
    case InvalidUrl
    case Other(message: String)
    
    public var errorDescription: String? {
        switch self {
        case .Not20XStatusCode(let statusCode, let body):
            return String(statusCode) + ": " + body.error
        case .UnknownResponse:
            return "Unknown response"
        case .InvalidUrl:
            return "Invalid URL"
        case .Other(let message):
            return message
        }
    }
}
