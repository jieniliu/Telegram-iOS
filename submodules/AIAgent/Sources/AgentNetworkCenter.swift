import Foundation
import SwiftSignalKit

/// 网络请求结果
public enum NetworkResult<T> {
    case success(T)
    case failure(Error)
}

/// 网络错误类型
public enum NetworkError: Error {
    case invalidURL
    case noData
    case decodingError
    case networkError(Error)
    case serverError(Int)
    
    public var localizedDescription: String {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .noData:
            return "No data received"
        case .decodingError:
            return "Failed to decode response"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .serverError(let code):
            return "Server error with code: \(code)"
        }
    }
}

/// 聊天消息结构
public struct ChatMessage: Codable {
    public let id: String?
    public let role: String
    public let content: String
    
    public init(id: String? = nil, role: String, content: String) {
        self.id = id
        self.role = role
        self.content = content
    }
}

/// 请求参数结构
public struct ChatRequest: Codable {
    public let messages: [ChatMessage]
    
    public init(messages: [ChatMessage]) {
        self.messages = messages
    }
}

/// 网络中心 - 负责处理所有网络请求
public final class AgentNetworkCenter {
    public static let shared = AgentNetworkCenter()
    
    private let baseURL = "https://telegpt-three.vercel.app"
    private let session: URLSession
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 120.0  // 增加到120秒
        config.timeoutIntervalForResource = 300.0  // 增加到300秒
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        self.session = URLSession(configuration: config)
    }
    
    /// 发送聊天请求
    /// - Parameters:
    ///   - messages: 聊天消息数组
    ///   - completion: 完成回调
    /// - Returns: 可取消的信号
    public func sendChatRequest(
        messages: [ChatMessage],
        completion: @escaping (NetworkResult<String>) -> Void
    ) -> Signal<String, NetworkError> {
        return Signal { subscriber in
            guard let url = URL(string: "\(self.baseURL)/generate") else {
                subscriber.putError(.invalidURL)
                return EmptyDisposable
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
            
            let chatRequest = ChatRequest(messages: messages)
            
            do {
                let jsonData = try JSONEncoder().encode(chatRequest)
                request.httpBody = jsonData
            } catch {
                subscriber.putError(.networkError(error))
                return EmptyDisposable
            }
            
            let task = self.session.dataTask(with: request) { data, response, error in
                if let error = error {
                    completion(.failure(NetworkError.networkError(error)))
                    subscriber.putError(.networkError(error))
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    guard 200...299 ~= httpResponse.statusCode else {
                        let serverError = NetworkError.serverError(httpResponse.statusCode)
                        completion(.failure(serverError))
                        subscriber.putError(serverError)
                        return
                    }
                }
                
                guard let data = data else {
                    completion(.failure(NetworkError.noData))
                    subscriber.putError(.noData)
                    return
                }
                
                if let responseString = String(data: data, encoding: .utf8) {
                    completion(.success(responseString))
                    subscriber.putNext(responseString)
                    subscriber.putCompletion()
                } else {
                    completion(.failure(NetworkError.decodingError))
                    subscriber.putError(NetworkError.decodingError)
                }
            }
            
            task.resume()
            
            return ActionDisposable {
                task.cancel()
            }
        }
    }
    
    /// 发送聊天请求（简化版本，直接返回结果）
    /// - Parameters:
    ///   - messages: 聊天消息数组
    ///   - completion: 完成回调
    public func sendChatRequestSimple(
        messages: [ChatMessage],
        completion: @escaping (NetworkResult<String>) -> Void
    ) {
        guard let url = URL(string: "\(baseURL)/generate") else {
            completion(.failure(NetworkError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        
        let chatRequest = ChatRequest(messages: messages)
        
        do {
            let jsonData = try JSONEncoder().encode(chatRequest)
            request.httpBody = jsonData
        } catch {
            completion(.failure(NetworkError.networkError(error)))
            return
        }
        
        let task = session.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(NetworkError.networkError(error)))
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    guard 200...299 ~= httpResponse.statusCode else {
                        completion(.failure(NetworkError.serverError(httpResponse.statusCode)))
                        return
                    }
                }
                
                guard let data = data else {
                    completion(.failure(NetworkError.noData))
                    return
                }
                
                if let responseString = String(data: data, encoding: .utf8) {
                    completion(.success(responseString))
                } else {
                    completion(.failure(NetworkError.decodingError))
                }
            }
        }
        
        task.resume()
    }
}
