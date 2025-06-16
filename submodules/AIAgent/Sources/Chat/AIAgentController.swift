// MomentsController.swift

import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import AccountContext
import TelegramPresentationData
import PresentationDataUtils
import TelegramUIPreferences
import ItemListUI

// Import Chat module classes - now in same module, no prefix needed



public final class AIAgentController: ViewController {
    internal let context: AccountContext
    private var messagesDisposable: Disposable?
    private let listNode: ListView
    private var messages: [Message] = []
    // 移除了 entries: [MomentEntry] 属性，现在使用 chatHistoryData
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

        self.title = "AIAgent"
        self.tabBarItem.title = "AIAgent"
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

    // 移除了 displayMessages 和 updateListView 方法，现在使用 displayChatHistoryData

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
    public func triggerDataChainLogic() {
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
