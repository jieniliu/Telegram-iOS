// MomentsController.swift

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

final class MomentEntry: Comparable, Identifiable {
    let message: Message
    let id: MessageId

    init(message: Message) {
        self.message = message
        self.id = message.id
    }

    static func == (lhs: MomentEntry, rhs: MomentEntry) -> Bool {
        return lhs.id == rhs.id
    }

    static func < (lhs: MomentEntry, rhs: MomentEntry) -> Bool {
        return lhs.message.timestamp > rhs.message.timestamp
    }
}

public final class MomentsController: ViewController {
    private let context: AccountContext
    private var messagesDisposable: Disposable?
    private let listNode: ListView
    private var messages: [Message] = []
    private var entries: [MomentEntry] = []



    public init(context: AccountContext) {
        self.context = context
        self.listNode = ListView()

        super.init(navigationBarPresentationData: nil)

        self.title = "动态"
        self.tabBarItem.title = "动态"
        if let image = UIImage(named: "TabMoments") {
            self.tabBarItem.image = image
        } else {
            if #available(iOS 13.0, *) {
                self.tabBarItem.image = UIImage(systemName: "person.2.square.stack")
            } else {
                self.tabBarItem.image = nil
            }
        }

        self.listNode.backgroundColor = .white
        self.listNode.verticalScrollIndicatorColor = .black
        self.listNode.verticalScrollIndicatorFollowsOverscroll = true
    }

    @available(*, unavailable)
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        self.messagesDisposable?.dispose()
    }

    private func loadRecentMessages() {
        let location = SearchMessagesLocation.general(scope: .everywhere, tags: nil, minDate: nil, maxDate: nil)
        self.messagesDisposable = (self.context.engine.messages.searchMessages(
            location: location,
            query: "",
            state: nil,
            limit: 50
        )
        |> deliverOnMainQueue).start(next: { [weak self] result, _ in
            self?.displayMessages(result.messages)
        })
    }

    private func displayMessages(_ messages: [Message]) {
        self.messages = messages
        self.entries = messages.map { MomentEntry(message: $0) }.sorted()

        let items = self.entries.map { entry -> ListViewItem in
            return MomentListItem(context: self.context, message: entry.message)
        }

        self.listNode.transaction(
            deleteIndices: [],
            insertIndicesAndItems: Array(zip(0..<items.count, items)).map { ListViewInsertItem(index: $0.0, previousIndex: $0.0, item: $0.1, directionHint: nil) },
            updateIndicesAndItems: [],
            options: [.Synchronous, .LowLatency],
            scrollToItem: nil,
            updateSizeAndInsets: ListViewUpdateSizeAndInsets(
                size: self.listNode.bounds.size,
                insets: UIEdgeInsets(top: 20.0, left: 0, bottom: 0, right: 0),
                duration: 0,
                curve: .Default(duration: nil)
            ),
            stationaryItemRange: nil,
            updateOpaqueState: nil,
            completion: { _ in }
        )
    }

    public override func loadDisplayNode() {
        self.displayNode = ASDisplayNode()
        self.displayNode.backgroundColor = .white
        self.displayNode.addSubnode(self.listNode)
        self.loadRecentMessages()
        self.loadSmallGroupsMessages()
    }

    public override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        let listNodeFrame = CGRect(origin: .zero, size: layout.size)
        self.listNode.frame = listNodeFrame
        self.listNode.transaction(
            deleteIndices: [],
            insertIndicesAndItems: [],
            updateIndicesAndItems: [],
            options: [.Synchronous],
            scrollToItem: nil,
            updateSizeAndInsets: ListViewUpdateSizeAndInsets(
                size: layout.size,
                insets: UIEdgeInsets(top: layout.statusBarHeight ?? 20.0, left: 0, bottom: layout.intrinsicInsets.bottom, right: 0),
                duration: 0,
                curve: .Default(duration: nil)
            ),
            stationaryItemRange: nil,
            updateOpaqueState: nil,
            completion: { _ in }
        )
    }
}

final class MomentListItem: ListViewItem {
    let context: AccountContext
    let message: Message

    init(context: AccountContext, message: Message) {
        self.context = context
        self.message = message
    }

    // MARK: - Required properties

    var selectable: Bool {
        return false
    }

    var accessoryItem: ListViewAccessoryItem? {
        return nil
    }

    var headerAccessoryItem: ListViewAccessoryItem? {
        return nil
    }

    var approximateHeight: CGFloat {
        return 120.0
    }

    // MARK: - Required methods

    func itemId() -> AnyHashable {
        return self.message.id
    }

    func equals(_ other: ListViewItem) -> Bool {
        guard let other = other as? MomentListItem else { return false }
        return self.message.id == other.message.id &&
               self.message.stableVersion == other.message.stableVersion
    }

    func selected(listView: ListView) {
        // 不可选，不做任何处理
    }

    func nodeConfiguredForParams(
        async: @escaping (@escaping () -> Void) -> Void,
        params: ListViewItemLayoutParams,
        synchronousLoads: Bool,
        previousItem: ListViewItem?,
        nextItem: ListViewItem?,
        completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void
    ) {
        async {
            let node = MomentItemNode(context: self.context)
            node.setMessage(self.message)

            let layout = self.asyncLayout()
            let (nodeLayout, apply) = layout(self, params, previousItem, nextItem)

            node.contentSize = nodeLayout.contentSize
            node.insets = nodeLayout.insets

            completion(node, {
                return (nil, { _ in apply().1() })
            })
        }
    }

    func updateNode(
        async: @escaping (@escaping () -> Void) -> Void,
        node: @escaping () -> ListViewItemNode,
        params: ListViewItemLayoutParams,
        previousItem: ListViewItem?,
        nextItem: ListViewItem?,
        animation: ListViewItemUpdateAnimation,
        completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void
    ) {
        async {
            guard let node = node() as? MomentItemNode else { return }
            let layout = self.asyncLayout()
            let (nodeLayout, apply) = layout(self, params, previousItem, nextItem)

            Queue.mainQueue().async {
                node.contentSize = nodeLayout.contentSize
                node.insets = nodeLayout.insets
                completion(nodeLayout, { _ in apply().1() })
            }
        }
    }

    // MARK: - Layout helper

    fileprivate func asyncLayout() -> (
        _ item: ListViewItem,
        _ params: ListViewItemLayoutParams,
        _ previousItem: ListViewItem?,
        _ nextItem: ListViewItem?
    ) -> (ListViewItemNodeLayout, () -> (MomentItemNode, () -> Void)) {
        return { [weak self] _, params, _, _ in
            guard let strongSelf = self else {
                return (
                    ListViewItemNodeLayout(contentSize: .zero, insets: .zero),
                    { (MomentItemNode(context: MomentListItem.dummyContext), {}) }
                )
            }

            let width = params.width
            let height: CGFloat = 120

            let layout = ListViewItemNodeLayout(
                contentSize: CGSize(width: width, height: height),
                insets: UIEdgeInsets()
            )

            return (layout, {
                let node = MomentItemNode(context: strongSelf.context)
                node.setMessage(strongSelf.message)
                node.updateLayout(size: layout.contentSize, transition: .immediate)
                return (node, {})
            })
        }
    }

    private static let dummyContext: AccountContext = {
        fatalError("Attempted to use dummy context. Provide a valid AccountContext.")
    }()
}

private final class MomentItemNode: ListViewItemNode {
    private let context: AccountContext
    private let contentNode = ASDisplayNode()
    private let textNode = ASTextNode()
    private let authorNode = ASTextNode()
    private let dateNode = ASTextNode()
    
    var currentSize: CGSize?
    var currentTransition: ContainedViewLayoutTransition?
    
    init(context: AccountContext) {
        self.context = context
        super.init(layerBacked: false, dynamicBounce: false)
        self.addSubnode(contentNode)
        contentNode.addSubnode(authorNode)
        contentNode.addSubnode(textNode)
        contentNode.addSubnode(dateNode)
    }

    func setMessage(_ message: Message) {
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let authorName = message.author.flatMap { peer in
            if let user = peer as? TelegramUser {
                return EnginePeer(user).compactDisplayTitle
            }
            return presentationData.strings.User_DeletedAccount
        } ?? presentationData.strings.User_DeletedAccount
        
        authorNode.attributedText = NSAttributedString(string: authorName, attributes: [
            .font: UIFont.boldSystemFont(ofSize: 14),
            .foregroundColor: UIColor.blue
        ])
        
        textNode.attributedText = NSAttributedString(string: message.text, attributes: [
            .font: UIFont.systemFont(ofSize: 16),
            .foregroundColor: UIColor.black
        ])
        
        let date = Date(timeIntervalSince1970: Double(message.timestamp))
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        
        dateNode.attributedText = NSAttributedString(string: formatter.string(from: date), attributes: [
            .font: UIFont.systemFont(ofSize: 12),
            .foregroundColor: UIColor.gray
        ])
    }
    
    override func layout() {
        super.layout()
        let padding: CGFloat = 16
        let bounds = self.bounds
        
        contentNode.frame = bounds
        let maxWidth = bounds.width - padding * 2
        
        let authorSize = authorNode.measure(CGSize(width: maxWidth, height: .greatestFiniteMagnitude))
        authorNode.frame = CGRect(origin: CGPoint(x: padding, y: padding), size: authorSize)
        
        let textSize = textNode.measure(CGSize(width: maxWidth, height: .greatestFiniteMagnitude))
        textNode.frame = CGRect(origin: CGPoint(x: padding, y: authorNode.frame.maxY + 8), size: textSize)
        
        let dateSize = dateNode.measure(CGSize(width: maxWidth, height: .greatestFiniteMagnitude))
        dateNode.frame = CGRect(origin: CGPoint(x: padding, y: textNode.frame.maxY + 8), size: dateSize)
    }
    
    override func didLoad() {
        super.didLoad()
        if let size = self.currentSize, let transition = self.currentTransition {
            self.performLayout(size: size, transition: transition)
        }
    }
    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
        self.currentSize = size
        self.currentTransition = transition
        if self.isNodeLoaded {
            self.performLayout(size: size, transition: transition)
        }
    }
    
    private func performLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
        self.frame = CGRect(origin: .zero, size: size)
        self.contentNode.frame = self.bounds
        self.setNeedsLayout()
    }
}

// MARK: - MomentsController Extension
extension MomentsController {
    // 公共方法：加载小群组的最新消息
    public func loadSmallGroupsMessages() {
        self.loadSmallGroupsRecentMessages()
    }
    
    private func loadRecentMessages1() {
        let context = self.context
        
        // 获取最近的聊天记录
        let recentChatsSignal = context.engine.messages.chatList(group: .root, count: 50)
        
        let _ = (recentChatsSignal
        |> deliverOnMainQueue).start(next: { [weak self] chatList in
            guard let strongSelf = self else { return }
            
            // 处理聊天列表
            for item in chatList.items {
                if let message = item.messages.first {
                    let momentEntry = MomentEntry(
                        message: message._asMessage()

                    )
                    strongSelf.entries.append(momentEntry)
                }
            }
            
            // 按时间戳排序
            strongSelf.entries.sort { $0.message.timestamp > $1.message.timestamp }
            
            // 更新显示
//            strongSelf.updateUI()
        })
    }
    
    // 新增方法：获取人数少于50人的所有群的最新消息
    private func loadSmallGroupsRecentMessages() {
        let context = self.context
        
        // 获取聊天列表
        let chatListSignal = context.engine.messages.chatList(group: .root, count: 200)
        
        let _ = (chatListSignal
                 |> deliverOnMainQueue).start(next: { [weak self] chatList in
            guard let strongSelf = self else { return }
            
            var smallGroupIds: [EnginePeer.Id] = []
            
            // 筛选人数少于50人的群组
            for item in chatList.items {
                guard let peer = item.renderedPeer.peer else { continue }
                let peerId: PeerId = peer.id
                
                // 检查是否为群组
                switch peer {
                case let .legacyGroup(group):
                    // 普通群组，直接检查participantCount
                    if group.participantCount < 50 {
                        smallGroupIds.append(peerId)
                    }
                case let .channel(channel):
                    // 频道/超级群组，需要检查缓存数据中的成员数量
                    if case .group = channel.info {
                        // 这是一个超级群组，需要获取成员数量
                        strongSelf.checkChannelMemberCount(peerId: peerId) { memberCount in
                            if memberCount < 50 {
                                smallGroupIds.append(peerId)
                                strongSelf.loadMessagesForGroups(groupIds: [peerId])
                            }
                        }
                    }
                default:
                    break
                }
            }
            
            // 为普通群组加载消息
            if !smallGroupIds.isEmpty {
                strongSelf.loadMessagesForGroups(groupIds: smallGroupIds)
            }
        })
    }
    
    // 检查频道/超级群组的成员数量
    private func checkChannelMemberCount(peerId: EnginePeer.Id, completion: @escaping (Int) -> Void) {
        let context = self.context
        
        let peerViewSignal = context.account.viewTracker.peerView(peerId, updateData: false)
        
        let _ = (peerViewSignal
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
    }
    
    // 为指定群组加载最新消息
    private func loadMessagesForGroups(groupIds: [EnginePeer.Id]) {
        let context = self.context
        
        for groupId in groupIds {
            // 使用aroundMessageHistoryViewForLocation获取每个群组的最新5条消息
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
            
            let _ = (historySignal
                     |> deliverOnMainQueue).start(next: { [weak self] (messageHistoryView, _, _) in
                guard let strongSelf = self else { return }
                
                // 处理获取到的消息
                for entry in messageHistoryView.entries {
                    let momentEntry = MomentEntry(
                        message: entry.message
                    )
                    print("=================\(entry.message.text)")
                    // 添加到moments列表中
                    strongSelf.entries.append(momentEntry)
                }
                
                // 按时间戳排序
                strongSelf.entries.sort { $0.message.timestamp > $1.message.timestamp }
                
                // 更新UI
//                strongSelf.updateUI()
            })
        }
    }
}
