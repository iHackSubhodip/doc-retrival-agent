import Foundation

class APIService: ObservableObject {
    static let shared = APIService()
    
    // API Configuration - These will be updated via updateConfiguration
    private var openAIAPIKey = ""
    private var vectorizeAPIKey = ""
    private var vectorizePipelineURL = ""
    private var weatherAPIKey = ""
    
    private let session = URLSession.shared
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
    
    private init() {
        decoder.dateDecodingStrategy = .iso8601
        encoder.dateEncodingStrategy = .iso8601
        
        // Load saved configuration on init
        loadSavedConfiguration()
    }
    
    private func loadSavedConfiguration() {
        openAIAPIKey = UserDefaults.standard.string(forKey: "openai_api_key") ?? ""
        vectorizeAPIKey = UserDefaults.standard.string(forKey: "vectorize_api_key") ?? ""
        vectorizePipelineURL = UserDefaults.standard.string(forKey: "vectorize_pipeline_url") ?? ""
        weatherAPIKey = UserDefaults.standard.string(forKey: "weather_api_key") ?? ""
    }
    
    // MARK: - OpenAI Chat API
    func sendMessage(_ message: String, context: String? = nil) async throws -> ChatResponse {
        guard !openAIAPIKey.isEmpty else {
            throw APIError(message: "OpenAI API key not configured", code: "MISSING_API_KEY", details: nil)
        }
        
        // Validate API key format
        guard openAIAPIKey.hasPrefix("sk-") && openAIAPIKey.count > 20 else {
            throw APIError(message: "Invalid OpenAI API key format. API keys should start with 'sk-' and be longer than 20 characters. Please check your key at https://platform.openai.com/api-keys", code: "INVALID_API_KEY", details: nil)
        }
        
        // First, search for relevant documents
        let documents = try await searchDocuments(query: message)
        
        // Format context from retrieved documents
        let retrievedContext = documents.map { doc in
            "Title: \(doc.title)\nContent: \(doc.content)"
        }.joined(separator: "\n\n")
        
        // Prepare messages for OpenAI
        var messages: [[String: Any]] = []
        
        if !retrievedContext.isEmpty {
            messages.append([
                "role": "system",
                "content": "You are a helpful assistant. Use the following context to answer questions. If the context doesn't contain relevant information, say so clearly.\n\nContext:\n\(retrievedContext)"
            ])
        }
        
        messages.append([
            "role": "user", 
            "content": message
        ])
        
        // Call OpenAI API
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(openAIAPIKey)", forHTTPHeaderField: "Authorization")
        
        let requestBody: [String: Any] = [
            "model": "gpt-4o-mini", // Following the reference project
            "messages": messages,
            "max_tokens": 1000,
            "temperature": 0.7
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError(message: "Invalid response", code: "INVALID_RESPONSE", details: nil)
        }
        
        if httpResponse.statusCode != 200 {
            let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            let errorDict = errorData?["error"] as? [String: Any]
            let errorMessage = errorDict?["message"] as? String ?? "HTTP Error \(httpResponse.statusCode)"
            let errorCode = errorDict?["code"] as? String
            
            // Provide more specific guidance based on the error
            var userFriendlyMessage = errorMessage
            if errorMessage.contains("organization") || errorMessage.contains("Invalid organization ID") {
                userFriendlyMessage = "OpenAI API Error: Your API key is associated with an invalid organization. Please:\n\n1. Generate a new API key at https://platform.openai.com/api-keys\n2. Make sure your OpenAI account is active\n3. Check that your organization hasn't been suspended"
            } else if errorMessage.contains("quota") || errorMessage.contains("billing") {
                userFriendlyMessage = "OpenAI API Error: Usage quota exceeded or billing issue. Please check your OpenAI account billing status."
            } else if errorMessage.contains("Invalid API key") {
                userFriendlyMessage = "OpenAI API Error: Invalid API key. Please generate a new key at https://platform.openai.com/api-keys"
            } else if errorMessage.contains("Rate limit") {
                userFriendlyMessage = "OpenAI API Error: Rate limit exceeded. Please wait a moment and try again."
            }
            
            throw APIError(message: userFriendlyMessage, code: "OPENAI_ERROR", details: ["original_error": errorMessage, "error_code": errorCode ?? "unknown"])
        }
        
        guard let openAIResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = openAIResponse["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let messageDict = firstChoice["message"] as? [String: Any],
              let messageContent = messageDict["content"] as? String else {
            throw APIError(message: "Invalid OpenAI response format", code: "INVALID_RESPONSE", details: nil)
        }
        
        let usage = openAIResponse["usage"] as? [String: Any]
        let tokensUsed = usage?["total_tokens"] as? Int
        
        return ChatResponse(
            message: messageContent,
            toolUsed: documents.isEmpty ? nil : "document_retrieval",
            sources: documents.isEmpty ? nil : documents,
            metadata: ResponseMetadata(
                processingTime: 0, // Could be calculated
                tokensUsed: tokensUsed,
                model: "gpt-4o-mini"
            )
        )
    }
    
    // MARK: - Vectorize.io Document Search
    func searchDocuments(query: String, limit: Int = 5) async throws -> [DocumentSource] {
        guard !vectorizeAPIKey.isEmpty && !vectorizePipelineURL.isEmpty else {
            throw APIError(message: "Vectorize API credentials not configured", code: "MISSING_VECTORIZE_CONFIG", details: nil)
        }
        
        // Use the retrieval endpoint directly (user provided the full retrieval URL)
        let url = URL(string: vectorizePipelineURL)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(vectorizeAPIKey)", forHTTPHeaderField: "Authorization")
        
        let requestBody: [String: Any] = [
            "question": query,
            "numResults": limit,
            "rerank": true
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError(message: "Invalid response", code: "INVALID_RESPONSE", details: nil)
        }
        
        if httpResponse.statusCode != 200 {
            let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            let errorMessage = errorData?["error"] as? String ?? "Vectorize search failed (HTTP \(httpResponse.statusCode))"
            throw APIError(message: errorMessage, code: "VECTORIZE_ERROR", details: nil)
        }
        
        guard let vectorizeResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw APIError(message: "Invalid JSON response from Vectorize", code: "INVALID_RESPONSE", details: nil)
        }
        

        
        guard let documents = vectorizeResponse["documents"] as? [[String: Any]] else {
            // Check if there's an error message in the response
            if let error = vectorizeResponse["error"] as? String {
                throw APIError(message: "Vectorize error: \(error)", code: "VECTORIZE_ERROR", details: nil)
            }
            // Check if documents array is empty
            if let docs = vectorizeResponse["documents"] as? [Any], docs.isEmpty {
                throw APIError(message: "No documents found in your Vectorize pipeline. Please upload documents first.", code: "NO_DOCUMENTS", details: nil)
            }
            throw APIError(message: "No documents found in Vectorize response", code: "INVALID_RESPONSE", details: nil)
        }
        
        return documents.map { document in
            let metadata = document["metadata"] as? [String: Any]
            
            // Try multiple possible field names for title
            let title = metadata?["title"] as? String ?? 
                       document["title"] as? String ?? 
                       metadata?["name"] as? String ?? 
                       document["name"] as? String ?? 
                       metadata?["filename"] as? String ?? 
                       document["filename"] as? String ?? 
                       "Document"
            
            // Try multiple possible field names for content
            let content = document["text"] as? String ?? 
                         document["content"] as? String ?? 
                         document["chunk"] as? String ?? 
                         metadata?["text"] as? String ?? 
                         ""
            
            // Try multiple possible field names for URL
            let url = metadata?["url"] as? String ?? 
                     document["url"] as? String ?? 
                     metadata?["source"] as? String ?? 
                     document["source"] as? String
            
            // Try multiple possible field names for score/relevance
            let score = document["score"] as? Double ?? 
                       document["relevance_score"] as? Double ?? 
                       document["similarity"] as? Double ?? 
                       document["distance"] as? Double ?? 
                       0.0
            
            return DocumentSource(
                title: title,
                content: content,
                url: url,
                score: score
            )
        }
    }
    
    // MARK: - Document Upload to Vectorize
    func uploadDocument(fileName: String, content: String, contentType: String) async throws -> DocumentUploadResponse {
        guard !vectorizeAPIKey.isEmpty && !vectorizePipelineURL.isEmpty else {
            throw APIError(message: "Vectorize API credentials not configured", code: "MISSING_VECTORIZE_CONFIG", details: nil)
        }
        
        // For uploads, we need to use the upsert endpoint instead of retrieval
        // Convert retrieval URL to upsert URL
        let upsertURL = vectorizePipelineURL.replacingOccurrences(of: "/retrieval", with: "/upsert")
        
        let url = URL(string: upsertURL)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(vectorizeAPIKey)", forHTTPHeaderField: "Authorization")
        
        // Vectorize.io expects documents in a specific format
        let documentId = UUID().uuidString
        let requestBody: [String: Any] = [
            "documents": [
                [
                    "id": documentId,
                    "text": content,
                    "metadata": [
                        "title": fileName,
                        "contentType": contentType,
                        "uploadedAt": ISO8601DateFormatter().string(from: Date())
                    ]
                ]
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError(message: "Invalid response", code: "INVALID_RESPONSE", details: nil)
        }
        
        if httpResponse.statusCode != 200 && httpResponse.statusCode != 201 {
            let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            let errorMessage = errorData?["error"] as? String ?? "Document upload failed (HTTP \(httpResponse.statusCode))"
            throw APIError(message: errorMessage, code: "UPLOAD_ERROR", details: nil)
        }
        
        return DocumentUploadResponse(
            success: true,
            documentId: documentId,
            message: "Document uploaded and indexed successfully"
        )
    }
    
    // MARK: - Weather API (OpenWeatherMap example)
    func getWeather(for location: String) async throws -> WeatherResponse {

        
        guard !weatherAPIKey.isEmpty else {
            throw APIError(message: "Weather API key not configured", code: "MISSING_WEATHER_KEY", details: nil)
        }
        
        // Using OpenWeatherMap as example - replace with your preferred weather API
        let cleanLocation = location.trimmingCharacters(in: .whitespacesAndNewlines)
        let encodedLocation = cleanLocation.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let cleanAPIKey = weatherAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let url = URL(string: "https://api.openweathermap.org/data/2.5/weather?q=\(encodedLocation)&appid=\(cleanAPIKey)&units=imperial")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError(message: "Invalid response", code: "INVALID_RESPONSE", details: nil)
        }
        
        if httpResponse.statusCode != 200 {
            let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            let errorMessage = errorData?["message"] as? String ?? "HTTP \(httpResponse.statusCode)"
            
            throw APIError(message: "Weather API error: \(errorMessage)", code: "WEATHER_ERROR", details: nil)
        }
        
        guard let weatherData = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let main = weatherData["main"] as? [String: Any],
              let weatherArray = weatherData["weather"] as? [[String: Any]],
              let weather = weatherArray.first else {
            throw APIError(message: "Invalid weather response format", code: "INVALID_RESPONSE", details: nil)
        }
        
        let wind = weatherData["wind"] as? [String: Any]
        
        guard let temperature = main["temp"] as? Double,
              let description = weather["description"] as? String,
              let humidity = main["humidity"] as? Int else {
            throw APIError(message: "Missing required weather data", code: "INVALID_RESPONSE", details: nil)
        }
        
        return WeatherResponse(
            location: location,
            temperature: temperature,
            description: description,
            humidity: humidity,
            windSpeed: wind?["speed"] as? Double ?? 0.0
        )
    }
    
    // MARK: - Agent-style Multi-step Processing
    func processAgentQuery(_ message: String) async throws -> ChatResponse {
        // Determine if this is a weather query or document query
        let lowerMessage = message.lowercased()
        
        if lowerMessage.contains("weather") || lowerMessage.contains("temperature") || lowerMessage.contains("forecast") {
            // Extract location from query using simple pattern matching
            let locationPattern = #"weather\s+(?:in|for|at)?\s*([a-zA-Z\s]+)"#
            let regex = try NSRegularExpression(pattern: locationPattern, options: .caseInsensitive)
            let range = NSRange(location: 0, length: message.count)
            
            var location = "San Francisco" // Default
            if let match = regex.firstMatch(in: message, options: [], range: range) {
                if let locationRange = Range(match.range(at: 1), in: message) {
                    location = String(message[locationRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
            
            let weather = try await getWeather(for: location)
            let response = "The weather in \(weather.location) is currently \(Int(weather.temperature))°F and \(weather.description). Humidity is \(weather.humidity)% with wind speeds of \(weather.windSpeed) mph."
            
            return ChatResponse(
                message: response,
                toolUsed: "weather_info",
                sources: nil,
                metadata: ResponseMetadata(processingTime: 0, tokensUsed: nil, model: "weather-api")
            )
        } else {
            // Use document retrieval
            return try await sendMessage(message)
        }
    }
    
    // MARK: - Health Check
    func healthCheck() async throws -> Bool {
        guard !openAIAPIKey.isEmpty else {
            return false
        }
        
        // Validate API key format first
        guard openAIAPIKey.hasPrefix("sk-") && openAIAPIKey.count > 20 else {
            throw APIError(message: "Invalid OpenAI API key format", code: "INVALID_API_KEY", details: nil)
        }
        
        // Simple check to OpenAI API
        let url = URL(string: "https://api.openai.com/v1/models")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(openAIAPIKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                return false
            }
            
            if httpResponse.statusCode == 401 {
                // Parse the error to provide better feedback
                if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let errorDict = errorData["error"] as? [String: Any],
                   let errorMessage = errorDict["message"] as? String {
                    
                    if errorMessage.contains("organization") || errorMessage.contains("Invalid organization ID") {
                        throw APIError(message: "OpenAI organization issue. Please generate a new API key at https://platform.openai.com/api-keys", code: "ORGANIZATION_ERROR", details: nil)
                    } else {
                        throw APIError(message: "Invalid OpenAI API key. Please check your key at https://platform.openai.com/api-keys", code: "INVALID_API_KEY", details: nil)
                    }
                }
            }
            
            return httpResponse.statusCode == 200
        } catch let error as APIError {
            // Re-throw our custom errors
            throw error
        } catch {
            // Network or other errors
            return false
        }
    }
}

// MARK: - Configuration Extensions
extension APIService {
    func updateConfiguration(openAIKey: String, vectorizeKey: String, vectorizeURL: String, weatherKey: String = "") {
        // Update the private properties with the new configuration
        self.openAIAPIKey = openAIKey
        self.vectorizeAPIKey = vectorizeKey
        self.vectorizePipelineURL = vectorizeURL
        
        // Update weather key - use provided key or load from UserDefaults
        if !weatherKey.isEmpty {
            self.weatherAPIKey = weatherKey.trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            self.weatherAPIKey = (UserDefaults.standard.string(forKey: "weather_api_key") ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        }
        

    }
}
