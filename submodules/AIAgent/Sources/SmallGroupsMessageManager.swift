import Foundation
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
    
    /// 加载小群组的最新消息（已废弃，现在使用 AgentServiceManager）
    /// - Parameter completion: 完成回调，返回消息条目数组
    func loadUnreadMessages(completion: @escaping ([Any]) -> Void) {
        guard let context = self.context else {
            completion([])
            return
        }
        
        // 方法已废弃，直接返回空数组
        print("SmallGroupsMessageManager.loadUnreadMessages 已废弃，请使用 AgentServiceManager")
        completion([])
        return
        
        // 获取聊天列表
        let chatListSignal = context.engine.messages.chatList(group: .root, count: 200)
        
        let disposable = (chatListSignal
            |> deliverOnMainQueue).start(next: { [weak self] chatList in
                guard let strongSelf = self else { return }
                
                var smallGroupIds: [EnginePeer.Id] = []
                var pendingChecks = 0
                var completedChecks = 0
                
                // 筛选人数少于50人的群组和私聊
                for item in chatList.items {
                    guard let peer = item.renderedPeer.peer else { continue }
                    let peerId: PeerId = peer.id
                    
                    // 检查是否为群组或私聊
                    switch peer {
                    case let .legacyGroup(group):
                        // 普通群组，直接检查participantCount
                        if group.participantCount < 5000 {
                            smallGroupIds.append(peerId)
                        }
                    case let .channel(channel):
                        // 频道/超级群组，需要检查缓存数据中的成员数量
                        if case .group = channel.info {
                            pendingChecks += 1
                            strongSelf.checkChannelMemberCount(peerId: peerId) { memberCount in
                                completedChecks += 1
                                if memberCount < 5000 {
                                    smallGroupIds.append(peerId)
                                }
                                
                                // 如果所有异步检查都完成了，加载消息
                                if completedChecks == pendingChecks {
                                    strongSelf.loadMessagesForGroups(groupIds: smallGroupIds, completion: completion)
                                }
                            }
                        }
                    case .user:
                        // 私聊，直接添加到列表中
                        smallGroupIds.append(peerId)
                    default:
                        break
                    }
                }
                
                // 如果没有需要异步检查的群组，直接加载普通群组的消息
                if pendingChecks == 0 {
                    strongSelf.loadMessagesForGroups(groupIds: smallGroupIds, completion: completion)
                }
            })
        
        self.disposables.append(disposable)
    }
    
    /// 检查频道/超级群组的成员数量
    private func checkChannelMemberCount(peerId: EnginePeer.Id, completion: @escaping (Int) -> Void) {
        guard let context = self.context else {
            completion(0)
            return
        }
        
        let peerViewSignal = context.account.viewTracker.peerView(peerId, updateData: false)
        
        let disposable = (peerViewSignal
            |> take(1)
            |> deliverOnMainQueue).start(next: { peerView in
                var memberCount = 0
                
                if let cachedData = peerView.cachedData as? CachedChannelData {
                    memberCount = Int(cachedData.participantsSummary.memberCount ?? 0)
                } else if let cachedData = peerView.cachedData as? CachedGroupData {
                    if let participants = cachedData.participants {
                        memberCount = participants.participants.count
                    }
                }
                
                completion(memberCount)
            })
        
        self.disposables.append(disposable)
    }
    
    /// 为指定群组和私聊加载最新消息
    private func loadMessagesForGroups(groupIds: [EnginePeer.Id], completion: @escaping ([Any]) -> Void) {
        guard let context = self.context else {
            completion([])
            return
        }
        
        var loadedChats = 0
        let totalChats = groupIds.count
        
        guard totalChats > 0 else {
            completion([])
            return
        }
        
        for groupId in groupIds {
            // 使用aroundMessageHistoryViewForLocation获取每个群组/私聊的最新5条消息
            let historySignal = context.account.postbox.aroundMessageHistoryViewForLocation(
                .peer(peerId: groupId, threadId: nil),
                anchor: .upperBound,
                ignoreMessagesInTimestampRange: nil,
                ignoreMessageIds: Set(),
                count: 5,
                fixedCombinedReadStates: nil,
                topTaggedMessageIdNamespaces: Set(),
                tag: nil,
                appendMessagesFromTheSameGroup: false,
                namespaces: .not(Namespaces.Message.allNonRegular),
                orderStatistics: []
            )
            
            let disposable = (historySignal
                |> take(1)
                |> deliverOnMainQueue).start(next: { [weak self] (messageHistoryView, _, _) in
                    guard let strongSelf = self else { return }
                    
                    // 处理获取到的消息
                    for entry in messageHistoryView.entries {
                        // 移除了 MomentEntry 的创建，现在直接使用 AgentServiceManager 处理
                    }
                    
                    loadedChats += 1
                    
                    // 如果所有群组/私聊的消息都加载完成
                    if loadedChats == totalChats {
                        // 方法已废弃，返回空数组
                        completion([])
                    }
                })
            
            self.disposables.append(disposable)
        }
    }
    
    /// 获取少于50人群组和私聊的未读消息
    /// - Parameter completion: 完成回调，返回未读消息条目数组
     func getUnreadMessagesForSmallGroups(completion: @escaping ([Any]) -> Void) {
        // 方法已废弃，直接返回空数组
        print("SmallGroupsMessageManager.getUnreadMessagesForSmallGroups 已废弃，请使用 AgentServiceManager")
        completion([])
        return
        guard let context = self.context else {
            completion([])
            return
        }
        
        // 移除了 unreadEntries: [MomentEntry] 变量
        
        // 获取聊天列表
        let chatListSignal = context.engine.messages.chatList(group: .root, count: 200)
        
        let disposable = (chatListSignal
            |> deliverOnMainQueue).start(next: { [weak self] chatList in
                guard let strongSelf = self else { return }
                
                var smallGroupIds: [EnginePeer.Id] = []
                var pendingChecks = 0
                var completedChecks = 0
                
                // 筛选人数少于50人的群组和私聊
                for item in chatList.items {
                    guard let peer = item.renderedPeer.peer else { continue }
                    let peerId: PeerId = peer.id
                    
                    // 检查是否为群组或私聊
                    switch peer {
                    case let .legacyGroup(group):
                        // 普通群组，直接检查participantCount
                        if group.participantCount < 50 {
                            smallGroupIds.append(peerId)
                        }
                    case let .channel(channel):
                        // 频道/超级群组，需要检查缓存数据中的成员数量
                        if case .group = channel.info {
                            pendingChecks += 1
                            strongSelf.checkChannelMemberCount(peerId: peerId) { memberCount in
                                completedChecks += 1
                                if memberCount < 50 {
                                    smallGroupIds.append(peerId)
                                }
                                
                                // 如果所有异步检查都完成了，加载未读消息
                                if completedChecks == pendingChecks {
                                    strongSelf.loadUnreadMessagesForGroups(groupIds: smallGroupIds, completion: completion)
                                }
                            }
                        }
                    case .user:
                        // 私聊，直接添加到列表中
                        smallGroupIds.append(peerId)
                    default:
                        break
                    }
                }
                
                // 如果没有需要异步检查的群组，直接加载普通群组的未读消息
                if pendingChecks == 0 {
                    strongSelf.loadUnreadMessagesForGroups(groupIds: smallGroupIds, completion: completion)
                }
            })
        
        self.disposables.append(disposable)
    }
    
    /// 为指定群组和私聊加载未读消息
    private func loadUnreadMessagesForGroups(groupIds: [EnginePeer.Id], completion: @escaping ([Any]) -> Void) {
        // 方法已废弃，直接返回空数组
        print("SmallGroupsMessageManager.loadUnreadMessagesForGroups 已废弃")
        completion([])
        return
        guard let context = self.context else {
            completion([])
            return
        }
        
        // 移除了 unreadEntries: [MomentEntry] 变量
        var loadedChats = 0
        let totalChats = groupIds.count
        
        guard totalChats > 0 else {
            completion([])
            return
        }
        
        for groupId in groupIds {
            // 获取聊天的读取状态
            let _ = context.account.postbox.combinedView(keys: [.basicPeer(groupId), .peerChatState(peerId: groupId)])
            
            // 先获取读取状态，然后获取消息历史
            let readStatesSignal = context.account.postbox.transaction({ transaction -> [(MessageId.Namespace, PeerReadState)]? in
                return transaction.getPeerReadStates(groupId)
            })
            
            let disposable = (readStatesSignal
                |> deliverOnMainQueue).start(next: { [weak self] readStates in
                    guard let strongSelf = self else { return }
                    
                    var readInboxMaxId: MessageId.Id = 0
                    
                    // 获取已读消息的最大ID
                    if let readStates = readStates {
                        for (namespace, state) in readStates {
                            if namespace == Namespaces.Message.Cloud {
                                if case let .idBased(maxIncomingReadId, _, _, _, _) = state {
                                    readInboxMaxId = maxIncomingReadId
                                }
                                break
                            }
                        }
                    }
                    
                    print("=== 调试信息 ===\n群组/私聊ID: \(groupId)\n已读最大消息ID: \(readInboxMaxId)\n读取状态: \(readStates?.description ?? "无")\n================")
                    
                    // 获取该群组的最新消息
                    let historySignal = context.account.postbox.aroundMessageHistoryViewForLocation(
                        .peer(peerId: groupId, threadId: nil),
                        anchor: .upperBound,
                        ignoreMessagesInTimestampRange: nil,
                        ignoreMessageIds: Set(),
                        count: 50, // 获取更多消息以筛选未读
                        fixedCombinedReadStates: nil,
                        topTaggedMessageIdNamespaces: Set(),
                        tag: nil,
                        appendMessagesFromTheSameGroup: false,
                        namespaces: .not(Namespaces.Message.allNonRegular),
                        orderStatistics: [],
                        additionalData: [.peer(groupId)]
                    )
                    
                    let historyDisposable = (historySignal
                        |> take(1)
                        |> deliverOnMainQueue).start(next: { (messageHistoryView, _, _) in
                            
                            // 筛选未读消息（消息ID大于已读最大ID的消息）
                            print("开始检查消息，总共 \(messageHistoryView.entries.count) 条消息")
                            for entry in messageHistoryView.entries {
                                let message = entry.message
                                print("检查消息ID: \(message.id.id), 已读最大ID: \(readInboxMaxId), 是否传入: \(message.flags.contains(.Incoming)), 消息标志: \(message.flags)")
                                // 检查消息是否未读且是传入消息（不是自己发送的）
                                if message.id.id > readInboxMaxId && message.flags.contains(.Incoming) {
                                    // 打印消息的详细信息
                                    print("=== 未读消息详情 ===")
                                    print("消息ID: \(message.id)")
                                    print("消息时间戳: \(message.timestamp)")
                                    print("消息日期: \(Date(timeIntervalSince1970: TimeInterval(message.timestamp)))")
                                    
                                    // 获取发送者信息
                                    if let author = message.author {
                                        print("发送者ID: \(author.id)")
                                        print("发送者名字: \(EnginePeer(author).displayTitle(strings: context.sharedContext.currentPresentationData.with { $0 }.strings, displayOrder: context.sharedContext.currentPresentationData.with { $0 }.nameDisplayOrder))")
                                        if let username = author.addressName {
                                            print("发送者用户名: @\(username)")
                                        }
                                    } else {
                                        print("发送者: 未知")
                                    }
                                    
                                    // 获取群组信息
                                    var groupPeer: Peer?
                                    for additionalData in messageHistoryView.additionalData {
                                        if case let .peer(peerId, peer) = additionalData, peerId == groupId {
                                            groupPeer = peer
                                            break
                                        }
                                    }
                                    
                                    if let peer = groupPeer {
                                        print("群组ID: \(peer.id)")
                                        print("群组名称: \(EnginePeer(peer).displayTitle(strings: context.sharedContext.currentPresentationData.with { $0 }.strings, displayOrder: context.sharedContext.currentPresentationData.with { $0 }.nameDisplayOrder))")
                                    } else {
                                        print("群组ID: \(groupId)")
                                        print("群组名称: 未知")
                                    }
                                    
                                    // 获取消息内容
                                    var messageContent = "无内容"
                                    for media in message.media {
                                        switch media {
                                        case let textMedia as TelegramMediaFile:
                                            if textMedia.isSticker {
                                                messageContent = "[贴纸]"
                                            } else if textMedia.isVideo {
                                                messageContent = "[视频]"
                                            } else if textMedia.isVoice {
                                                messageContent = "[语音]"
                                            } else {
                                                messageContent = "[文件: \(textMedia.fileName ?? "未知")]"
                                            }
                                        case _ as TelegramMediaImage:
                                            messageContent = "[图片]"
                                        case let contact as TelegramMediaContact:
                                            messageContent = "[联系人: \(contact.firstName) \(contact.lastName)]"
                                        case let location as TelegramMediaMap:
                                            messageContent = "[位置: \(location.latitude), \(location.longitude)]"
                                        case _ as TelegramMediaPoll:
                                            messageContent = "[投票]"
                                        default:
                                            break
                                        }
                                    }
                                    
                                    // 如果有文本内容，优先显示文本
                                    if !message.text.isEmpty {
                                        messageContent = message.text
                                    }
                                    
                                    print("消息内容: \(messageContent)")
                                    
                                    // 消息标志
                                    var flags: [String] = []
                                    if message.flags.contains(.Incoming) {
                                        flags.append("接收")
                                    }
                                    if message.flags.contains(.Failed) {
                                        flags.append("失败")
                                    }
//                                    if message.flags.contains(.Pending) {
//                                        flags.append("发送中")
//                                    }
                                    if message.flags.contains(.Unsent) {
                                        flags.append("未发送")
                                    }
                                    print("消息标志: \(flags.joined(separator: ", "))")
                                    
                                    // 转发信息
                                    if let forwardInfo = message.forwardInfo {
//                                        if let source = forwardInfo.source {
//                                            print("转发来源: \(source.displayTitle(strings: context.sharedContext.currentPresentationData.with { $0 }.strings, displayOrder: .firstLast))")
//                                        }
                                        if let authorSignature = forwardInfo.authorSignature {
                                            print("转发作者签名: \(authorSignature)")
                                        }
                                    }
                                    
                                    // 回复信息
//                                    if let replyToMessageId = message.replyToMessageId {
//                                        print("回复消息ID: \(replyToMessageId)")
//                                    }
                                    
                                    print("===================")
                                    print("")
                                    
                                    // 移除了 MomentEntry 的创建和添加操作
                                }
                            }
                            
                            loadedChats += 1
                            
                            // 如果所有群组/私聊的消息都加载完成
                            if loadedChats == totalChats {
                                // 方法已废弃，返回空数组
                                completion([])
                            }
                        })
                    
                    strongSelf.disposables.append(historyDisposable)
                })
            
            self.disposables.append(disposable)
        }
    }
    
    /// 清理资源
    public func cleanup() {
        for disposable in disposables {
            disposable.dispose()
        }
        disposables.removeAll()
        // entries 属性已移除
    }
    
    deinit {
        cleanup()
    }
}
