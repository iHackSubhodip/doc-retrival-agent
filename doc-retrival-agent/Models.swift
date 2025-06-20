import Foundation

// MARK: - Chat Models
struct ChatMessage: Identifiable, Codable {
    var id = UUID()
    let content: String
    let isUser: Bool
    let timestamp: Date
    let sources: [DocumentSource]?
    
    init(content: String, isUser: Bool, sources: [DocumentSource]? = nil) {
        self.content = content
        self.isUser = isUser
        self.timestamp = Date()
        self.sources = sources
    }
}

struct DocumentSource: Identifiable, Codable {
    var id = UUID()
    let title: String
    let content: String
    let url: String?
    let score: Double
}

// MARK: - API Request/Response Models
struct ChatRequest: Codable {
    let message: String
    let context: String?
}

struct ChatResponse: Codable {
    let message: String
    let toolUsed: String?
    let sources: [DocumentSource]?
    let metadata: ResponseMetadata?
}

struct ResponseMetadata: Codable {
    let processingTime: Double
    let tokensUsed: Int?
    let model: String?
}

// MARK: - Tool Models
enum ToolType: String, CaseIterable {
    case documentRetrieval = "document_retrieval"
    case weatherInfo = "weather_info"
    
    var displayName: String {
        switch self {
        case .documentRetrieval:
            return "Document Search"
        case .weatherInfo:
            return "Weather Info"
        }
    }
    
    var description: String {
        switch self {
        case .documentRetrieval:
            return "Search through uploaded documents using RAG"
        case .weatherInfo:
            return "Get current weather information"
        }
    }
}

struct ToolCall: Codable {
    let type: String
    let parameters: [String: String]
}

// MARK: - Weather Models
struct WeatherResponse: Codable {
    let location: String
    let temperature: Double
    let description: String
    let humidity: Int
    let windSpeed: Double
}

// MARK: - Document Upload Models
struct DocumentUploadRequest: Codable {
    let fileName: String
    let content: String
    let contentType: String
}

struct DocumentUploadResponse: Codable {
    let success: Bool
    let documentId: String?
    let message: String
}

// MARK: - Error Models
struct APIError: Error, Codable {
    let message: String
    let code: String?
    let details: [String: String]?
}

extension APIError: LocalizedError {
    var errorDescription: String? {
        return message
    }
} 
