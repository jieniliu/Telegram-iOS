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
    private var agentChatViewDisposable: Disposable?
    private var isCreatingSampleData: Bool = false


    public init(context: AccountContext) {
        self.context = context
        self.listNode = ListView()
        
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        super.init(navigationBarPresentationData: NavigationBarPresentationData(presentationData: presentationData))

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

        self.listNode.backgroundColor = .gray
        self.listNode.verticalScrollIndicatorColor = .black
        self.listNode.verticalScrollIndicatorFollowsOverscroll = true
    }

    @available(*, unavailable)
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        self.messagesDisposable?.dispose()
        self.agentChatViewDisposable?.dispose()
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
        
        print("AIAgent: 开始保存 \(sampleChats.count) 条示例数据到数据库")
        
        // 保存示例数据到数据库
        let group = DispatchGroup()
        var savedCount = 0
        
        for chat in sampleChats {
            group.enter()
            AgentServiceManager.shared.historyManager.addChatRecord(chat) { result in
                defer { group.leave() }
                switch result {
                case .success():
                    savedCount += 1
                    print("AIAgent: 成功保存示例数据 \(chat.id)")
                case .failure(let error):
                    print("AIAgent: 保存示例数据 \(chat.id) 失败: \(error)")
                }
            }
        }
        
        // 等待所有保存操作完成后再加载数据
        group.notify(queue: .main) {
            print("AIAgent: 示例数据保存完成，成功保存 \(savedCount)/\(sampleChats.count) 条记录")
            
            // 重置创建标志
            self.isCreatingSampleData = false
            
            // 延迟一下再重新加载数据，确保数据库操作完成
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                print("AIAgent: 重新加载聊天历史数据")
                self.loadChatHistoryData()
            }
        }
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
        // super.loadDisplayNode()
        // 不要再赋值
        self.displayNode = ASDisplayNode()
        self.displayNode.backgroundColor = UIColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1.0)
        
        // 设置列表节点的背景为更明显的颜色用于调试
        self.listNode.backgroundColor = UIColor.red
        self.listNode.view.clipsToBounds = true
        
        // 添加listNode到displayNode
        self.displayNode.addSubnode(self.listNode)
        
        // 确保listNode有初始frame
        self.listNode.frame = self.displayNode.bounds
        
        
        // 强制设置displayNode的一些属性
        self.displayNode.isOpaque = false
        self.displayNode.alpha = 1.0
        self.displayNode.isHidden = false
        self.displayNode.clipsToBounds = false
        
        print("AIAgentController: loadDisplayNode - 显示节点已加载")
        print("AIAgentController: loadDisplayNode - displayNode frame: \(self.displayNode.frame)")
        print("AIAgentController: loadDisplayNode - displayNode backgroundColor: \(self.displayNode.backgroundColor?.description ?? "nil")")
        print("AIAgentController: loadDisplayNode - displayNode alpha: \(self.displayNode.alpha)")
        print("AIAgentController: loadDisplayNode - displayNode isHidden: \(self.displayNode.isHidden)")
        print("AIAgentController: loadDisplayNode - listNode初始frame: \(self.listNode.frame)")
        
    }
    
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        print("AIAgentController: viewDidLoad - 设置初始布局")
        self.view.frame = CGRectMake(0, 0, 393, 852)
        print("AIAgentController: viewDidLoad - 初始view frame: \(self.view.frame)")
        print("AIAgentController: viewDidLoad - view backgroundColor: \(self.view.backgroundColor?.description ?? "nil")")
        print("AIAgentController: viewDidLoad - view alpha: \(self.view.alpha)")
        print("AIAgentController: viewDidLoad - view isHidden: \(self.view.isHidden)")
        print("AIAgentController: viewDidLoad - displayNode frame: \(self.displayNode.frame)")
        
        // 强制设置view的frame，确保有正确的尺寸
        if self.view.frame.size.width == 0 || self.view.frame.size.height == 0 {
            let screenSize = UIScreen.main.bounds.size
            self.view.frame = CGRect(origin: .zero, size: screenSize)
            print("AIAgentController: viewDidLoad - 强制设置view frame为屏幕尺寸: \(screenSize)")
        }
        
        // 不要再 addSubview 或 addSubnode displayNode
        // 只需要配置 displayNode 即可
        
        // 设置displayNode的frame为整个视图的bounds
        self.displayNode.frame = self.view.bounds
        print("AIAgentController: displayNode frame设置为: \(self.displayNode.frame)")
        
        // 检查视图层次结构
        print("AIAgentController: view.subviews count: \(self.view.subviews.count)")
        print("AIAgentController: view.layer.sublayers count: \(self.view.layer.sublayers?.count ?? 0)")
        print("AIAgentController: displayNode.subnodes count: \(self.displayNode.subnodes?.count ?? 0)")
        
        // 强制设置view的背景色为白色，确保可见
        self.view.backgroundColor = UIColor.white
        

        // 触发数据链条逻辑
        self.triggerDataChainLogic()
        
        // 监听聊天历史数据变化
        self.setupChatHistoryMonitoring()
        
        // 加载聊天历史数据
        self.loadChatHistoryData()
        
        print("AIAgentController: viewDidLoad - 最终view frame: \(self.view.frame)")
        print("AIAgentController: viewDidLoad - 最终displayNode frame: \(self.displayNode.frame)")
    }
    
    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        print("AIAgentController: viewDidAppear - 视图已显示")
        print("AIAgentController: view frame: \(self.view.frame)")
        print("AIAgentController: view bounds: \(self.view.bounds)")
        print("AIAgentController: displayNode frame: \(self.displayNode.frame)")
        print("AIAgentController: listNode frame: \(self.listNode.frame)")
        print("AIAgentController: displayNode subnodes count: \(self.displayNode.subnodes?.count ?? 0)")
        
        // 确保displayNode的frame正确设置为view的bounds
        if !self.view.bounds.equalTo(self.displayNode.frame) {
            self.displayNode.frame = self.view.bounds
            print("AIAgentController: viewDidAppear - 重新设置displayNode frame为: \(self.displayNode.frame)")
        }
        
        // 如果view的bounds仍然是零，强制设置一个默认尺寸
        if self.view.bounds.size.width == 0 || self.view.bounds.size.height == 0 {
            let defaultSize = CGSize(width: 375, height: 667)
            self.view.frame = CGRect(origin: .zero, size: defaultSize)
            self.displayNode.frame = CGRect(origin: .zero, size: defaultSize)
            print("AIAgentController: viewDidAppear - 强制设置默认尺寸: \(defaultSize)")
            
            // 手动触发布局更新
            let layout = ContainerViewLayout(
                size: defaultSize,
                metrics: LayoutMetrics(widthClass: .compact, heightClass: .regular, orientation: .portrait),
                deviceMetrics: DeviceMetrics.iPhoneX,
                intrinsicInsets: UIEdgeInsets.zero,
                safeInsets: UIEdgeInsets(top: 44, left: 0, bottom: 34, right: 0),
                additionalInsets: UIEdgeInsets.zero,
                statusBarHeight: 44,
                inputHeight: nil,
                inputHeightIsInteractivellyChanging: false,
                inVoiceOver: false
            )
            self.containerLayoutUpdated(layout, transition: .immediate)
        }

    }

    public override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        print("AIAgentController: containerLayoutUpdated - 布局尺寸: \(layout.size)")
        print("AIAgentController: containerLayoutUpdated - 设置前listNode frame: \(self.listNode.frame)")
        print("AIAgentController: containerLayoutUpdated - 设置前displayNode frame: \(self.displayNode.frame)")
        
        // 确保displayNode的frame正确设置
        let displayFrame = CGRect(origin: .zero, size: layout.size)
        transition.updateFrame(node: self.displayNode, frame: displayFrame)
        print("AIAgentController: containerLayoutUpdated - displayNode frame更新为: \(displayFrame)")
        
        // 确保displayNode的可见性属性
        self.displayNode.isOpaque = false
        self.displayNode.alpha = 1.0
        self.displayNode.isHidden = false
        self.displayNode.clipsToBounds = false
        
        print("AIAgentController: displayNode属性 - isOpaque: \(self.displayNode.isOpaque), alpha: \(self.displayNode.alpha), isHidden: \(self.displayNode.isHidden)")
        
        // 设置listNode的frame等于layout.size
        let listFrame = CGRect(origin: .zero, size: layout.size)
        transition.updateFrame(node: self.listNode, frame: listFrame)
        
        // 更新绿色测试方块位置到屏幕正中间
        if let testSquare = self.displayNode.subnodes?.last {
            let centerX = layout.size.width / 2 - 50
            let centerY = layout.size.height / 2 - 50
            transition.updateFrame(node: testSquare, frame: CGRect(x: centerX, y: centerY, width: 100, height: 100))
            print("AIAgentController: 绿色方块位置更新到: (\(centerX), \(centerY))")
        }
        
        print("AIAgentController: containerLayoutUpdated - 设置后listNode frame: \(self.listNode.frame)")
        
        // 计算正确的insets
        let topInset = layout.statusBarHeight ?? 20.0
        let bottomInset = layout.intrinsicInsets.bottom
        
        // 强制刷新显示 - 多层级刷新
        self.displayNode.setNeedsDisplay()
        self.displayNode.setNeedsLayout()
        self.listNode.setNeedsDisplay()
        self.listNode.setNeedsLayout()
        
        // 强制刷新所有子节点
        if let subnodes = self.displayNode.subnodes {
            for subnode in subnodes {
                subnode.setNeedsDisplay()
                subnode.setNeedsLayout()
            }
        }
        
        self.view.setNeedsDisplay()
        self.view.setNeedsLayout()
        self.view.layoutIfNeeded()
        
        // 异步再次刷新，确保渲染完成
        DispatchQueue.main.async {
            self.displayNode.recursivelyEnsureDisplaySynchronously(true)
            self.listNode.recursivelyEnsureDisplaySynchronously(true)
        }
        
        print("AIAgentController: 强制刷新显示完成 - 多层级刷新")
        
        self.listNode.transaction(
            deleteIndices: [],
            insertIndicesAndItems: [],
            updateIndicesAndItems: [],
            options: [.Synchronous],
            scrollToItem: nil,
            updateSizeAndInsets: ListViewUpdateSizeAndInsets(
                size: layout.size,
                insets: UIEdgeInsets(top: topInset, left: 0, bottom: bottomInset, right: 0),
                duration: 0,
                curve: .Default(duration: nil)
            ),
            stationaryItemRange: nil,
            updateOpaqueState: nil,
            completion: { _ in 
                print("AIAgentController: 布局更新完成，重新显示数据")
                print("AIAgentController: 最终listNode frame: \(self.listNode.frame), bounds: \(self.listNode.bounds)")
                // 布局完成后重新显示数据
                if !self.chatHistoryData.isEmpty {
                    self.displayChatHistoryData()
                } else {
                    // 如果没有数据，强制加载一次
                    self.loadChatHistoryData()
                }
            }
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
    
    /// 设置聊天历史数据监听 - 使用响应式AgentChatView
    private func setupChatHistoryMonitoring() {
        print("AIAgentController: 设置响应式聊天历史数据监听")
        
        // 直接使用AgentServiceManager监听数据变化
        // 注意：AgentChatViewPlaceholder只是占位符，实际数据需要通过AgentServiceManager获取
        self.loadChatHistoryData()
        
        // 保持原有的定时器作为备用机制
        let timer = Timer.scheduledTimer(withTimeInterval: 1000.0, repeats: true) { [weak self] _ in
            // 每10秒检查一次，作为备用机制
            self?.loadChatHistoryData()
        }
        
        self.chatHistoryDisposable = ActionDisposable {
            timer.invalidate()
        }
    }
    
    /// 加载聊天历史数据
    private func loadChatHistoryData() {
        AgentServiceManager.shared.getChatHistory(page: 0, pageSize: 50) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let chatHistory):
                    print("AIAgentController: 成功获取聊天历史，共 \(chatHistory.count) 条记录")
                    if chatHistory.isEmpty {
                        // 检查是否已经在创建示例数据，避免重复创建
                        if self?.isCreatingSampleData != true {
                            print("AIAgentController: 数据库为空，创建示例数据")
                            self?.isCreatingSampleData = true
                            self?.createSampleMessages()
                        } else {
                            print("AIAgentController: 正在创建示例数据，跳过重复创建")
                        }
                    } else {
                        self?.isCreatingSampleData = false
                        self?.updateChatHistoryData(chatHistory)
                    }
                case .failure(let error):
                    print("AIAgentController: 获取聊天历史失败: \(error)")
                    // 如果获取失败，也尝试显示示例数据
                    if self?.isCreatingSampleData != true {
                        print("AIAgentController: 由于获取失败，显示示例数据")
                        self?.isCreatingSampleData = true
                        self?.createSampleMessages()
                    } else {
                        print("AIAgentController: 正在创建示例数据，跳过重复创建")
                    }
                }
            }
        }
    }
    
    /// 更新聊天历史数据并刷新UI
    private func updateChatHistoryData(_ newData: [AgentChatModel]) {
        print("AIAgentController: 收到聊天历史数据，共 \(newData.count) 条记录")
        
        // 打印每条记录的详细信息
        for (index, chat) in newData.enumerated() {
            if index < 10 {
                print("  记录 \(index + 1): ID=\(chat.id), 用户消息=\(chat.userMessage.prefix(50))..., AI回复=\(chat.aiResponse.prefix(50))...")
            }
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
        
        // 确保listNode有有效的尺寸
        var listSize = self.listNode.bounds.size
        if listSize == .zero {
            // 如果listNode尺寸为零，尝试使用displayNode的尺寸
            listSize = self.displayNode.bounds.size
            if listSize == .zero {
                // 再尝试使用view的尺寸
                listSize = self.view.bounds.size
                if listSize == .zero {
                    // 最后的备用尺寸
                    listSize = CGSize(width: 375, height: 667)
                }
            }
            // 强制更新listNode的frame
            self.listNode.frame = CGRect(origin: .zero, size: listSize)
            print("AIAgentController: 强制设置listNode frame为: \(self.listNode.frame)")
        }
        
        print("AIAgentController: 使用列表尺寸: \(listSize)")
        print("AIAgentController: 当前listNode frame: \(self.listNode.frame)")
        
        // 更新列表视图
        self.listNode.transaction(
            deleteIndices: deleteIndices,
            insertIndicesAndItems: insertItems,
            updateIndicesAndItems: [],
            options: [.Synchronous, .LowLatency],
            scrollToItem: nil,
            updateSizeAndInsets: ListViewUpdateSizeAndInsets(
                size: listSize,
                insets: UIEdgeInsets(top: 20.0, left: 0, bottom: 20.0, right: 0),
                duration: 0,
                curve: .Default(duration: nil)
            ),
            stationaryItemRange: nil,
            updateOpaqueState: items.count,
            completion: { _ in 
                print("AIAgentController: 列表视图更新完成，当前显示 \(items.count) 个项目")
                print("AIAgentController: view frame: \(self.view.frame), bounds: \(self.view.bounds)")
                print("AIAgentController: displayNode frame: \(self.displayNode.frame), bounds: \(self.displayNode.bounds)")
                print("AIAgentController: listNode frame: \(self.listNode.frame), bounds: \(self.listNode.bounds)")
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
            
            // 内容预览
            let previewText = String(item.chatModel.aiResponse.prefix(100)) + (item.chatModel.aiResponse.count > 100 ? "..." : "")
            let contentText = NSAttributedString(
                string: previewText,
                attributes: [
                    .font: UIFont.systemFont(ofSize: 14.0),
                    .foregroundColor: UIColor.darkGray
                ]
            )
            
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
            
            // 计算文本尺寸
            let titleSize = titleText.boundingRect(
                with: CGSize(width: contentWidth, height: CGFloat.greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                context: nil
            ).size
            
            let contentSize = contentText.boundingRect(
                with: CGSize(width: contentWidth, height: CGFloat.greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                context: nil
            ).size
            
            let timeSize = timeText.boundingRect(
                with: CGSize(width: contentWidth, height: CGFloat.greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                context: nil
            ).size
            
            let totalHeight = topInset + titleSize.height + spacing + contentSize.height + spacing + timeSize.height + bottomInset
            
            let layout = ListViewItemNodeLayout(
                contentSize: CGSize(width: params.width, height: totalHeight),
                insets: UIEdgeInsets()
            )
            
            return (layout, {
                // 设置文本内容
                self.titleNode.attributedText = titleText
                self.contentNode.attributedText = contentText
                self.timeNode.attributedText = timeText
                
                // 设置节点背景色用于调试
                self.backgroundColor = UIColor.yellow
                self.titleNode.backgroundColor = UIColor.cyan
                self.contentNode.backgroundColor = UIColor.lightGray
                self.timeNode.backgroundColor = UIColor.orange
                
                // 设置节点位置和大小
                self.titleNode.frame = CGRect(
                    origin: CGPoint(x: leftInset, y: topInset),
                    size: titleSize
                )
                
                self.contentNode.frame = CGRect(
                    origin: CGPoint(x: leftInset, y: topInset + titleSize.height + spacing),
                    size: contentSize
                )
                
                self.timeNode.frame = CGRect(
                    origin: CGPoint(x: leftInset, y: topInset + titleSize.height + spacing + contentSize.height + spacing),
                    size: timeSize
                )
                
                self.separatorNode.frame = CGRect(
                    origin: CGPoint(x: 0, y: totalHeight - 1.0),
                    size: CGSize(width: params.width, height: 1.0)
                )
                
                print("ChatHistoryListItemNode: 应用布局 - 总高度: \(totalHeight), 宽度: \(params.width)")
                print("ChatHistoryListItemNode: 标题: \(titleText.string)")
                print("ChatHistoryListItemNode: 内容: \(contentText.string)")
                print("ChatHistoryListItemNode: 时间: \(timeText.string)")
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
    private let bubbleBackgroundNode = ASImageNode()
    private let textNode = ASTextNode()
    private let authorNode = ASTextNode()
    private let dateNode = ASTextNode()
    private var message: Message?
    
    var currentSize: CGSize?
    var currentTransition: ContainedViewLayoutTransition?
    
    init(context: AccountContext) {
        self.context = context
        super.init(layerBacked: false, dynamicBounce: false)
        
        // 设置气泡背景
        bubbleBackgroundNode.displaysAsynchronously = false
        bubbleBackgroundNode.displayWithoutProcessing = true
        
        self.addSubnode(bubbleBackgroundNode)
        bubbleBackgroundNode.addSubnode(authorNode)
        bubbleBackgroundNode.addSubnode(textNode)
        bubbleBackgroundNode.addSubnode(dateNode)
        
        print("MomentItemNode: 初始化完成")
    }

    func setMessage(_ message: Message) {
        self.message = message
        print("MomentItemNode: 设置消息 - \(message.text)")
        
        // 判断是否为发出的消息（简单判断：如果作者是当前用户则为发出消息）
        let isOutgoing = message.flags.contains(.Incoming) == false
        
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
        
        // 根据消息方向设置文本颜色
        let textColor = isOutgoing ? UIColor.white : UIColor.black
        let authorColor = isOutgoing ? UIColor.white.withAlphaComponent(0.8) : UIColor.blue
        let dateColor = isOutgoing ? UIColor.white.withAlphaComponent(0.7) : UIColor.gray
        
        authorNode.attributedText = NSAttributedString(string: authorName, attributes: [
            .font: UIFont.boldSystemFont(ofSize: 14),
            .foregroundColor: authorColor
        ])
        
        // 设置消息文本
        let messageText = message.text.isEmpty ? "[Media Message]" : message.text
        textNode.attributedText = NSAttributedString(string: messageText, attributes: [
            .font: UIFont.systemFont(ofSize: 16),
            .foregroundColor: textColor
        ])
        
        // 设置时间
        let date = Date(timeIntervalSince1970: Double(message.timestamp))
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        
        dateNode.attributedText = NSAttributedString(string: formatter.string(from: date), attributes: [
            .font: UIFont.systemFont(ofSize: 12),
            .foregroundColor: dateColor
        ])
        
        // 生成气泡背景图片
        self.updateBubbleBackground(isOutgoing: isOutgoing)
        
        print("MomentItemNode: 消息设置完成 - 作者: \(authorName), 文本: \(messageText), 发出: \(isOutgoing)")
        
        // 强制重新布局
        self.setNeedsLayout()
    }
    
    private func updateBubbleBackground(isOutgoing: Bool) {
        // 创建类似Telegram的气泡背景
        let bubbleColor = isOutgoing ? UIColor.systemBlue : UIColor(red: 0.95, green: 0.95, blue: 0.97, alpha: 1.0)
        let cornerRadius: CGFloat = 18.0
        let minCornerRadius: CGFloat = 4.0
        
        // 生成气泡背景图片
        let bubbleImage = self.generateBubbleImage(
            cornerRadius: cornerRadius,
            minCornerRadius: minCornerRadius,
            isOutgoing: isOutgoing,
            fillColor: bubbleColor
        )
        
        bubbleBackgroundNode.image = bubbleImage
    }
    
    private func generateBubbleImage(cornerRadius: CGFloat, minCornerRadius: CGFloat, isOutgoing: Bool, fillColor: UIColor) -> UIImage {
        let size = CGSize(width: 60, height: 40)
        
        return UIGraphicsImageRenderer(size: size).image { context in
            let rect = CGRect(origin: .zero, size: size)
            let cgContext = context.cgContext
            
            // 设置填充颜色
            cgContext.setFillColor(fillColor.cgColor)
            
            // 创建圆角矩形路径
            let path = UIBezierPath(roundedRect: rect.insetBy(dx: 2, dy: 2), cornerRadius: cornerRadius)
            
            // 如果是发出的消息，在右下角添加小尾巴
            if isOutgoing {
                let tailPath = UIBezierPath()
                let tailPoint = CGPoint(x: rect.maxX - 2, y: rect.maxY - 8)
                tailPath.move(to: tailPoint)
                tailPath.addLine(to: CGPoint(x: rect.maxX + 4, y: rect.maxY - 2))
                tailPath.addLine(to: CGPoint(x: rect.maxX - 2, y: rect.maxY - 2))
                tailPath.close()
                path.append(tailPath)
            } else {
                // 如果是接收的消息，在左下角添加小尾巴
                let tailPath = UIBezierPath()
                let tailPoint = CGPoint(x: rect.minX + 2, y: rect.maxY - 8)
                tailPath.move(to: tailPoint)
                tailPath.addLine(to: CGPoint(x: rect.minX - 4, y: rect.maxY - 2))
                tailPath.addLine(to: CGPoint(x: rect.minX + 2, y: rect.maxY - 2))
                tailPath.close()
                path.append(tailPath)
            }
            
            path.fill()
        }.resizableImage(withCapInsets: UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20))
    }
    
    override func layout() {
        super.layout()
        let padding: CGFloat = 12
        let horizontalMargin: CGFloat = 16
        let verticalMargin: CGFloat = 4
        let bounds = self.bounds
        
        // 判断是否为发出的消息
        let isOutgoing = message?.flags.contains(.Incoming) == false
        
        // 计算内容尺寸
        let maxContentWidth = bounds.width * 0.75 // 最大宽度为屏幕的75%
        let maxTextWidth = maxContentWidth - padding * 2
        
        let authorSize = authorNode.measure(CGSize(width: maxTextWidth, height: .greatestFiniteMagnitude))
        let textSize = textNode.measure(CGSize(width: maxTextWidth, height: .greatestFiniteMagnitude))
        let dateSize = dateNode.measure(CGSize(width: maxTextWidth, height: .greatestFiniteMagnitude))
        
        // 计算气泡内容的总高度和宽度
        let contentHeight = authorSize.height + textSize.height + dateSize.height + padding * 2 + 16 // 16为间距
        let contentWidth = max(max(authorSize.width, textSize.width), dateSize.width) + padding * 2
        
        // 根据消息方向设置气泡位置
        let bubbleX: CGFloat
        if isOutgoing {
            bubbleX = bounds.width - contentWidth - horizontalMargin
        } else {
            bubbleX = horizontalMargin
        }
        
        // 设置气泡背景框架
        bubbleBackgroundNode.frame = CGRect(
            x: bubbleX,
            y: verticalMargin,
            width: contentWidth,
            height: contentHeight
        )
        
        // 在气泡内部布局文本节点
        authorNode.frame = CGRect(
            origin: CGPoint(x: padding, y: padding),
            size: authorSize
        )
        
        textNode.frame = CGRect(
            origin: CGPoint(x: padding, y: authorNode.frame.maxY + 4),
            size: textSize
        )
        
        dateNode.frame = CGRect(
            origin: CGPoint(x: padding, y: textNode.frame.maxY + 4),
            size: dateSize
        )
        
        print("MomentItemNode: 布局完成 - bubbleFrame: \(bubbleBackgroundNode.frame), isOutgoing: \(isOutgoing)")
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
