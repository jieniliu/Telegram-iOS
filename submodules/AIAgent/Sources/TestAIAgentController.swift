import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import SwiftSignalKit
import AccountContext
import TelegramPresentationData
import ItemListUI

// MARK: - 简单测试数据结构
struct SimpleTestItem {
    let id: String
    let title: String
    let subtitle: String
}

// MARK: - 测试AI代理控制器
public final class TestAIAgentController: ViewController {
    private let context: AccountContext
    private var listNode: ListView!
    private var items: [SimpleTestItem] = []
    private var testSquare: UIView!
    
    public init(context: AccountContext) {
        self.context = context
//        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        super.init(navigationBarPresentationData: nil)
        let screenBounds = UIScreen.main.bounds
        self.view.frame = screenBounds
        self.displayNode.frame = screenBounds
        self.title = "AI Agent Test"
        print("TestAIAgentController: 初始化完成")
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        print("TestAIAgentController: 销毁")
    }
    
    // MARK: - 简单测试数据生成
    private func createSimpleTestData() -> [SimpleTestItem] {
        return [
            SimpleTestItem(id: "1", title: "测试项目 1", subtitle: "这是第一个测试项目"),
            SimpleTestItem(id: "2", title: "测试项目 2", subtitle: "这是第二个测试项目"),
            SimpleTestItem(id: "3", title: "测试项目 3", subtitle: "这是第三个测试项目"),
            SimpleTestItem(id: "4", title: "AI 代理测试", subtitle: "测试 AI 代理功能"),
            SimpleTestItem(id: "5", title: "界面测试", subtitle: "测试用户界面显示")
            
        ]
    }
    
    private func loadTestData() {
        print("TestAIAgentController: 开始加载测试数据")
        self.items = createSimpleTestData()
        print("TestAIAgentController: 测试数据加载完成，共 \(items.count) 条")
        updateListView()
    }
    
    // MARK: - UI更新
    private func updateListView() {
        print("TestAIAgentController: 开始更新列表视图，条目数: \(items.count)")
        
        let listItems = items.map { item in
            SimpleTestListItem(
                context: self.context,
                testItem: item
            )
        }
        
        let insertItems = listItems.enumerated().map { index, item in
            ListViewInsertItem(index: index, previousIndex: nil, item: item, directionHint: nil)
        }
        
        listNode.transaction(deleteIndices: [], insertIndicesAndItems: insertItems, updateIndicesAndItems: [], options: [.Synchronous], scrollToItem: nil, additionalScrollDistance: 0.0, updateSizeAndInsets: nil, stationaryItemRange: nil, updateOpaqueState: nil, completion: { [weak self] _ in
            print("TestAIAgentController: 列表视图更新完成")
            self?.updateListNodeLayout()
        })
    }
    
    private func updateListNodeLayout() {
        guard let listNode = self.listNode else { return }
        
        // 使用 displayNode 的 bounds 或屏幕尺寸，确保有正确的尺寸
        let bounds = self.displayNode.bounds.size != .zero ? self.displayNode.bounds : CGRect(origin: .zero, size: UIScreen.main.bounds.size)
        let insets = UIEdgeInsets(top: 88, left: 0, bottom: 34, right: 0)
        
//        listNode.bounds = bounds
//        listNode.position = CGPoint(x: bounds.midX, y: bounds.midY)
        listNode.frame = bounds
        listNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [], updateSizeAndInsets: ListViewUpdateSizeAndInsets(
            size: bounds.size,
            insets: insets,
            duration: 0,
            curve: .Default(duration: nil)
        ), updateOpaqueState: nil)
        
        print("TestAIAgentController: 列表节点布局更新完成 - size: \(bounds.size), insets: \(insets)")
    }
    
    // MARK: - 视图生命周期
    public override func loadDisplayNode() {
        self.displayNode = ASDisplayNode() // ✅ 必须手动创建 displayNode 实例
        self.displayNode.backgroundColor = UIColor.white
        
        // 初始化 ListView
        self.listNode = ListView()
        self.displayNode.addSubnode(self.listNode)
        
        // 添加绿色调试方块
        self.testSquare = UIView()
        self.testSquare.backgroundColor = UIColor.green
        self.testSquare.frame = CGRect(x: 20, y: 100, width: 50, height: 50)
        self.displayNode.view.addSubview(self.testSquare)

        print("TestAIAgentController: loadDisplayNode 完成")
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        print("TestAIAgentController: viewDidLoad 开始")
        
        self.view.backgroundColor = UIColor.white
        
        // 确保 displayNode 有正确的尺寸
        if self.displayNode.frame.size == .zero {
            let screenBounds = UIScreen.main.bounds
            self.displayNode.frame = screenBounds
            print("TestAIAgentController: 在 viewDidLoad 中设置 displayNode 尺寸 - \(screenBounds)")
        }
        
        updateTestSquarePosition()
        loadTestData()
        updateListNodeLayout() // 确保在加载数据后更新列表布局
        
        print("TestAIAgentController: viewDidLoad 完成 - displayNode frame: \(self.displayNode.frame)")
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        print("TestAIAgentController: viewWillAppear")
        
        // 确保视图有正确的尺寸
        if self.view.bounds.size == .zero {
            self.view.frame = UIScreen.main.bounds
            print("TestAIAgentController: 在 viewWillAppear 中设置 view 尺寸")
        }
    }
    
    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        print("TestAIAgentController: viewDidAppear")
        print("View frame: \(self.view.frame)")
        print("DisplayNode frame: \(self.displayNode.frame)")
        print("View superview: \(self.view.superview)")
        print("Is view in window: \(self.view.window != nil)")
        
        // 确保布局正确
        if self.displayNode.frame.size == .zero {
            let screenBounds = UIScreen.main.bounds
            self.displayNode.frame = screenBounds
            updateListNodeLayout()
        }
        
        // 强制触发布局
        self.view.setNeedsLayout()
        self.view.layoutIfNeeded()
        
        updateTestSquarePosition()
    }
    
    private func updateTestSquarePosition() {
        guard let testSquare = self.testSquare else { return }
        
        let viewSize = self.view.bounds.size
        let displaySize = self.displayNode.bounds.size
        
        print("TestAIAgentController: 更新测试方块位置 - view: \(viewSize), display: \(displaySize)")
        
        testSquare.frame = CGRect(
            x: max(viewSize.width, displaySize.width) - 70,
            y: 100,
            width: 50,
            height: 50
        )
    }
    
    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        let bounds = self.view.bounds
        print("TestAIAgentController: viewDidLayoutSubviews - view bounds: \(bounds)")
        
        // 确保 displayNode 有正确的尺寸
        if bounds.size != .zero {
            self.displayNode.frame = bounds
            updateListNodeLayout()
        } else {
            // 如果 view bounds 为零，使用屏幕尺寸
            let screenBounds = UIScreen.main.bounds
            self.displayNode.frame = screenBounds
            updateListNodeLayout()
            print("TestAIAgentController: 使用屏幕尺寸设置 displayNode - \(screenBounds)")
        }
        
        updateTestSquarePosition()
    }
}

// MARK: - 简单测试列表项
final class SimpleTestListItem: ListViewItem {
    let context: AccountContext
    let testItem: SimpleTestItem
    
    init(context: AccountContext, testItem: SimpleTestItem) {
        self.context = context
        self.testItem = testItem
    }
    
    var selectable: Bool { return true }
    var accessoryItem: ListViewAccessoryItem? { return nil }
    var headerAccessoryItem: ListViewAccessoryItem? { return nil }
    var approximateHeight: CGFloat { return 80 }
    
    func itemId() -> AnyHashable {
        return "simple_test_\(testItem.id)"
    }
    
    func equals(_ other: ListViewItem) -> Bool {
        guard let other = other as? SimpleTestListItem else { 
            print("SimpleTestListItem: equals 比较失败 - 类型不匹配")
            return false 
        }
        let result = self.testItem.id == other.testItem.id
        print("SimpleTestListItem: equals 比较 - \(self.testItem.id) vs \(other.testItem.id) = \(result)")
        return result
    }
    
    func selected(listView: ListView) {
        print("SimpleTestListItem: 选中了项目 - \(testItem.title)")
    }
    
    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        print("SimpleTestListItem: nodeConfiguredForParams 被调用 - \(testItem.title)")
        async {
            let node = SimpleTestItemNode(context: self.context)
            node.setTestItem(self.testItem)
            
            completion(node, {
                return (nil, { _ in 
                    print("SimpleTestListItem: apply 被调用 - \(self.testItem.title)")
                })
            })
        }
    }
    
    func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        print("SimpleTestListItem: updateNode 被调用 - \(testItem.title)")
        async {
            let layout = ListViewItemNodeLayout(
                contentSize: CGSize(width: params.width, height: 80),
                insets: UIEdgeInsets()
            )
            
            completion(layout, { _ in 
                print("SimpleTestListItem: updateNode apply 被调用 - \(self.testItem.title)")
            })
        }
    }
    
    func asyncLayout() -> (_ item: SimpleTestListItem, _ params: ListViewItemLayoutParams, _ mergedTop: Bool, _ mergedBottom: Bool, _ dateHeaderAtBottom: Bool) -> (ListViewItemNodeLayout, (ListViewItemUpdateAnimation, Bool, Bool) -> ListViewItemNode) {
        print("SimpleTestListItem: asyncLayout 被调用 - \(testItem.title)")
        return { item, params, _, _, _ in
            let layout = ListViewItemNodeLayout(
                contentSize: CGSize(width: params.width, height: 80),
                insets: UIEdgeInsets()
            )
            
            return (layout, { _, _, _ in
                print("SimpleTestListItem: asyncLayout 创建节点 - \(item.testItem.title)")
                let node = SimpleTestItemNode(context: item.context)
                node.setTestItem(item.testItem)
                node.updateLayout(size: layout.contentSize, transition: ContainedViewLayoutTransition.immediate)
                return node
            })
        }
    }
}

// MARK: - 简单测试节点
final class SimpleTestItemNode: ListViewItemNode {
    private let context: AccountContext
    private let contentNode = ASDisplayNode()
    private let titleNode = ASTextNode()
    private let subtitleNode = ASTextNode()
    
    var currentSize: CGSize?
    var currentTransition: ContainedViewLayoutTransition?
    
    init(context: AccountContext) {
        self.context = context
        super.init(layerBacked: false, dynamicBounce: false)
        
        // 设置内容节点样式
        contentNode.backgroundColor = UIColor.lightGray
        contentNode.cornerRadius = 8.0
        contentNode.borderWidth = 1.0
        contentNode.borderColor = UIColor.gray.cgColor
        
        self.addSubnode(contentNode)
        contentNode.addSubnode(titleNode)
        contentNode.addSubnode(subtitleNode)
        
        print("SimpleTestItemNode: 初始化完成")
    }
    
    func setTestItem(_ item: SimpleTestItem) {
        print("SimpleTestItemNode: 设置测试项目 - \(item.title)")
        
        // 设置标题
        titleNode.attributedText = NSAttributedString(string: item.title, attributes: [
            .font: UIFont.boldSystemFont(ofSize: 16),
            .foregroundColor: UIColor.black
        ])
        
        // 设置副标题
        subtitleNode.attributedText = NSAttributedString(string: item.subtitle, attributes: [
            .font: UIFont.systemFont(ofSize: 14),
            .foregroundColor: UIColor.darkGray
        ])
        
        print("SimpleTestItemNode: 项目设置完成 - 标题: \(item.title), 副标题: \(item.subtitle)")
        
        // 强制重新布局
        self.setNeedsLayout()
    }
    
    override func layout() {
        super.layout()
        
        let bounds = self.bounds
        print("SimpleTestItemNode: layout 被调用 - bounds: \(bounds)")
        self.frame = CGRect(origin: .zero, size: bounds.size) // ✅ 明确设置自己的 frame

        let padding: CGFloat = 12
        let margin: CGFloat = 8

        contentNode.frame = CGRect(
            x: margin,
            y: margin,
            width: bounds.width - margin * 2,
            height: bounds.height - margin * 2
        )
        
        let maxWidth = contentNode.bounds.width - padding * 2
        
        let titleSize = titleNode.measure(CGSize(width: maxWidth, height: .greatestFiniteMagnitude))
        titleNode.frame = CGRect(origin: CGPoint(x: padding, y: padding), size: titleSize)
        
        let subtitleSize = subtitleNode.measure(CGSize(width: maxWidth, height: .greatestFiniteMagnitude))
        subtitleNode.frame = CGRect(origin: CGPoint(x: padding, y: titleNode.frame.maxY + 4), size: subtitleSize)

        print("SimpleTestItemNode: 布局完成 - contentNode: \(contentNode.frame), titleNode: \(titleNode.frame)")
    }

    
    override func didLoad() {
        super.didLoad()
        print("SimpleTestItemNode: didLoad 被调用")
        if let size = self.currentSize, let transition = self.currentTransition {
            print("SimpleTestItemNode: didLoad 执行延迟布局 - size: \(size)")
            self.performLayout(size: size, transition: transition)
        }
    }
    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
        print("SimpleTestItemNode: updateLayout 被调用 - size: \(size), isNodeLoaded: \(self.isNodeLoaded)")
        self.currentSize = size
        self.currentTransition = transition
        if self.isNodeLoaded {
            self.performLayout(size: size, transition: transition)
        }
    }
    
    private func performLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
        print("SimpleTestItemNode: performLayout 被调用 - size: \(size)")
        self.frame = CGRect(origin: .zero, size: size)
        self.layout()
        self.setNeedsLayout()
    }
}
