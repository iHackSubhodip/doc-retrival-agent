import Foundation
import SwiftUI

@MainActor
class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var currentMessage: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var isConnected: Bool = false
    @Published var availableTools: [ToolType] = ToolType.allCases
    @Published var selectedTool: ToolType?
    
    private let apiService: APIService
    
    init() {
        self.apiService = APIService.shared
        
        // Load saved configuration
        loadConfiguration()
        
        // Add welcome message
        addWelcomeMessage()
        
        // Check connection status
        Task {
            await checkConnection()
        }
    }
    
    private func loadConfiguration() {
        let openAIKey = UserDefaults.standard.string(forKey: "openai_api_key") ?? ""
        let vectorizeKey = UserDefaults.standard.string(forKey: "vectorize_api_key") ?? ""
        let vectorizeURL = UserDefaults.standard.string(forKey: "vectorize_pipeline_url") ?? ""
        
        // Update API service with saved credentials
        if !openAIKey.isEmpty && !vectorizeKey.isEmpty && !vectorizeURL.isEmpty {
            apiService.updateConfiguration(
                openAIKey: openAIKey,
                vectorizeKey: vectorizeKey,
                vectorizeURL: vectorizeURL
            )
        }
    }
    
    private func addWelcomeMessage() {
        let welcomeContent = if isConfigured {
            "👋 Welcome to your RAG Agent! I'm connected to your real APIs.\n\n🔍 **Document Search**: Ask questions about your uploaded documents\n🌤️ **Weather Info**: Get current weather information\n🤖 **Powered by**: OpenAI GPT-4o-mini + Vectorize.io\n\nHow can I assist you today?"
        } else {
            "👋 Welcome to your RAG Agent!\n\n🔧 **Setup Required**: Configure your API credentials to get started:\n🔍 **Document Search**: Connect to Vectorize.io\n🌤️ **Weather Info**: Get real-time weather data\n🤖 **OpenAI GPT-4o-mini**: Advanced AI responses\n\nTap the key icon to configure your API keys!"
        }
        
        let welcomeMessage = ChatMessage(
            content: welcomeContent,
            isUser: false
        )
        messages.append(welcomeMessage)
    }
    
    var isConfigured: Bool {
        let openAIKey = UserDefaults.standard.string(forKey: "openai_api_key") ?? ""
        let vectorizeKey = UserDefaults.standard.string(forKey: "vectorize_api_key") ?? ""
        let vectorizeURL = UserDefaults.standard.string(forKey: "vectorize_pipeline_url") ?? ""
        
        return !openAIKey.isEmpty && !vectorizeKey.isEmpty && !vectorizeURL.isEmpty
    }
    
    func sendMessage() {
        guard !currentMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard isConfigured else {
            errorMessage = "Please configure your API credentials first"
            return
        }
        
        let userMessage = ChatMessage(content: currentMessage, isUser: true)
        messages.append(userMessage)
        
        let messageToSend = currentMessage
        currentMessage = ""
        
        Task {
            await processMessage(messageToSend)
        }
    }
    
    private func processMessage(_ message: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Use real API service with agent-style processing
            let response = try await apiService.processAgentQuery(message)
            
            let assistantMessage = ChatMessage(
                content: response.message,
                isUser: false,
                sources: response.sources
            )
            
            messages.append(assistantMessage)
            
            // Update selected tool based on response
            if let toolUsed = response.toolUsed {
                selectedTool = ToolType(rawValue: toolUsed)
            }
            
        } catch {
            errorMessage = error.localizedDescription
            
            let errorMessage = ChatMessage(
                content: "❌ Sorry, I encountered an error: \(error.localizedDescription)\n\nPlease check your API configuration or try again.",
                isUser: false
            )
            messages.append(errorMessage)
        }
        
        isLoading = false
    }
    
    func uploadDocument(fileName: String, content: String, contentType: String) async {
        guard isConfigured else {
            errorMessage = "Please configure your API credentials first"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let response = try await apiService.uploadDocument(
                fileName: fileName,
                content: content,
                contentType: contentType
            )
            
            let uploadMessage = ChatMessage(
                content: "✅ \(response.message)\n\nYour document has been processed and indexed for search.",
                isUser: false
            )
            messages.append(uploadMessage)
            
        } catch {
            errorMessage = error.localizedDescription
            
            let errorMessage = ChatMessage(
                content: "❌ Failed to upload document: \(error.localizedDescription)",
                isUser: false
            )
            messages.append(errorMessage)
        }
        
        isLoading = false
    }
    
    func checkConnection() async {
        guard isConfigured else {
            isConnected = false
            return
        }
        
        do {
            isConnected = try await apiService.healthCheck()
        } catch {
            isConnected = false
        }
    }
    
    func suggestedQuestions() -> [String] {
        return [
            "Search my documents",
            "What's the weather like?",
            "Tell me about the uploaded files",
            "Current weather forecast"
        ]
    }
    
    func clearChat() {
        messages.removeAll()
        addWelcomeMessage()
        selectedTool = nil
        errorMessage = nil
    }
    
    func retryLastMessage() {
        guard let lastUserMessage = messages.last(where: { $0.isUser }) else { return }
        
        Task {
            await processMessage(lastUserMessage.content)
        }
    }
    
    func triggerTool(_ tool: ToolType) {
        guard isConfigured else {
            errorMessage = "Please configure your API credentials first"
            return
        }
        
        switch tool {
        case .documentRetrieval:
            // For document search, show a prompt or use a default search
            currentMessage = "Search through my documents"
            sendMessage()
            
        case .weatherInfo:
            // For weather, ask for current location or use a default location
            showWeatherPrompt()
        }
    }
    
    private func showWeatherPrompt() {
        // Add a system message asking for location
        let promptMessage = ChatMessage(
            content: "🌤️ **Weather Tool Activated**\n\nTo get weather information, please tell me which location you'd like to check.\n\nFor example:\n• \"What's the weather in New York?\"\n• \"Current weather in Tokyo\"\n• \"Weather forecast for London\"",
            isUser: false
        )
        messages.append(promptMessage)
        selectedTool = .weatherInfo
        
        // Auto-fill a sample weather query
        currentMessage = "What's the weather in "
    }
    
    // MARK: - Configuration Updates
    func updateAPIConfiguration() {
        loadConfiguration()
        
        // Update API service with all saved credentials including weather key
        let openAIKey = UserDefaults.standard.string(forKey: "openai_api_key") ?? ""
        let vectorizeKey = UserDefaults.standard.string(forKey: "vectorize_api_key") ?? ""
        let vectorizeURL = UserDefaults.standard.string(forKey: "vectorize_pipeline_url") ?? ""
        let weatherKey = UserDefaults.standard.string(forKey: "weather_api_key") ?? ""
        
        apiService.updateConfiguration(
            openAIKey: openAIKey,
            vectorizeKey: vectorizeKey,
            vectorizeURL: vectorizeURL,
            weatherKey: weatherKey
        )
        
        clearChat()
        
        Task {
            await checkConnection()
        }
    }
    
}

// MARK: - Message Extensions
extension ChatMessage {
    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
    
    var hasValidSources: Bool {
        return sources?.isEmpty == false
    }
}

// MARK: - Tool Extensions
extension ToolType {
    var systemColor: Color {
        switch self {
        case .documentRetrieval:
            return .blue
        case .weatherInfo:
            return .orange
        }
    }
    
    var iconName: String {
        switch self {
        case .documentRetrieval:
            return "doc.text.magnifyingglass"
        case .weatherInfo:
            return "cloud.sun"
        }
    }
} 
