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

public final class AIAgentController: ViewController {
    private let context: AccountContext
    private var messagesDisposable: Disposable?
    private let listNode: ListView
    private var messages: [Message] = []
    private var entries: [MomentEntry] = []
    private var chatHistoryDisposable: Disposable?
    private var chatHistoryData: [AgentChatModel] = []



    public init(context: AccountContext) {
        self.context = context
        self.listNode = ListView()

        super.init(navigationBarPresentationData: nil)

        // 配置AgentChatHistoryManager - 需要在Postbox队列中执行
        let _ = (context.account.postbox.transaction { transaction -> Void in
            // 在Postbox队列中配置AgentChatHistoryManager
            AgentChatHistoryManager.shared.configure(with: context.account.postbox)
            print("AIAgentController: AgentChatHistoryManager 配置完成")
        }).start(next: { _ in
            // 配置完成后立即加载数据
            DispatchQueue.main.async {
                self.loadChatHistoryData()
            }
        })

        self.title = "AI助手"
        self.tabBarItem.title = "AI助手"
        if let image = UIImage(named: "TabAIAgent") {
            self.tabBarItem.image = image
        } else {
            if #available(iOS 13.0, *) {
                self.tabBarItem.image = UIImage(systemName: "brain.head.profile")
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
        self.chatHistoryDisposable?.dispose()
        self.cleanupSmallGroupsManager()
    }

    private func loadRecentMessages() {
        // 获取最近的聊天列表，然后从中提取消息
        let chatListSignal = self.context.engine.messages.chatList(group: .root, count: 20)
        
        self.messagesDisposable = (chatListSignal
        |> deliverOnMainQueue).start(next: { [weak self] chatList in
            guard let strongSelf = self else { return }
            
            var allMessages: [Message] = []
            
            print("AIAgent: 获取到 \(chatList.items.count) 个聊天项目")
            
            // 从每个聊天中获取最新的消息
            for item in chatList.items {
                if let engineMessage = item.messages.first {
                    print("Found message: \(engineMessage.text)")
                    let message = engineMessage._asMessage()
                    allMessages.append(message)
                }
            }
            
            print("AIAgent: 总共获取到 \(allMessages.count) 条消息")
            
            // 如果没有从聊天列表获取到消息，显示提示信息
            if allMessages.isEmpty {
                strongSelf.createSampleMessages()
            } else {
                strongSelf.displayMessages(allMessages)
            }
        })
    }
    
    private func createSampleMessages() {
        print("AIAgent: 没有找到消息，创建示例聊天数据")
        
        // 创建一些示例聊天数据用于测试
        let sampleChats = [
            AgentChatModel(
                id: "1",
                userMessage: "你好，请介绍一下你自己",
                aiResponse: "你好！我是AI助手，很高兴为您服务。我可以帮助您回答问题、提供信息和协助解决各种问题。",
                timestamp: Date(),
                messageCount: 1
            ),
            AgentChatModel(
                id: "2",
                userMessage: "今天天气怎么样？",
                aiResponse: "抱歉，我无法获取实时天气信息。建议您查看天气应用或网站获取准确的天气预报。",
                timestamp: Date(timeIntervalSinceNow: -3600),
                messageCount: 2
            ),
            AgentChatModel(
                id: "3",
                userMessage: "能帮我写一个简单的Python函数吗？",
                aiResponse: "当然可以！这里是一个简单的Python函数示例：\n\n```python\ndef greet(name):\n    return f'Hello, {name}!'\n\nprint(greet('World'))\n```\n\n这个函数接受一个名字参数并返回问候语。",
                timestamp: Date(timeIntervalSinceNow: -7200),
                messageCount: 3
            )
        ]
        
        // 更新聊天历史数据并显示
        self.chatHistoryData = sampleChats
        self.displayChatHistoryData()
        
        print("AIAgent: 已创建 \(sampleChats.count) 条示例聊天记录")
    }
    
    private func showEmptyStateMessage() {
        // 在界面上显示一个提示信息
        let alertController = UIAlertController(
            title: "AI助手",
            message: "正在加载消息，请稍候...",
            preferredStyle: .alert
        )
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            alertController.dismiss(animated: true, completion: nil)
        }
        
        self.present(alertController, animated: true, completion: nil)
    }

    private func displayMessages(_ messages: [Message]) {
        self.messages = messages
        self.entries = messages.map { MomentEntry(message: $0) }.sorted()
        self.updateListView()
    }
    
    private func updateListView() {
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
        self.displayNode.backgroundColor = UIColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1.0) // 浅灰色背景
        self.displayNode.addSubnode(self.listNode)
        
        // 设置列表节点的背景
        self.listNode.backgroundColor = UIColor.clear
        
        // 初始化列表状态 - ListView doesn't have updateOpaqueState method
        // The opaque state is managed through transaction calls
        
        print("AIAgentController: 显示节点加载完成")
        
        // 触发数据链条逻辑
        self.triggerDataChainLogic()
        
        // 监听聊天历史数据变化
        self.setupChatHistoryMonitoring()
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
    
    // MARK: - Data Chain Logic
    
    /// 触发数据链条逻辑：SmallGroupsMessageManager → AgentServiceManager → AgentNetworkCenter → AgentChatHistoryManager
    private func triggerDataChainLogic() {
        print("AIAgentController: 开始触发数据链条逻辑")
        
        // 配置SmallGroupsMessageManager
        SmallGroupsMessageManager.shared.configure(with: self.context)
        
        // 调用AgentServiceManager处理聊天总结请求
        AgentServiceManager.shared.processChatSummary { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let summary):
                    print("AIAgentController: 聊天总结成功: \(summary)")
                    // 数据已保存到AgentChatHistoryManager，会通过监听机制更新UI
                case .failure(let error):
                    print("AIAgentController: 聊天总结失败: \(error)")
                    
                    // 根据错误类型提供更友好的提示
                    var errorMessage = "获取聊天总结失败"
                    
                    if let networkError = error as? NetworkError {
                        switch networkError {
                        case .networkError(let underlyingError):
                            let nsError = underlyingError as NSError
                            if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorTimedOut {
                                errorMessage = "网络请求超时，请检查网络连接后重试"
                            } else if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorNotConnectedToInternet {
                                errorMessage = "网络连接不可用，请检查网络设置"
                            } else {
                                errorMessage = "网络连接异常: \(underlyingError.localizedDescription)"
                            }
                        case .serverError(let code):
                            errorMessage = "服务器错误(\(code))，请稍后重试"
                        case .invalidURL:
                            errorMessage = "请求地址无效"
                        case .noData:
                            errorMessage = "服务器未返回数据"
                        case .decodingError:
                            errorMessage = "数据解析失败"
                        }
                    } else {
                        errorMessage = "获取聊天总结失败: \(error.localizedDescription)"
                    }
                    
                    self?.showErrorAlert(message: errorMessage)
                }
            }
        }
    }
    
    /// 设置聊天历史数据监听
    private func setupChatHistoryMonitoring() {
        print("AIAgentController: 设置聊天历史数据监听")
        
        // 定期检查聊天历史数据变化
        let timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.loadChatHistoryData()
        }
        
        // 将timer转换为Disposable以便管理
        self.chatHistoryDisposable = ActionDisposable {
            timer.invalidate()
        }
        
        // 注意：不在这里立即加载数据，因为已经在配置完成后加载了
    }
    
    /// 加载聊天历史数据
    private func loadChatHistoryData() {
        AgentServiceManager.shared.getChatHistory(page: 0, pageSize: 50) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let chatHistory):
                    print("AIAgentController: 成功获取聊天历史，共 \(chatHistory.count) 条记录")
                    if chatHistory.isEmpty {
                        print("AIAgentController: 数据库为空，创建示例数据")
                        self?.createSampleMessages()
                    } else {
                        self?.updateChatHistoryData(chatHistory)
                    }
                case .failure(let error):
                    print("AIAgentController: 获取聊天历史失败: \(error)")
                    // 如果获取失败，也尝试显示示例数据
                    print("AIAgentController: 由于获取失败，显示示例数据")
                    self?.createSampleMessages()
                }
            }
        }
    }
    
    /// 更新聊天历史数据并刷新UI
    private func updateChatHistoryData(_ newData: [AgentChatModel]) {
        print("AIAgentController: 收到聊天历史数据，共 \(newData.count) 条记录")
        
        // 打印每条记录的详细信息
        for (index, chat) in newData.enumerated() {
            print("  记录 \(index + 1): ID=\(chat.id), 用户消息=\(chat.userMessage.prefix(50))..., AI回复=\(chat.aiResponse.prefix(50))...")
        }
        
        // 检查数据是否有变化
        if self.chatHistoryData.count != newData.count {
            print("AIAgentController: 聊天历史数据发生变化，从 \(self.chatHistoryData.count) 条更新为 \(newData.count) 条")
            self.chatHistoryData = newData
            self.displayChatHistoryData()
        } else {
            print("AIAgentController: 聊天历史数据数量未变化，保持 \(newData.count) 条记录")
            // 即使数量相同，也更新数据以防内容有变化
            self.chatHistoryData = newData
            self.displayChatHistoryData()
        }
    }
    
    /// 显示聊天历史数据
    private func displayChatHistoryData() {
        print("AIAgentController: 开始显示聊天历史数据，共 \(self.chatHistoryData.count) 条记录")
        
        // 将聊天历史数据转换为显示项目
        let items = self.chatHistoryData.map { chatModel -> ListViewItem in
            print("  创建列表项: \(chatModel.id)")
            return ChatHistoryListItem(chatModel: chatModel)
        }
        
        print("AIAgentController: 创建了 \(items.count) 个列表项，开始更新列表视图")
        
        // 获取当前列表中的项目数量
        let currentItemCount = self.listNode.opaqueTransactionState as? Int ?? 0
        
        // 创建删除索引（删除所有现有项目）
        let deleteIndices = Array(0..<currentItemCount).map { ListViewDeleteItem(index: $0, directionHint: nil) }
        
        // 创建插入项目
        let insertItems = Array(zip(0..<items.count, items)).map { 
            ListViewInsertItem(index: $0.0, previousIndex: nil, item: $0.1, directionHint: nil) 
        }
        
        // 更新列表视图
        self.listNode.transaction(
            deleteIndices: deleteIndices,
            insertIndicesAndItems: insertItems,
            updateIndicesAndItems: [],
            options: [.Synchronous, .LowLatency],
            scrollToItem: nil,
            updateSizeAndInsets: ListViewUpdateSizeAndInsets(
                size: self.listNode.bounds.size,
                insets: UIEdgeInsets(top: 20.0, left: 0, bottom: 20.0, right: 0),
                duration: 0,
                curve: .Default(duration: nil)
            ),
            stationaryItemRange: nil,
            updateOpaqueState: items.count,
            completion: { _ in 
                print("AIAgentController: 列表视图更新完成，当前显示 \(items.count) 个项目")
            }
        )
    }
    
    /// 显示错误提示
    private func showErrorAlert(message: String) {
        let alertController = UIAlertController(
            title: "错误",
            message: message,
            preferredStyle: .alert
        )
        
        alertController.addAction(UIAlertAction(title: "确定", style: .default, handler: nil))
        self.present(alertController, animated: true, completion: nil)
    }
}

/// 聊天历史列表项
final class ChatHistoryListItem: ListViewItem {
    let chatModel: AgentChatModel
    
    init(chatModel: AgentChatModel) {
        self.chatModel = chatModel
    }
    
    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = ChatHistoryListItemNode()
            let (layout, apply) = node.asyncLayout()(self, params, false)
            
            node.contentSize = layout.contentSize
            node.insets = layout.insets
            
            completion(node, {
                return (nil, { _ in apply() })
            })
        }
    }
    
    func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            if let nodeValue = node() as? ChatHistoryListItemNode {
                let (layout, apply) = nodeValue.asyncLayout()(self, params, false)
                completion(layout, { _ in
                    apply()
                })
            }
        }
    }
}

/// 聊天历史列表项节点
final class ChatHistoryListItemNode: ListViewItemNode {
    private let titleNode: ASTextNode
    private let contentNode: ASTextNode
    private let timeNode: ASTextNode
    private let separatorNode: ASDisplayNode
    
    init() {
        self.titleNode = ASTextNode()
        self.titleNode.isLayerBacked = true
        self.contentNode = ASTextNode()
        self.contentNode.isLayerBacked = true
        self.timeNode = ASTextNode()
        self.timeNode.isLayerBacked = true
        self.separatorNode = ASDisplayNode()
        self.separatorNode.isLayerBacked = true
        
        super.init(layerBacked: true)
        
        self.addSubnode(self.titleNode)
        self.addSubnode(self.contentNode)
        self.addSubnode(self.timeNode)
        self.addSubnode(self.separatorNode)
        
        self.separatorNode.backgroundColor = UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1.0)
    }
    
    func asyncLayout() -> (_ item: ChatHistoryListItem, _ params: ListViewItemLayoutParams, _ first: Bool) -> (ListViewItemNodeLayout, () -> Void) {
        let titleLayout = TextNode.asyncLayout(self.titleNode)
        let contentLayout = TextNode.asyncLayout(self.contentNode)
        let timeLayout = TextNode.asyncLayout(self.timeNode)
        
        return { item, params, first in
            let leftInset: CGFloat = 16.0
            let rightInset: CGFloat = 16.0
            let topInset: CGFloat = 12.0
            let bottomInset: CGFloat = 12.0
            let spacing: CGFloat = 8.0
            
            let contentWidth = params.width - leftInset - rightInset
            
            // 标题
            let titleText = NSAttributedString(
                string: "聊天总结 (\(item.chatModel.messageCount) 条消息)",
                attributes: [
                    .font: UIFont.boldSystemFont(ofSize: 16.0),
                    .foregroundColor: UIColor.black
                ]
            )
            let (titleSize, titleApply) = titleLayout(TextNodeLayoutArguments(
                attributedString: titleText,
                backgroundColor: nil,
                maximumNumberOfLines: 1,
                truncationType: .end,
                constrainedSize: CGSize(width: contentWidth, height: CGFloat.greatestFiniteMagnitude),
                alignment: .natural,
                cutout: nil,
                insets: UIEdgeInsets()
            ))
            
            // 内容预览
            let previewText = String(item.chatModel.aiResponse.prefix(100)) + (item.chatModel.aiResponse.count > 100 ? "..." : "")
            let contentText = NSAttributedString(
                string: previewText,
                attributes: [
                    .font: UIFont.systemFont(ofSize: 14.0),
                    .foregroundColor: UIColor.darkGray
                ]
            )
            let (contentSize, contentApply) = contentLayout(TextNodeLayoutArguments(
                attributedString: contentText,
                backgroundColor: nil,
                maximumNumberOfLines: 3,
                truncationType: .end,
                constrainedSize: CGSize(width: contentWidth, height: CGFloat.greatestFiniteMagnitude),
                alignment: .natural,
                cutout: nil,
                insets: UIEdgeInsets()
            ))
            
            // 时间
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            let timeText = NSAttributedString(
                string: formatter.string(from: item.chatModel.timestamp),
                attributes: [
                    .font: UIFont.systemFont(ofSize: 12.0),
                    .foregroundColor: UIColor.lightGray
                ]
            )
            let (timeSize, timeApply) = timeLayout(TextNodeLayoutArguments(
                attributedString: timeText,
                backgroundColor: nil,
                maximumNumberOfLines: 1,
                truncationType: .end,
                constrainedSize: CGSize(width: contentWidth, height: CGFloat.greatestFiniteMagnitude),
                alignment: .natural,
                cutout: nil,
                insets: UIEdgeInsets()
            ))
            
            let totalHeight = topInset + titleSize.size.height + spacing + contentSize.size.height + spacing + timeSize.size.height + bottomInset
            
            let layout = ListViewItemNodeLayout(
                contentSize: CGSize(width: params.width, height: totalHeight),
                insets: UIEdgeInsets()
            )
            
            return (layout, {
                let _ = titleApply()
                let _ = contentApply()
                let _ = timeApply()
                
                self.titleNode.frame = CGRect(
                    origin: CGPoint(x: leftInset, y: topInset),
                    size: titleSize.size
                )
                
                self.contentNode.frame = CGRect(
                    origin: CGPoint(x: leftInset, y: topInset + titleSize.size.height + spacing),
                    size: contentSize.size
                )
                
                self.timeNode.frame = CGRect(
                    origin: CGPoint(x: leftInset, y: topInset + titleSize.size.height + spacing + contentSize.size.height + spacing),
                    size: timeSize.size
                )
                
                self.separatorNode.frame = CGRect(
                    origin: CGPoint(x: 0, y: totalHeight - 1.0),
                    size: CGSize(width: params.width, height: 1.0)
                )
            })
        }
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
        
        // 设置内容节点样式
        contentNode.backgroundColor = UIColor.white
        contentNode.cornerRadius = 8.0
        contentNode.borderWidth = 1.0
        contentNode.borderColor = UIColor.lightGray.cgColor
        
        self.addSubnode(contentNode)
        contentNode.addSubnode(authorNode)
        contentNode.addSubnode(textNode)
        contentNode.addSubnode(dateNode)
        
        print("MomentItemNode: 初始化完成")
    }

    func setMessage(_ message: Message) {
        print("MomentItemNode: 设置消息 - \(message.text)")
        
        // 设置作者名称
        let authorName: String
        if let author = message.author {
            if let user = author as? TelegramUser {
                authorName = user.firstName ?? "Unknown User"
            } else {
                authorName = "Chat"
            }
        } else {
            authorName = "Unknown"
        }
        
        authorNode.attributedText = NSAttributedString(string: authorName, attributes: [
            .font: UIFont.boldSystemFont(ofSize: 14),
            .foregroundColor: UIColor.blue
        ])
        
        // 设置消息文本
        let messageText = message.text.isEmpty ? "[Media Message]" : message.text
        textNode.attributedText = NSAttributedString(string: messageText, attributes: [
            .font: UIFont.systemFont(ofSize: 16),
            .foregroundColor: UIColor.black
        ])
        
        // 设置时间
        let date = Date(timeIntervalSince1970: Double(message.timestamp))
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        
        dateNode.attributedText = NSAttributedString(string: formatter.string(from: date), attributes: [
            .font: UIFont.systemFont(ofSize: 12),
            .foregroundColor: UIColor.gray
        ])
        
        print("MomentItemNode: 消息设置完成 - 作者: \(authorName), 文本: \(messageText)")
        
        // 强制重新布局
        self.setNeedsLayout()
    }
    
    override func layout() {
        super.layout()
        let padding: CGFloat = 16
        let margin: CGFloat = 8
        let bounds = self.bounds
        
        // 给contentNode留出边距
        contentNode.frame = CGRect(
            x: margin,
            y: margin,
            width: bounds.width - margin * 2,
            height: bounds.height - margin * 2
        )
        
        let maxWidth = contentNode.bounds.width - padding * 2
        
        let authorSize = authorNode.measure(CGSize(width: maxWidth, height: .greatestFiniteMagnitude))
        authorNode.frame = CGRect(origin: CGPoint(x: padding, y: padding), size: authorSize)
        
        let textSize = textNode.measure(CGSize(width: maxWidth, height: .greatestFiniteMagnitude))
        textNode.frame = CGRect(origin: CGPoint(x: padding, y: authorNode.frame.maxY + 8), size: textSize)
        
        let dateSize = dateNode.measure(CGSize(width: maxWidth, height: .greatestFiniteMagnitude))
        dateNode.frame = CGRect(origin: CGPoint(x: padding, y: textNode.frame.maxY + 8), size: dateSize)
        
        print("MomentItemNode: 布局完成 - contentNode: \(contentNode.frame)")
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

// MARK: - AIAgentController Extension
extension AIAgentController {
    /// 配置小群组消息管理器
    private func configureSmallGroupsManager() {
        SmallGroupsMessageManager.shared.configure(with: self.context)
    }
    
    /// 公共方法：加载小群组的最新消息
    public func loadSmallGroupsMessages() {
        self.configureSmallGroupsManager()
        
        SmallGroupsMessageManager.shared.loadUnreadMessages { [weak self] momentEntries in
            guard let strongSelf = self else { return }
            
            // 将获取到的消息添加到当前的entries中
            strongSelf.entries.append(contentsOf: momentEntries)
            
            // 重新排序所有条目
            strongSelf.entries.sort { $0.message.timestamp > $1.message.timestamp }
            
            // 更新UI
            strongSelf.updateListView()
            print("成功加载了 \(momentEntries.count) 条小群组消息")
        }
    }
    
    /// 获取少于50人群组的未读消息
    public func getUnreadMessagesForSmallGroups() {
        self.configureSmallGroupsManager()
        
        SmallGroupsMessageManager.shared.getUnreadMessagesForSmallGroups { [weak self] unreadEntries in
            guard let strongSelf = self else { return }
            
            // 将获取到的未读消息添加到当前的entries中
            strongSelf.entries.append(contentsOf: unreadEntries)
            
            // 重新排序所有条目
            strongSelf.entries.sort { $0.message.timestamp > $1.message.timestamp }
            
            // 更新UI显示
            strongSelf.updateListView()
            
            print("成功获取了 \(unreadEntries.count) 条小群组未读消息")
        }
    }
    
    /// 清理小群组消息管理器资源
    public func cleanupSmallGroupsManager() {
        SmallGroupsMessageManager.shared.cleanup()
    }
}
