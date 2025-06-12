import Foundation
import Postbox
import TelegramCore

// MARK: - AgentChatModel
public struct AgentChatModel: Codable, Equatable {
    public let id: String
    public let userMessage: String
    public let aiResponse: String
    public let timestamp: Date
    public let messageCount: Int
    
    public init(id: String, userMessage: String, aiResponse: String, timestamp: Date, messageCount: Int) {
        self.id = id
        self.userMessage = userMessage
        self.aiResponse = aiResponse
        self.timestamp = timestamp
        self.messageCount = messageCount
    }
}

// MARK: - Legacy AgentChatModel for storage compatibility
public struct LegacyAgentChatModel: Codable, Equatable {
    public let id: Int32
    public let role: String
    public let content: String
    public let timestamp: Int64
    
    public init(id: Int32, role: String, content: String, timestamp: Int64) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
    }
}

// MARK: - AgentChatTable
final class AgentChatTable: Table {
    static func tableSpec(_ id: Int32) -> ValueBoxTable {
        return ValueBoxTable(id: id, keyType: .binary, compactValuesOnCreation: false)
    }
    
    private let sharedKey = ValueBoxKey(length: 4)
    
    private func key(id: Int32) -> ValueBoxKey {
        self.sharedKey.setInt32(0, value: id)
        return self.sharedKey
    }
    
    private func timestampKey(timestamp: Int64, id: Int32) -> ValueBoxKey {
        let key = ValueBoxKey(length: 8 + 4)
        key.setInt64(0, value: timestamp)
        key.setInt32(8, value: id)
        return key
    }
    
    // MARK: - CRUD Operations
    
    func insert(_ model: LegacyAgentChatModel) {
        if let data = try? JSONEncoder().encode(model) {
            let entry = CodableEntry(data: data)
            self.valueBox.set(self.table, key: self.key(id: model.id), value: ReadBuffer(data: entry.data))
        }
    }
    
    func get(id: Int32) -> LegacyAgentChatModel? {
        if let value = self.valueBox.get(self.table, key: self.key(id: id)) {
            let entry = CodableEntry(data: value.makeData())
            return try? JSONDecoder().decode(LegacyAgentChatModel.self, from: entry.data)
        }
        return nil
    }
    
    func update(_ model: LegacyAgentChatModel) {
        insert(model) // 使用相同的key覆盖
    }
    
    func delete(id: Int32) {
        self.valueBox.remove(self.table, key: self.key(id: id), secure: false)
    }
    
    func getAllChats() -> [LegacyAgentChatModel] {
        var results: [LegacyAgentChatModel] = []
        
        self.valueBox.range(self.table, start: ValueBoxKey(length: 0), end: ValueBoxKey(length: 0).successor, values: { key, value in
            let entry = CodableEntry(data: value.makeData())
            if let model = try? JSONDecoder().decode(LegacyAgentChatModel.self, from: entry.data) {
                results.append(model)
            }
            return true
        }, limit: 0)
        
        let sortedResults = results.sorted { $0.timestamp > $1.timestamp }
        print("AgentChatTable: getAllChats 返回 \(sortedResults.count) 条记录")
        return sortedResults
    }
    
    func getChatsWithPagination(index: Int, limit: Int) -> [LegacyAgentChatModel] {
        let allChats = getAllChats()
        let startIndex = index * limit
        let endIndex = min(startIndex + limit, allChats.count)
        
        print("AgentChatTable: getChatsWithPagination - 总记录数: \(allChats.count), 页码: \(index), 每页: \(limit), 开始索引: \(startIndex), 结束索引: \(endIndex)")
        
        guard startIndex < allChats.count else {
            print("AgentChatTable: 开始索引超出范围，返回空数组")
            return []
        }
        
        let result = Array(allChats[startIndex..<endIndex])
        print("AgentChatTable: getChatsWithPagination 返回 \(result.count) 条记录")
        return result
    }
    
    override func clearMemoryCache() {
        
    }
    
    override func beforeCommit() {
        
    }
}

// MARK: - AgentChatHistoryManager
public final class AgentChatHistoryManager {
    public static let shared = AgentChatHistoryManager()
    
    private var postbox: Postbox?
    private var table: AgentChatTable?
    private var nextId: Int32 = 1

    private init() {
        self.postbox = nil
        self.table = nil
    }
    
    public init(postbox: Postbox) {
        self.postbox = postbox
        self.table = AgentChatTable(valueBox: postbox.valueBox, table: postbox.agentChatTable, useCaches: true)
        self.loadNextId()
    }
    
    public func configure(with postbox: Postbox) {
        self.postbox = postbox
        self.table = AgentChatTable(valueBox: postbox.valueBox, table: postbox.agentChatTable, useCaches: true)
        self.loadNextId()
    }
    
    private func loadNextId() {
        guard let postbox = self.postbox, let table = self.table else {
            self.nextId = 1
            return
        }
        
        let _ = postbox.transaction { _ in
            let allChats = table.getAllChats()
            if allChats.isEmpty {
                self.nextId = 1
            } else {
                let maxId = allChats.map { $0.id }.max() ?? 0
                self.nextId = maxId + 1
            }
            print("AgentChatHistoryManager: 加载下一个ID: \(self.nextId), 现有聊天记录数: \(allChats.count)")
        }
    }
    
    // MARK: - Public Methods
    
    public func addChat(role: String, content: String) -> LegacyAgentChatModel? {
        guard let postbox = self.postbox, let table = self.table else { return nil }
        
        let timestamp = Int64(Date().timeIntervalSince1970 * 1000) // 毫秒时间戳
        let model = LegacyAgentChatModel(id: self.nextId, role: role, content: content, timestamp: timestamp)
        
        var result: LegacyAgentChatModel? = nil
        let _ = postbox.transaction { _ in
            table.insert(model)
            self.nextId += 1
            result = model
        }
        
        return result
    }
    
    /// 添加聊天记录（带完成回调）
    /// - Parameters:
    ///   - chatModel: 聊天模型
    ///   - completion: 完成回调
    public func addChatRecord(_ chatModel: AgentChatModel, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let postbox = self.postbox, let table = self.table else {
            completion(.failure(NSError(domain: "AgentChatHistoryManager", code: 500, userInfo: [NSLocalizedDescriptionKey: "Manager not configured"])))
            return
        }
        
        let _ = postbox.transaction { _ in
            // 将新的AgentChatModel转换为存储格式
            let content = "用户消息: \(chatModel.userMessage)\n\nAI回复: \(chatModel.aiResponse)"
            
            let timestamp = Int64(Date().timeIntervalSince1970 * 1000) // 毫秒时间戳
            let model = LegacyAgentChatModel(id: self.nextId, role: "assistant", content: content, timestamp: timestamp)
            
            table.insert(model)
            self.nextId += 1
            return ()
        }.start(next: { _ in
            completion(.success(()))
        })
    }
    
    public func getChat(id: Int32) -> LegacyAgentChatModel? {
        guard let postbox = self.postbox, let table = self.table else { return nil }
        var result: LegacyAgentChatModel? = nil
        let _ = postbox.transaction { _ in
            result = table.get(id: id)
        }
        return result
    }

    public func updateChat(_ model: LegacyAgentChatModel) {
        guard let postbox = self.postbox, let table = self.table else { return }
        let _ = postbox.transaction { _ in
            table.update(model)
        }
    }

    public func deleteChat(id: Int32) {
        guard let postbox = self.postbox, let table = self.table else { return }
        let _ = postbox.transaction { _ in
            table.delete(id: id)
        }
    }

    public func getAllChats() -> [AgentChatModel] {
        guard let postbox = self.postbox, let table = self.table else { return [] }
        var result: [AgentChatModel] = []
        let _ = postbox.transaction { _ in
            let legacyChats = table.getAllChats()
            result = legacyChats.map { self.convertToNewModel($0) }
        }
        return result
    }

    public func getChatsWithPagination(index: Int, limit: Int) -> [AgentChatModel] {
        guard let postbox = self.postbox, let table = self.table else { return [] }
        var result: [AgentChatModel] = []
        let _ = postbox.transaction { _ in
            let legacyChats = table.getChatsWithPagination(index: index, limit: limit)
            result = legacyChats.map { self.convertToNewModel($0) }
        }
        return result
    }

    public func clearAllChats() {
        guard let postbox = self.postbox, let table = self.table else { return }
        let _ = postbox.transaction { _ in
            let allChats = table.getAllChats()
            for chat in allChats {
                table.delete(id: chat.id)
            }
            self.nextId = 1
        }
    }

    public func getChatCount() -> Int {
        guard let postbox = self.postbox, let table = self.table else { return 0 }
        var result = 0
        let _ = postbox.transaction { _ in
            result = table.getAllChats().count
        }
        return result
    }
    
    // MARK: - Conversion Methods
    
    /// 将LegacyAgentChatModel转换为新的AgentChatModel
    private func convertToNewModel(_ legacyModel: LegacyAgentChatModel) -> AgentChatModel {
        // 解析content字段，提取用户消息和AI回复
        let content = legacyModel.content
        var userMessage = ""
        var aiResponse = ""
        
        if content.contains("用户消息:") && content.contains("AI回复:") {
            let components = content.components(separatedBy: "\n\nAI回复: ")
            if components.count == 2 {
                userMessage = components[0].replacingOccurrences(of: "用户消息: ", with: "")
                aiResponse = components[1]
            } else {
                aiResponse = content
            }
        } else {
            aiResponse = content
        }
        
        return AgentChatModel(
            id: String(legacyModel.id),
            userMessage: userMessage,
            aiResponse: aiResponse,
            timestamp: Date(timeIntervalSince1970: Double(legacyModel.timestamp) / 1000.0),
            messageCount: 0 // 默认值，因为旧数据没有这个字段
        )
    }
    
    public func getChatCount(completion: @escaping (Result<Int, Error>) -> Void) {
        guard let postbox = self.postbox, let table = self.table else {
            completion(.failure(NSError(domain: "AgentChatHistoryManager", code: 500, userInfo: [NSLocalizedDescriptionKey: "Manager not configured"])))
            return
        }
        let _ = postbox.transaction { _ in
            let count = table.getAllChats().count
            return count
        }.start(next: { count in
            completion(.success(count))
        })
    }

    public func getChatRecordsPaginated(
        page: Int,
        pageSize: Int,
        completion: @escaping (Result<[AgentChatModel], Error>) -> Void
    ) {
        print("AgentChatHistoryManager: 开始获取分页聊天记录，页码: \(page), 每页大小: \(pageSize)")
        guard let postbox = self.postbox, let table = self.table else {
            print("AgentChatHistoryManager: 管理器未配置")
            completion(.failure(NSError(domain: "AgentChatHistoryManager", code: 500, userInfo: [NSLocalizedDescriptionKey: "Manager not configured"])))
            return
        }
        let _ = postbox.transaction { _ in
            let records = table.getChatsWithPagination(index: page, limit: pageSize)
            print("AgentChatHistoryManager: 从表中获取到 \(records.count) 条原始记录")
            let convertedRecords = records.map { self.convertToNewModel($0) }
            print("AgentChatHistoryManager: 转换后得到 \(convertedRecords.count) 条聊天记录")
            return convertedRecords
        }.start(next: { records in
            completion(.success(records))
        })
    }

    public func clearAllChatRecords(completion: @escaping (Result<Void, Error>) -> Void) {
        guard let postbox = self.postbox, let table = self.table else {
            completion(.failure(NSError(domain: "AgentChatHistoryManager", code: 500, userInfo: [NSLocalizedDescriptionKey: "Manager not configured"])))
            return
        }
        let _ = postbox.transaction { _ in
            let allChats = table.getAllChats()
            for chat in allChats {
                table.delete(id: chat.id)
            }
            self.nextId = 1
            return ()
        }.start(next: { _ in
            completion(.success(()))
        })
    }

    public func deleteChatRecord(chatId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let postbox = self.postbox, let table = self.table else {
            completion(.failure(NSError(domain: "AgentChatHistoryManager", code: 500, userInfo: [NSLocalizedDescriptionKey: "Manager not configured"])))
            return
        }
        let _ = postbox.transaction { _ -> Bool in
            // 由于当前存储使用Int32 ID，需要转换或查找对应记录
            // 这里简化处理，遍历所有记录找到匹配的ID
            let allChats = table.getAllChats()
            for chat in allChats {
                // 假设chatId是字符串形式的ID，需要匹配
                if String(chat.id) == chatId {
                    table.delete(id: chat.id)
                    return true // 找到并删除成功
                }
            }
            return false // 没找到对应记录
        }.start(next: { found in
            if found {
                completion(.success(()))
            } else {
                completion(.failure(NSError(domain: "AgentChatHistoryManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "Chat record not found"])))
            }
        })
    }
}
