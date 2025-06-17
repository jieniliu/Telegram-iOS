//
import UIKit
import Display
import AsyncDisplayKit
import AccountContext
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import PresentationDataUtils

/// 单例类：管理小群组（少于50人）和私聊的未读消息获取
public final class SmallGroupsMessageManager {
    public static let shared = SmallGroupsMessageManager()
    
    private var context: AccountContext?
    private var disposables: [Disposable] = []
    // 移除了 entries: [MomentEntry] 属性，现在直接使用 AgentServiceManager 处理数据
    
    private init() {}
    
    /// 配置管理器
    /// - Parameter context: 账户上下文
    public func configure(with context: AccountContext) {
        self.context = context
    }
    
    /// 加载未读消息
    public func loadUnreadMessages(completion: @escaping ([Any], AccountContext?) -> Void = { _, _ in }) {
        guard let context = self.context else {
            print("Context not configured")
            completion([], nil)
            return
        }
        
        // 获取所有对话
        let signal = context.account.postbox.tailChatListView(
            groupId: .root,
            count: 10000,
            summaryComponents: ChatListEntrySummaryComponents()
        )
        
        let disposable = signal.start(next: { [weak self] (view, _) in
            guard let strongSelf = self else { return }
            
            var groupIds: [PeerId] = []
            
            for entry in view.entries {
                switch entry {
                case let .MessageEntry(entryData):
                    if let peer = entryData.renderedPeer.peer {
                        // 检查是否为群组且成员数少于50
                        if let group = peer as? TelegramGroup {
                            if group.participantCount < 50 {
                                groupIds.append(peer.id)
                            }
                        }
                        // 检查是否为私聊
                        else if peer is TelegramUser {
                            groupIds.append(peer.id)
                        }
                    }
                default:
                    break
                }
            }
            
            // 加载这些群组的未读消息
            if groupIds.isEmpty {
                completion([], context)
            } else {
                strongSelf.loadUnreadMessagesForGroups(groupIds: groupIds, completion: completion)
            }
        })
        
        self.disposables.append(disposable)
    }
    
    /// 为指定群组加载未读消息
    /// - Parameter groupIds: 群组ID列表
    /// - Parameter completion: 完成回调
    private func loadUnreadMessagesForGroups(groupIds: [PeerId], completion: @escaping ([Any], AccountContext?) -> Void) {
        guard let context = self.context else { return }
        
        let keys: [PostboxViewKey] = groupIds.map { groupId in
            return .combinedReadState(peerId: groupId, handleThreads: false)
        }
        
        let combinedSignal = context.account.postbox.combinedView(keys: keys)
        
        let disposable = combinedSignal.start(next: { [weak self] views in
            guard let strongSelf = self else { return }
            
            var loadedChats = 0
            let totalChats = groupIds.count
            var allMessages: [Any] = []
            
            for (index, groupId) in groupIds.enumerated() {
                let readStateView = views.views[.combinedReadState(peerId: groupId, handleThreads: false)] as? CombinedReadStateView
                let readState = readStateView?.state
                
                // 获取消息历史
                let historySignal = context.account.postbox.aroundMessageHistoryViewForLocation(
                    .peer(peerId: groupId, threadId: nil),
                    anchor: .upperBound,
                    ignoreMessagesInTimestampRange: nil,
                    ignoreMessageIds: Set(),
                    count: 50,
                    fixedCombinedReadStates: nil,
                    topTaggedMessageIdNamespaces: Set(),
                    tag: nil,
                    appendMessagesFromTheSameGroup: false,
                    namespaces: .not(Namespaces.Message.allNonRegular),
                    orderStatistics: .combinedLocation
                )
                
                let historyDisposable = historySignal.start(next: { [weak strongSelf] (historyView, _, _) in
                    guard let strongSelf = strongSelf else { return }
                    
                    // 过滤出未读消息（最近7天内）
                    let currentTime = Int32(Date().timeIntervalSince1970)
                    let sevenDaysAgo = currentTime - (7 * 24 * 60 * 60)
                    
                    var unreadMessages: [Message] = []
                    
                    for entry in historyView.entries {
                        let message = entry.message
                        // 检查消息是否在最近7天内
                        if message.timestamp >= sevenDaysAgo {
                            // 检查是否未读
                            if let readState = readState {
                                // 正确访问 CombinedPeerReadState 中的 maxIncomingReadId
                                var maxIncomingReadId: Int32 = 0
                                for (_, state) in readState.states {
                                    if case let .idBased(maxIncoming, _, _, _, _) = state {
                                        maxIncomingReadId = maxIncoming
                                        break
                                    }
                                }
                                if message.id.id > maxIncomingReadId {
                                    unreadMessages.append(message)
                                }
                            } else {
                                // 如果没有读取状态，认为是未读
                                unreadMessages.append(message)
                            }
                        }
                    }
                    
                    // 按时间戳排序（最新的在前）
                    unreadMessages.sort { $0.timestamp > $1.timestamp }
                    
                    // 处理未读消息
                    for message in unreadMessages {
                        // 提取消息内容
                        var messageText = ""
                        var messageFlags: MessageFlags = []
                        var forwardInfo: MessageForwardInfo?
                        
                        for media in message.media {
                            if let text = media as? TelegramMediaWebpage {
                                // 处理网页媒体
                            }
                        }
                        
                        for attribute in message.attributes {
                            if let textAttribute = attribute as? TextEntitiesMessageAttribute {
                                messageText = message.text
                            }
                            if let forwardAttribute = attribute as? ForwardSourceInfoAttribute {
                                // 处理转发信息
                            }
                        }
                        
                        messageText = message.text
                        messageFlags = message.flags
                        forwardInfo = message.forwardInfo
                        // 将消息添加到结果数组
                        allMessages.append(message)
                    }
                    
                    loadedChats += 1
                    if loadedChats == totalChats {
                        // 所有聊天都已加载完成
                        print("All chats loaded. Total unread messages processed: \(allMessages.count)")
                        
                        // 调用完成回调
                        completion(allMessages, context)
                    }
                })
                
                strongSelf.disposables.append(historyDisposable)
            }
            
        })
        
        self.disposables.append(disposable)
    }

    deinit {
        cleanup()
    }
    
    /// 清理资源
    public func cleanup() {
        for disposable in disposables {
            disposable.dispose()
        }
        disposables.removeAll()
        // entries 属性已移除
    }
}
