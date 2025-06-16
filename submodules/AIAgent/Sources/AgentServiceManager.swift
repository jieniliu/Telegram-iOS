import Foundation
import SwiftSignalKit
import TelegramCore
import Postbox
import AccountContext
import Foundation

/// 服务管理器 - 结合业务逻辑调用网络接口
public final class AgentServiceManager {
    public static let shared = AgentServiceManager()
    
    private let networkCenter: AgentNetworkCenter
    public let historyManager: AgentChatHistoryManager
    
    private init() {
        self.networkCenter = AgentNetworkCenter.shared
        self.historyManager = AgentChatHistoryManager.shared
    }
    
    /// 处理聊天记录总结请求
    /// - Parameters:
    ///   - completion: 完成回调，返回总结结果
    public func processChatSummary(completion: @escaping (Result<String, Error>) -> Void) {
        processChatSummaryWithRetry(retryCount: 3, completion: completion)
    }
    
    /// 带重试机制的聊天记录总结请求
    /// - Parameters:
    ///   - retryCount: 重试次数
    ///   - completion: 完成回调
    private func processChatSummaryWithRetry(retryCount: Int, completion: @escaping (Result<String, Error>) -> Void) {
        // 1. 获取未读消息
        SmallGroupsMessageManager.shared.loadUnreadMessages { [weak self] momentEntries in
            guard let self = self, momentEntries.count > 0 else {
                completion(.failure(NetworkError.noData as Error))
                return
            }
            
            // 2. 转换消息格式
            let messageList = self.convertMomentEntriesToMessageList(momentEntries)
            
            // 3. 构建请求参数
            let requestContent = self.buildRequestContent(with: messageList)
            
            // 4. 创建聊天消息
            let chatMessage = ChatMessage(
                id: UUID().uuidString,
                role: "user",
                content: requestContent
            )
            
            // 5. 发送网络请求
            self.networkCenter.sendChatRequestSimple(messages: [chatMessage]) { result in
                switch result {
                case .success(let response):
                    // 6. 保存聊天记录
                    let chatModel = AgentChatModel(
                        id: UUID().uuidString,
                        userMessage: requestContent,
                        aiResponse: response,
                        timestamp: Date(),
                        messageCount: messageList.count
                    )
                    
                    self.historyManager.addChatRecord(chatModel) { saveResult in
                        switch saveResult {
                        case .success:
                            print("聊天记录保存成功")
                        case .failure(let error):
                            print("聊天记录保存失败: \(error)")
                        }
                    }
                    
                    completion(.success(response))
                    
                case .failure(let error):
                    // 检查是否为网络超时错误且还有重试次数
                    if retryCount > 0, self.isRetryableError(error) {
                        print("网络请求失败，剩余重试次数: \(retryCount - 1)，错误: \(error.localizedDescription)")
                        // 延迟2秒后重试
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            self.processChatSummaryWithRetry(retryCount: retryCount - 1, completion: completion)
                        }
                    } else {
                        completion(.failure(error))
                    }
                }
            }
        }
    }
    
    /// 获取聊天历史记录
    /// - Parameters:
    ///   - page: 页码（从0开始）
    ///   - pageSize: 每页大小
    ///   - completion: 完成回调
    public func getChatHistory(
        page: Int = 0,
        pageSize: Int = 20,
        completion: @escaping (Result<[AgentChatModel], Error>) -> Void
    ) {
        print("AgentServiceManager: 开始获取聊天历史，页码: \(page), 每页大小: \(pageSize)")
        historyManager.getChatRecordsPaginated(
            page: page,
            pageSize: pageSize,
            completion: { result in
                switch result {
                case .success(let chatHistory):
                    print("AgentServiceManager: 成功获取聊天历史，共 \(chatHistory.count) 条记录")
                case .failure(let error):
                    print("AgentServiceManager: 获取聊天历史失败: \(error)")
                }
                completion(result)
            }
        )
    }
    
    /// 获取聊天记录总数
    /// - Parameter completion: 完成回调
    public func getChatCount(completion: @escaping (Result<Int, Error>) -> Void) {
        historyManager.getChatCount(completion: completion)
    }
    
    /// 判断是否为可重试的错误
    /// - Parameter error: 错误对象
    /// - Returns: 是否可重试
    private func isRetryableError(_ error: Error) -> Bool {
        // 检查是否为NetworkError类型
        if let networkError = error as? NetworkError {
            switch networkError {
            case .networkError(let underlyingError):
                // 检查底层错误是否为超时或连接错误
                let nsError = underlyingError as NSError
                return nsError.domain == NSURLErrorDomain && 
                       (nsError.code == NSURLErrorTimedOut || 
                        nsError.code == NSURLErrorCannotConnectToHost ||
                        nsError.code == NSURLErrorNetworkConnectionLost ||
                        nsError.code == NSURLErrorNotConnectedToInternet)
            case .serverError(let code):
                // 5xx服务器错误可以重试
                return code >= 500
            default:
                return false
            }
        }
        
        // 检查NSError类型的网络错误
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            return nsError.code == NSURLErrorTimedOut ||
                   nsError.code == NSURLErrorCannotConnectToHost ||
                   nsError.code == NSURLErrorNetworkConnectionLost ||
                   nsError.code == NSURLErrorNotConnectedToInternet
        }
        
        return false
    }
    
    /// 清空所有聊天记录
    /// - Parameter completion: 完成回调
    public func clearAllChatHistory(completion: @escaping (Result<Void, Error>) -> Void) {
        historyManager.clearAllChatRecords(completion: completion)
    }
    
    /// 删除指定聊天记录
    /// - Parameters:
    ///   - chatId: 聊天记录ID
    ///   - completion: 完成回调
    public func deleteChatRecord(
        chatId: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        historyManager.deleteChatRecord(chatId: chatId, completion: completion)
    }
    
    // MARK: - Private Methods
    
    /// 将MomentEntry数组转换为消息列表JSON字符串（已废弃）
    private func convertMomentEntriesToMessageList(_ momentEntries: [Any]) -> [MessageItem] {
        // 方法已废弃，返回空数组
        print("convertMomentEntriesToMessageList 已废弃，现在直接使用 SmallGroupsMessageManager 的新逻辑")
        return []
    }
    
    /// 构建请求内容
    private func buildRequestContent(with messageList: [MessageItem]) -> String {
        // 获取默认总结提示词
        let summaryPrompt = defaultSummaryPrompt
        
        // 构建消息列表JSON
        let messageListWrapper = MessageListWrapper(messageList: messageList)
        
        do {
            let encoder = JSONEncoder()
            if #available(iOS 13.0, *) {
                encoder.outputFormatting = .withoutEscapingSlashes
            }
            let jsonData = try encoder.encode(messageListWrapper)
            let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"
            
            // 组合提示词和消息数据
            return "\(summaryPrompt)\n\n\(jsonString)"
        } catch {
            print("JSON编码失败: \(error)")
            return summaryPrompt
        }
    }
    
    /// 获取聊天标题
    private func getChatTitle(from message: Message) -> String {
        // 这里需要根据实际的Telegram API来获取聊天标题
        // 暂时返回默认值
        return "Unknown Chat"
    }
    
    /// 获取聊天类型
    private func getChatType(from message: Message) -> String {
        let peerId = message.id.peerId
        
        if peerId.namespace == Namespaces.Peer.CloudUser {
            return "private"
        } else if peerId.namespace == Namespaces.Peer.CloudGroup {
            return "group"
        } else if peerId.namespace == Namespaces.Peer.CloudChannel {
            return "channel"
        } else {
            return "unknown"
        }
    }
    
    /// 获取发送者名称
    private func getSenderName(from message: Message) -> String {
        if let author = message.author {
            if let user = author as? TelegramUser {
                var name = ""
                if let firstName = user.firstName {
                    name += firstName
                }
                if let lastName = user.lastName {
                    if !name.isEmpty {
                        name += " "
                    }
                    name += lastName
                }
                return name.isEmpty ? "Unknown User" : name
            }
        }
        return "Unknown User"
    }
    
    /// 获取消息内容
    private func getMessageContent(from message: Message) -> String {
        // 直接返回消息文本内容
        return message.text
    }
}

// MARK: - Data Models

/// 消息项结构
public struct MessageItem: Codable {
    public let chatId: String
    public let chatTitle: String
    public let chatType: String
    public let senderId: String
    public let senderName: String
    public let date: Int
    public let messageId: Int
    public let content: String
    
    public init(
        chatId: String,
        chatTitle: String,
        chatType: String,
        senderId: String,
        senderName: String,
        date: Int,
        messageId: Int,
        content: String
    ) {
        self.chatId = chatId
        self.chatTitle = chatTitle
        self.chatType = chatType
        self.senderId = senderId
        self.senderName = senderName
        self.date = date
        self.messageId = messageId
        self.content = content
    }
}

/// 消息列表包装器
public struct MessageListWrapper: Codable {
    public let messageList: [MessageItem]
    
    public init(messageList: [MessageItem]) {
        self.messageList = messageList
    }
}
