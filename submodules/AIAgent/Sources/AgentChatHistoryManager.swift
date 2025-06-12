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
        print("AgentChatTable: 开始插入记录 - ID: \(model.id), 时间戳: \(model.timestamp)")
        
        do {
            let data = try JSONEncoder().encode(model)
            print("AgentChatTable: JSON编码成功，数据大小: \(data.count) 字节")
            
            let entry = CodableEntry(data: data)
            // 使用timestampKey而不是简单的id key，这样getAllChats的范围查询才能找到数据
            let keyToUse = self.timestampKey(timestamp: model.timestamp, id: model.id)
            
            print("AgentChatTable: 准备写入ValueBox - 表ID: \(self.table), Key长度: \(keyToUse.length)")
            
            // 检查ValueBox是否可用
            if self.valueBox == nil {
                print("AgentChatTable: 错误 - ValueBox为nil")
                return
            }
            
            self.valueBox.set(self.table, key: keyToUse, value: ReadBuffer(data: entry.data))
            print("AgentChatTable: 数据写入ValueBox完成 - ID: \(model.id)")
            
            // 立即验证写入是否成功
            if let verifyValue = self.valueBox.get(self.table, key: keyToUse) {
                print("AgentChatTable: 写入验证成功 - 可以立即读取到数据，大小: \(verifyValue.length) 字节")
            } else {
                print("AgentChatTable: 警告 - 写入后立即读取失败")
            }
            
        } catch {
            print("AgentChatTable: JSON编码失败: \(error.localizedDescription)")
        }
    }
    
    func get(id: Int32) -> LegacyAgentChatModel? {
        // 由于现在使用timestampKey存储，需要通过范围查询来查找指定id的记录
        var result: LegacyAgentChatModel? = nil
        
        // 使用正确的key范围来查询timestampKey格式的数据
        // timestampKey格式：8字节timestamp + 4字节id = 12字节
        let startKey = ValueBoxKey(length: 12)
        startKey.setInt64(0, value: 0) // 最小时间戳
        startKey.setInt32(8, value: 0) // 最小ID
        
        let endKey = ValueBoxKey(length: 12)
        endKey.setInt64(0, value: Int64.max) // 最大时间戳
        endKey.setInt32(8, value: Int32.max) // 最大ID
        
        self.valueBox.range(self.table, start: startKey, end: endKey.successor, values: { key, value in
            do {
                let entry = CodableEntry(data: value.makeData())
                let model = try JSONDecoder().decode(LegacyAgentChatModel.self, from: entry.data)
                if model.id == id {
                    result = model
                    return false // 找到后停止遍历
                }
            } catch {
                // 解码失败，继续下一个
            }
            return true
        }, limit: 0)
        
        return result
    }
    
    func update(_ model: LegacyAgentChatModel) {
        insert(model) // 使用相同的key覆盖
    }
    
    func delete(id: Int32) {
        // 由于现在使用timestampKey存储，需要先找到对应的记录获取timestamp，然后删除
        if let model = get(id: id) {
            let keyToDelete = self.timestampKey(timestamp: model.timestamp, id: model.id)
            self.valueBox.remove(self.table, key: keyToDelete, secure: false)
        }
    }
    
    func getAllChats() -> [LegacyAgentChatModel] {
        print("AgentChatTable: 开始getAllChats查询")
        var results: [LegacyAgentChatModel] = []
        var processedCount = 0
        var errorCount = 0
        
        print("AgentChatTable: 开始遍历ValueBox范围查询")
        
        // 使用正确的key范围来查询timestampKey格式的数据
        // timestampKey格式：8字节timestamp + 4字节id = 12字节
        let startKey = ValueBoxKey(length: 12)
        startKey.setInt64(0, value: 0) // 最小时间戳
        startKey.setInt32(8, value: 0) // 最小ID
        
        let endKey = ValueBoxKey(length: 12)
        endKey.setInt64(0, value: Int64.max) // 最大时间戳
        endKey.setInt32(8, value: Int32.max) // 最大ID
        
        self.valueBox.range(self.table, start: startKey, end: endKey.successor, values: { key, value in
            processedCount += 1
            print("AgentChatTable: 处理第\(processedCount)条记录 - Key长度: \(key.length), Value长度: \(value.length)")
            
            do {
                let entry = CodableEntry(data: value.makeData())
                let model = try JSONDecoder().decode(LegacyAgentChatModel.self, from: entry.data)
                results.append(model)
                print("AgentChatTable: 成功解码记录 - ID: \(model.id), 时间戳: \(model.timestamp)")
            } catch {
                errorCount += 1
                print("AgentChatTable: 解码失败 - 错误: \(error.localizedDescription)")
            }
            
            return true
        }, limit: 0)
        
        print("AgentChatTable: 范围查询完成 - 处理了\(processedCount)条记录，成功解码\(results.count)条，失败\(errorCount)条")
        
        let sortedResults = results.sorted { $0.timestamp > $1.timestamp }
        print("AgentChatTable: getAllChats 返回 \(sortedResults.count) 条记录（按时间戳降序排列）")
        
        // 打印前几条记录的详细信息
        for (index, result) in sortedResults.prefix(3).enumerated() {
            print("AgentChatTable: 结果[\(index)] - ID: \(result.id), 时间戳: \(result.timestamp), 角色: \(result.role)")
        }
        
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
        print("AgentChatHistoryManager: 开始添加聊天记录 - ID: \(chatModel.id), 用户消息长度: \(chatModel.userMessage.count), AI回复长度: \(chatModel.aiResponse.count)")
        
        guard let postbox = self.postbox, let table = self.table else {
            let error = NSError(domain: "AgentChatHistoryManager", code: 500, userInfo: [NSLocalizedDescriptionKey: "Manager not configured"])
            print("AgentChatHistoryManager: 错误 - 管理器未配置: \(error.localizedDescription)")
            completion(.failure(error))
            return
        }
        
        print("AgentChatHistoryManager: 准备插入数据 - 当前nextId: \(self.nextId)")
        
        let _ = postbox.transaction { _ -> (Bool, LegacyAgentChatModel?) in
            do {
                // 将新的AgentChatModel转换为存储格式
                let content = "用户消息: \(chatModel.userMessage)\n\nAI回复: \(chatModel.aiResponse)"
                
                let timestamp = Int64(Date().timeIntervalSince1970 * 1000) // 毫秒时间戳
                let model = LegacyAgentChatModel(id: self.nextId, role: "assistant", content: content, timestamp: timestamp)
                
                print("AgentChatHistoryManager: 准备插入模型 - ID: \(model.id), 时间戳: \(model.timestamp), 内容长度: \(model.content.count)")
                
                // 插入前检查表是否可用
                if table.valueBox == nil {
                    print("AgentChatHistoryManager: 错误 - ValueBox为空")
                    return (false, nil)
                }
                
                // 执行插入操作
                table.insert(model)
                print("AgentChatHistoryManager: 数据插入完成 - ID: \(model.id)")
                
                // 立即验证插入是否成功
                let insertedModel = table.get(id: model.id)
                if insertedModel != nil {
                    print("AgentChatHistoryManager: 插入验证成功 - 可以立即查询到ID: \(model.id)的记录")
                } else {
                    print("AgentChatHistoryManager: 警告 - 插入后立即查询失败，ID: \(model.id)")
                }
                
                // 更新nextId
                let oldNextId = self.nextId
                self.nextId += 1
                print("AgentChatHistoryManager: nextId更新 - 从 \(oldNextId) 到 \(self.nextId)")
                
                // 检查当前总记录数
                let totalCount = table.getAllChats().count
                print("AgentChatHistoryManager: 插入后总记录数: \(totalCount)")
                
                return (true, model)
            } catch {
                print("AgentChatHistoryManager: 插入过程中发生异常: \(error.localizedDescription)")
                return (false, nil)
            }
        }.start(next: { (success, model) in
            if success {
                print("AgentChatHistoryManager: 事务完成成功")
                if let insertedModel = model {
                    print("AgentChatHistoryManager: 成功插入记录 - ID: \(insertedModel.id), 时间戳: \(insertedModel.timestamp)")
                }
                completion(.success(()))
            } else {
                let error = NSError(domain: "AgentChatHistoryManager", code: 501, userInfo: [NSLocalizedDescriptionKey: "Failed to insert chat record"])
                print("AgentChatHistoryManager: 插入失败: \(error.localizedDescription)")
                completion(.failure(error))
            }
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
        print("AgentChatHistoryManager: 开始获取所有聊天记录")
        guard let postbox = self.postbox, let table = self.table else {
            print("AgentChatHistoryManager: 错误 - 管理器未配置，返回空数组")
            return []
        }
        var result: [AgentChatModel] = []
        let _ = postbox.transaction { _ in
            print("AgentChatHistoryManager: 在事务中开始查询所有聊天记录")
            let legacyChats = table.getAllChats()
            print("AgentChatHistoryManager: 从表中获取到 \(legacyChats.count) 条原始记录")
            
            // 打印前几条记录的详细信息
            for (index, chat) in legacyChats.prefix(3).enumerated() {
                print("AgentChatHistoryManager: 记录[\(index)] - ID: \(chat.id), 时间戳: \(chat.timestamp), 角色: \(chat.role), 内容长度: \(chat.content.count)")
            }
            
            result = legacyChats.map { self.convertToNewModel($0) }
            print("AgentChatHistoryManager: 转换后得到 \(result.count) 条聊天记录")
        }
        print("AgentChatHistoryManager: getAllChats 返回 \(result.count) 条记录")
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
