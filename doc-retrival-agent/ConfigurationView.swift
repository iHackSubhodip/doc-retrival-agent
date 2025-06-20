import SwiftUI

struct ConfigurationView: View {
    @Binding var isPresented: Bool
    @State private var openAIKey: String = ""
    @State private var vectorizeKey: String = ""
    @State private var vectorizeURL: String = ""
    @State private var weatherAPIKey: String = ""
    @State private var isTestingConnection = false
    @State private var connectionStatus: ConnectionStatus = .unknown
    @State private var showingHelp = false
    
    enum ConnectionStatus {
        case unknown, testing, success, failure
        
        var color: Color {
            switch self {
            case .unknown: return .secondary
            case .testing: return .orange
            case .success: return .green
            case .failure: return .red
            }
        }
        
        var icon: String {
            switch self {
            case .unknown: return "questionmark.circle"
            case .testing: return "arrow.triangle.2.circlepath"
            case .success: return "checkmark.circle.fill"
            case .failure: return "xmark.circle.fill"
            }
        }
        
        var message: String {
            switch self {
            case .unknown: return "Not tested"
            case .testing: return "Testing connection..."
            case .success: return "Connection successful"
            case .failure: return "Connection failed"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    Text("Configure your API credentials to connect to OpenAI and Vectorize.io services.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Section("OpenAI Configuration") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("API Key")
                            .font(.headline)
                        
                        SecureField("sk-...", text: $openAIKey)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        Text("Get your API key from OpenAI Platform")
                            .font(.caption)
                            .foregroundColor(.blue)
                            .onTapGesture {
                                if let url = URL(string: "https://platform.openai.com/api-keys") {
                                    UIApplication.shared.open(url)
                                }
                            }
                    }
                }
                
                Section("Vectorize.io Configuration") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("API Key")
                            .font(.headline)
                        
                        SecureField("vz_...", text: $vectorizeKey)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        Text("Pipeline URL")
                            .font(.headline)
                        
                        TextField("https://api.vectorize.io/v1/...", text: $vectorizeURL)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                        
                        Text("Get your credentials from Vectorize.io Dashboard")
                            .font(.caption)
                            .foregroundColor(.blue)
                            .onTapGesture {
                                if let url = URL(string: "https://vectorize.io") {
                                    UIApplication.shared.open(url)
                                }
                            }
                    }
                }
                
                Section("Weather API (Optional)") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("OpenWeatherMap API Key")
                            .font(.headline)
                        
                        SecureField("Enter API key", text: $weatherAPIKey)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        Text("Sign up at OpenWeatherMap for weather features")
                            .font(.caption)
                            .foregroundColor(.blue)
                            .onTapGesture {
                                if let url = URL(string: "https://openweathermap.org/api") {
                                    UIApplication.shared.open(url)
                                }
                            }
                    }
                }
                
                Section("Connection Status") {
                    HStack {
                        Image(systemName: connectionStatus.icon)
                            .foregroundColor(connectionStatus.color)
                        
                        Text(connectionStatus.message)
                            .foregroundColor(connectionStatus.color)
                        
                        Spacer()
                        
                        if connectionStatus == .testing {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                    }
                    
                    Button(action: testConnection) {
                        HStack {
                            Image(systemName: "network")
                            Text("Test Connection")
                        }
                    }
                    .disabled(isTestingConnection || openAIKey.isEmpty)
                }
                
                Section {
                    Button(action: {
                        showingHelp = true
                    }) {
                        HStack {
                            Image(systemName: "questionmark.circle")
                            Text("Setup Help")
                        }
                    }
                }
            }
            .navigationTitle("Configuration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveConfiguration()
                        isPresented = false
                    }
                    .disabled(openAIKey.isEmpty || vectorizeKey.isEmpty || vectorizeURL.isEmpty)
                }
            }
            .onAppear {
                loadSavedConfiguration()
            }
        }
        .sheet(isPresented: $showingHelp) {
            SetupHelpView()
        }
    }
    
    private func testConnection() {
        isTestingConnection = true
        connectionStatus = .testing
        
        Task {
            do {
                // Create a temporary API service with the provided credentials
                let testService = APIService.shared
                testService.updateConfiguration(
                    openAIKey: openAIKey,
                    vectorizeKey: vectorizeKey,
                    vectorizeURL: vectorizeURL
                )
                
                let isHealthy = try await testService.healthCheck()
                
                await MainActor.run {
                    connectionStatus = isHealthy ? .success : .failure
                    isTestingConnection = false
                }
            } catch {
                await MainActor.run {
                    connectionStatus = .failure
                    isTestingConnection = false
                }
            }
        }
    }
    
    private func saveConfiguration() {
        // In a production app, store these securely in Keychain
        UserDefaults.standard.set(openAIKey.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "openai_api_key")
        UserDefaults.standard.set(vectorizeKey.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "vectorize_api_key")
        UserDefaults.standard.set(vectorizeURL.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "vectorize_pipeline_url")
        UserDefaults.standard.set(weatherAPIKey.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "weather_api_key")
        
        // Update the API service
        APIService.shared.updateConfiguration(
            openAIKey: openAIKey,
            vectorizeKey: vectorizeKey,
            vectorizeURL: vectorizeURL,
            weatherKey: weatherAPIKey
        )
    }
    
    private func loadSavedConfiguration() {
        openAIKey = UserDefaults.standard.string(forKey: "openai_api_key") ?? ""
        vectorizeKey = UserDefaults.standard.string(forKey: "vectorize_api_key") ?? ""
        vectorizeURL = UserDefaults.standard.string(forKey: "vectorize_pipeline_url") ?? ""
        weatherAPIKey = UserDefaults.standard.string(forKey: "weather_api_key") ?? ""
    }
}

struct SetupHelpView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    setupSection(
                        title: "1. OpenAI Setup",
                        icon: "brain.head.profile",
                        color: .green,
                        steps: [
                            "Visit platform.openai.com",
                            "Sign up or log in to your account",
                            "Navigate to API Keys section",
                            "Create a new API key",
                            "Copy the key (starts with 'sk-')",
                            "Paste it in the OpenAI API Key field"
                        ]
                    )
                    
                    setupSection(
                        title: "2. Vectorize.io Setup",
                        icon: "doc.text.magnifyingglass",
                        color: .blue,
                        steps: [
                            "Visit vectorize.io and create an account",
                            "Create a new pipeline",
                            "Get your API key from dashboard",
                            "Copy your pipeline URL",
                            "Paste both in the Vectorize fields"
                        ]
                    )
                    
                    setupSection(
                        title: "3. Weather API (Optional)",
                        icon: "cloud.sun",
                        color: .orange,
                        steps: [
                            "Visit openweathermap.org/api",
                            "Sign up for a free account",
                            "Get your API key",
                            "Paste it in the Weather API field"
                        ]
                    )
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Tips", systemImage: "lightbulb")
                            .font(.headline)
                            .foregroundColor(.yellow)
                        
                        Text("• Your API keys are stored securely on your device")
                        Text("• Use the Test Connection button to verify setup")
                        Text("• Weather API is optional - the app works without it")
                        Text("• You can update credentials anytime in Settings")
                    }
                    .padding()
                    .background(Color.yellow.opacity(0.1))
                    .cornerRadius(12)
                }
                .padding()
            }
            .navigationTitle("Setup Guide")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func setupSection(title: String, icon: String, color: Color, steps: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.headline)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(index + 1).")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(step)
                            .font(.caption)
                    }
                }
            }
        }
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

struct ConfigurationView_Previews: PreviewProvider {
    static var previews: some View {
        ConfigurationView(isPresented: .constant(true))
    }
} 