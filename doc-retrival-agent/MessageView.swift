import SwiftUI

struct MessageView: View {
    let message: ChatMessage
    @State private var showSources = false
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if message.isUser {
                Spacer()
                userMessageContent
            } else {
                assistantMessageContent
                Spacer()
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
    
    private var userMessageContent: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text(message.content)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.blue)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .frame(maxWidth: UIScreen.main.bounds.width * 0.7, alignment: .trailing)
            
            Text(message.formattedTimestamp)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
    
    private var assistantMessageContent: some View {
        HStack(alignment: .top, spacing: 8) {
            // Avatar
            Circle()
                .fill(Color.green.gradient)
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: "brain.head.profile")
                        .foregroundColor(.white)
                        .font(.system(size: 14, weight: .medium))
                )
            
            VStack(alignment: .leading, spacing: 8) {
                // Message content
                Text(message.content)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .frame(maxWidth: UIScreen.main.bounds.width * 0.7, alignment: .leading)
                
                // Sources section
                if message.hasValidSources {
                    sourcesSection
                }
                
                // Timestamp
                Text(message.formattedTimestamp)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var sourcesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showSources.toggle()
                }
            }) {
                HStack {
                    Image(systemName: "doc.text")
                        .foregroundColor(.blue)
                    Text("\(message.sources?.count ?? 0) source(s)")
                        .font(.caption)
                        .foregroundColor(.blue)
                    Image(systemName: showSources ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.blue.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            
            if showSources, let sources = message.sources {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(sources) { source in
                        SourceView(source: source)
                    }
                }
                .transition(.slide.combined(with: .opacity))
            }
        }
    }
}

struct SourceView: View {
    let source: DocumentSource
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(source.title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)
                        
                        HStack {
                            Text("Relevance: \(Int(source.score * 100))%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            if let url = source.url {
                                Text("• \(url)")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                    .lineLimit(1)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            if isExpanded {
                Text(source.content)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
                    .transition(.slide.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
    }
}

struct TypingIndicatorView: View {
    @State private var animationPhase = 0
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Avatar
            Circle()
                .fill(Color.green.gradient)
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: "brain.head.profile")
                        .foregroundColor(.white)
                        .font(.system(size: 14, weight: .medium))
                )
            
            // Typing animation
            HStack(spacing: 4) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(Color.secondary)
                        .frame(width: 8, height: 8)
                        .scaleEffect(animationPhase == index ? 1.2 : 0.8)
                        .opacity(animationPhase == index ? 1.0 : 0.5)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .onAppear {
                withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: false)) {
                    animationPhase = 2
                }
            }
            
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

struct MessageView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 16) {
            MessageView(message: ChatMessage(content: "Hello, how can you help me?", isUser: true))
            
            MessageView(message: ChatMessage(
                content: "I can help you search through documents and get weather information!",
                isUser: false,
                sources: [
                    DocumentSource(
                        title: "RAG Documentation",
                        content: "This is a sample document about RAG systems...",
                        url: "https://example.com/rag-docs",
                        score: 0.95
                    )
                ]
            ))
            
            TypingIndicatorView()
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
} 