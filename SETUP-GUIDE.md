# RAG Agent iOS Setup Guide

This guide will help you configure your iOS RAG Agent app with your **OpenAI API key** and **Vectorize.io access token**. 

## 📋 Prerequisites

Based on the [reference implementation](https://github.com/trancethehuman/agent-next-typescript), you'll need:

1. **OpenAI API Key** - For GPT-4o-mini responses
2. **Vectorize.io Account** - For document embedding and search
3. **Weather API Key** (Optional) - For weather features

## 🚀 Quick Setup (iOS App)

### Step 1: Launch the App
1. Build and run the iOS app in Xcode
2. You'll see a **"Configuration Required"** banner
3. Tap **"Configure"** to open the setup screen

### Step 2: Configure OpenAI
1. Go to [OpenAI Platform](https://platform.openai.com/api-keys)
2. Create a new API key (starts with `sk-`)
3. Copy the key and paste it in the **"OpenAI API Key"** field

### Step 3: Configure Vectorize.io
1. Go to your [Vectorize.io Dashboard](https://vectorize.io)
2. Get your **Pipeline Access Token** (JWT format, starts with `eyJ`)
3. Copy your **Pipeline Retrieval URL** in this format:
   ```
   https://api.vectorize.io/v1/org/{org-id}/pipelines/{pipeline-id}/retrieval
   ```
   Example: `https://api.vectorize.io/v1/org/c0f1588c-9217-46c2-8036-2c36b056eb6a/pipelines/aipfa301-9617-4b03-acbd-f99da8abfbbe/retrieval`
4. Paste both in the respective fields

### Step 4: Test Connection
1. Tap **"Test Connection"** to verify your setup
2. Wait for the green checkmark ✅
3. Tap **"Save"** to store your configuration

## 🔧 API Architecture (Following Reference Project)

Your iOS app now mirrors the architecture from the [agent-next-typescript](https://github.com/trancethehuman/agent-next-typescript) project:

```
iOS App ──→ OpenAI GPT-4o-mini (Chat Completions)
        └──→ Vectorize.io API (Document Search & Upload)
        └──→ OpenWeatherMap (Weather Info)
```

### Vectorize.io Endpoints Used

- **Document Search**: `GET {pipeline-url}/retrieval`
- **Document Upload**: `POST {pipeline-url}/upsert`

The app automatically converts your retrieval URL to the upsert URL for document uploads.

### Supported Features

#### 🤖 Two AI Tools (Like Reference Project)
1. **Document Retrieval Tool**
   - Searches your Vectorize.io pipeline
   - Provides context for RAG responses
   - Shows source documents with similarity scores

2. **Weather Information Tool** 
   - Gets current weather data
   - Location extraction from queries
   - Real-time weather information

#### 📱 iOS-Specific Features
- **Native SwiftUI Interface**
- **Secure Credential Storage**
- **Real-time Connection Status**
- **Document Upload via UI**
- **Source Citation Display**

## 🔄 How It Works (RAG Flow)

Following the same pattern as the TypeScript reference:

1. **User Input**: "What is machine learning?"
2. **Document Search**: Query Vectorize.io for relevant documents
3. **Context Building**: Format retrieved documents as context
4. **OpenAI Query**: Send context + question to GPT-4o-mini
5. **Response**: Get AI response with source citations

### Example API Calls

#### Document Search (Vectorize.io)
```json
POST https://api.vectorize.io/v1/org/{org-id}/pipelines/{pipeline-id}/retrieval
Authorization: Bearer {your-jwt-token}
{
  "query": "machine learning",
  "top_k": 5
}
```

#### Document Upload (Vectorize.io)
```json
POST https://api.vectorize.io/v1/org/{org-id}/pipelines/{pipeline-id}/upsert
Authorization: Bearer {your-jwt-token}
{
  "documents": [
    {
      "id": "unique-doc-id",
      "text": "document content",
      "metadata": {
        "title": "Document Title",
        "contentType": "text/plain"
      }
    }
  ]
}
```

#### Chat Completion (OpenAI)
```json
POST https://api.openai.com/v1/chat/completions
Authorization: Bearer {your-openai-key}
{
  "model": "gpt-4o-mini",
  "messages": [
    {
      "role": "system", 
      "content": "Use the following context: [Retrieved Documents]"
    },
    {
      "role": "user",
      "content": "What is machine learning?"
    }
  ]
}
```

## 🎯 Configuration Examples

### Your Configuration Values
Based on your `.env.local` file:

```
OpenAI API Key: sk-proj-SGfQAaBWLpL15XSAW0-DMjF6TNhioENsa2FjzpWTVLxwEGa79N7i
Vectorize Token: eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJpYXQiOjE3MzQ2OTY4NzEsImV4cCI6MTc2NjIzMjg3MSwic3ViIjoiNTI3ZDlhMjctYzM0YS00ZDBhLThmZGUtMTEyOWE1N2ViNWI4IiwiYXVkIjoidmVjdG9yaXplLmlvIiwiaXNzIjoidmVjdG9yaXplLmlvIiwianRpIjoiYWlwZmEzMDEtOTYxNy00YjAzLWFjYmQtZjk5ZGE4YWJmYmJlIn0.eyJwaXBlbGluZV9pZCI6ImFpcGZhMzAxLTk2MTctNGIwMy1hY2JkLWY5OWRhOGFiZmJiZSIsIm9yZ2FuaXphdGlvbl9pZCI6IjUyN2Q5YTI3LWMzNGEtNGQwYS04ZmRlLTExMjlhNTdlYjViOCIsInBlcm1pc3Npb25zIjpbInJldHJpZXZhbCIsInVwc2VydCJdfQ
Vectorize URL: https://api.vectorize.io/v1/org/c0f1588c-9217-46c2-8036-2c36b056eb6a/pipelines/aipfa301-9617-4b03-acbd-f99da8abfbbe/retrieval
```

### Weather API Setup (Optional)
1. Sign up at [OpenWeatherMap](https://openweathermap.org/api)
2. Get your free API key
3. Add it in the "Weather API" section
4. Enables queries like "What's the weather in Tokyo?"

## 🎯 Usage Examples

### Document-Based Questions
```
"What does the manual say about installation?"
"Summarize the key features from the documentation"
"Find information about pricing"
```

### Weather Questions  
```
"What's the weather in New York?"
"Is it raining in London?"
"Temperature in San Francisco"
```

### General Questions (with RAG Context)
```
"How do I get started?"
"What are the main benefits?"
"Tell me about the technical architecture"
```

## 🚨 Troubleshooting

### "Configuration Required" Banner Won't Go Away
- Check all fields are filled (OpenAI key, Vectorize token, Vectorize URL)
- Ensure keys don't have extra spaces
- Test connection shows green checkmark

### OpenAI Errors
- `401 Unauthorized`: Check API key is correct
- `429 Too Many Requests`: You've hit rate limits
- `403 Forbidden`: Check billing/quota

### Vectorize Errors  
- `404 Not Found`: Check pipeline URL format
- `401 Unauthorized`: Verify Vectorize access token
- `Empty Results`: Pipeline may not have documents

### Connection Test Fails
- Check internet connection
- Verify API endpoints are accessible
- Try toggling airplane mode on/off

## 📚 Reference Implementation

This iOS app implements the same concepts from:
- **Repository**: [agent-next-typescript](https://github.com/trancethehuman/agent-next-typescript)
- **Architecture**: Multi-step agent with RAG
- **Models**: OpenAI GPT-4o-mini + Vectorize.io
- **Tools**: Document search + Weather info

## 🎉 You're Ready!

Once configured, your iOS RAG Agent will:
- ✅ Search your actual documents in Vectorize.io
- ✅ Provide AI-powered responses from OpenAI
- ✅ Show real weather information
- ✅ Display source citations
- ✅ Work just like the TypeScript reference!

Happy RAG-ing! 🤖📱 