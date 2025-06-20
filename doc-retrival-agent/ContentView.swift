//
//  ContentView.swift
//  doc-retrival-agent
//
//  Created by Subhodip Banerjee on 20/06/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = ChatViewModel()
    @State private var showingDocumentPicker = false
    @State private var showingSettings = false
    @State private var showingConfiguration = false
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                headerView
                
                // Configuration Banner (if not configured)
                if !viewModel.isConfigured {
                    configurationBanner
                }
                
                // Messages
                messagesView
                
                // Input area
                inputView
            }
            .navigationBarHidden(true)
            .background(Color(.systemBackground))
        }
        .sheet(isPresented: $showingDocumentPicker) {
            DocumentPickerView(viewModel: viewModel)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(viewModel: viewModel, showingConfiguration: $showingConfiguration)
        }
        .sheet(isPresented: $showingConfiguration) {
            ConfigurationView(isPresented: $showingConfiguration)
                .onDisappear {
                    // Update view model when configuration changes
                    viewModel.updateAPIConfiguration()
                }
        }
    }
    
    private var configurationBanner: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Configuration Required")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("Set up your OpenAI and Vectorize.io credentials to get started")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button("Configure") {
                showingConfiguration = true
            }
            .font(.caption)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.orange)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color.orange.opacity(0.3)),
            alignment: .bottom
        )
    }
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("RAG Agent")
                    .font(.title2)
                    .fontWeight(.bold)
                
                HStack(spacing: 4) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)
                    
                    Text(statusText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let selectedTool = viewModel.selectedTool {
                        Text("• Using \(selectedTool.displayName)")
                            .font(.caption)
                            .foregroundColor(selectedTool.systemColor)
                    }
                }
            }
            
            Spacer()
            
            HStack(spacing: 16) {
                Button(action: {
                    showingDocumentPicker = true
                }) {
                    Image(systemName: "doc.badge.plus")
                        .font(.title3)
                        .foregroundColor(viewModel.isConfigured ? .blue : .secondary)
                }
                .disabled(!viewModel.isConfigured)
                
                Button(action: {
                    if !viewModel.isConfigured {
                        showingConfiguration = true
                    } else {
                        showingSettings = true
                    }
                }) {
                    Image(systemName: viewModel.isConfigured ? "gearshape" : "key.fill")
                        .font(.title3)
                        .foregroundColor(viewModel.isConfigured ? .blue : .orange)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(.systemGray4)),
            alignment: .bottom
        )
    }
    
    private var statusColor: Color {
        if !viewModel.isConfigured {
            return .orange
        }
        return viewModel.isConnected ? .green : .red
    }
    
    private var statusText: String {
        if !viewModel.isConfigured {
            return "Configuration needed"
        }
        return viewModel.isConnected ? "Connected" : "Offline"
    }
    
    private var messagesView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(viewModel.messages) { message in
                        MessageView(message: message)
                            .id(message.id)
                    }
                    
                    if viewModel.isLoading {
                        TypingIndicatorView()
                            .id("typing")
                    }
                    
                    if viewModel.messages.isEmpty && !viewModel.isLoading {
                        emptyStateView
                    }
                }
            }
            .onChange(of: viewModel.messages.count) {
                withAnimation(.easeOut(duration: 0.3)) {
                    if let lastMessage = viewModel.messages.last {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
            .onChange(of: viewModel.isLoading) {
                if viewModel.isLoading {
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo("typing", anchor: .bottom)
                    }
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            VStack(spacing: 12) {
                Text("Welcome to RAG Agent")
                    .font(.title2)
                    .fontWeight(.bold)
                
                if viewModel.isConfigured {
                    Text("I can help you search through documents and get weather information. Try asking me something!")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                } else {
                    VStack(spacing: 8) {
                        Text("To get started, configure your API credentials")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button("Setup APIs") {
                            showingConfiguration = true
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                    }
                }
            }
            
            if viewModel.isConfigured {
                VStack(spacing: 8) {
                    Text("Try asking:")
                        .font(.headline)
                        .fontWeight(.medium)
                    
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ForEach(viewModel.suggestedQuestions(), id: \.self) { question in
                            Button(action: {
                                viewModel.currentMessage = question
                                viewModel.sendMessage()
                            }) {
                                Text(question)
                                    .font(.caption)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color.blue.opacity(0.1))
                                    .foregroundColor(.blue)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private var inputView: some View {
        VStack(spacing: 0) {
            if let errorMessage = viewModel.errorMessage {
                errorBanner(errorMessage)
            }
            
            if viewModel.isConfigured {
                toolIndicatorView
            }
            
            HStack(spacing: 12) {
                HStack {
                    TextField(viewModel.isConfigured ? "Ask me anything..." : "Configure APIs first...", text: $viewModel.currentMessage, axis: .vertical)
                        .focused($isInputFocused)
                        .lineLimit(1...4)
                        .disabled(!viewModel.isConfigured)
                        .onSubmit {
                            if !viewModel.currentMessage.isEmpty && viewModel.isConfigured {
                                viewModel.sendMessage()
                            }
                        }
                    
                    if !viewModel.currentMessage.isEmpty {
                        Button(action: {
                            viewModel.currentMessage = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 24))
                
                Button(action: {
                    if viewModel.isConfigured {
                        viewModel.sendMessage()
                    } else {
                        showingConfiguration = true
                    }
                }) {
                    Image(systemName: viewModel.isLoading ? "stop.circle.fill" : (viewModel.isConfigured ? "arrow.up.circle.fill" : "key.fill"))
                        .font(.title2)
                        .foregroundColor(
                            viewModel.isConfigured ? 
                                (viewModel.currentMessage.isEmpty ? .secondary : .blue) :
                                .orange
                        )
                }
                .disabled(viewModel.isConfigured && viewModel.currentMessage.isEmpty && !viewModel.isLoading)
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
        }
    }
    
    private var toolIndicatorView: some View {
        HStack {
            Text("Available Tools:")
                .font(.caption)
                .foregroundColor(.secondary)
            
            ForEach(viewModel.availableTools, id: \.self) { tool in
                Button(action: {
                    viewModel.triggerTool(tool)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: tool.iconName)
                            .font(.caption)
                        Text(tool.displayName)
                            .font(.caption)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        (viewModel.selectedTool == tool ? tool.systemColor : Color.secondary)
                            .opacity(0.2)
                    )
                    .foregroundColor(viewModel.selectedTool == tool ? tool.systemColor : .secondary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(!viewModel.isConfigured)
            }
            
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
    
    private func errorBanner(_ message: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            
            Text(message)
                .font(.caption)
                .foregroundColor(.primary)
            
            Spacer()
            
            Button("Retry") {
                viewModel.retryLastMessage()
            }
            .font(.caption)
            .foregroundColor(.blue)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.orange.opacity(0.1))
    }
}

struct DocumentPickerView: View {
    @ObservedObject var viewModel: ChatViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var documentText = ""
    @State private var fileName = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Document Name")
                        .font(.headline)
                    
                    TextField("Enter document name", text: $fileName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Document Content")
                        .font(.headline)
                    
                    TextEditor(text: $documentText)
                        .frame(minHeight: 200)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                        )
                }
                
                Button(action: {
                    Task {
                        await viewModel.uploadDocument(
                            fileName: fileName.isEmpty ? "Untitled Document" : fileName,
                            content: documentText,
                            contentType: "text/plain"
                        )
                        dismiss()
                    }
                }) {
                    Text("Upload Document")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(documentText.isEmpty)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Add Document")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct SettingsView: View {
    @ObservedObject var viewModel: ChatViewModel
    @Binding var showingConfiguration: Bool
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section("Chat") {
                    Button(action: {
                        viewModel.clearChat()
                        dismiss()
                    }) {
                        Label("Clear Chat History", systemImage: "trash")
                            .foregroundColor(.red)
                    }
                }
                
                Section("API Configuration") {
                    Button(action: {
                        dismiss()
                        showingConfiguration = true
                    }) {
                        Label("API Settings", systemImage: "key")
                    }
                }
                
                Section("Connection") {
                    HStack {
                        Label("Status", systemImage: "network")
                        Spacer()
                        Text(viewModel.isConnected ? "Connected" : "Offline")
                            .foregroundColor(viewModel.isConnected ? .green : .red)
                    }
                    
                    Button(action: {
                        Task {
                            await viewModel.checkConnection()
                        }
                    }) {
                        Label("Test Connection", systemImage: "arrow.clockwise")
                    }
                }
                
                Section("Tools") {
                    ForEach(viewModel.availableTools, id: \.self) { tool in
                        HStack {
                            Image(systemName: tool.iconName)
                                .foregroundColor(tool.systemColor)
                            
                            VStack(alignment: .leading) {
                                Text(tool.displayName)
                                    .font(.headline)
                                Text(tool.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if viewModel.selectedTool == tool {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                        }
                    }
                }
                
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Based on")
                        Spacer()
                        Link("agent-next-typescript", destination: URL(string: "https://github.com/trancethehuman/agent-next-typescript")!)
                            .foregroundColor(.blue)
                    }
                }
            }
            .navigationTitle("Settings")
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
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
    ContentView()
    }
}
