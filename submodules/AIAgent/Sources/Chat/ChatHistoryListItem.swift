import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import SwiftSignalKit
import AccountContext
import ItemListUI

final class ChatHistoryListItem: ListViewItem {
    let chatModel: AgentChatModel
    
    init(chatModel: AgentChatModel) {
        self.chatModel = chatModel
    }
    
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
    
    func itemId() -> AnyHashable {
        return chatModel.id
    }
    
    func equals(_ other: ListViewItem) -> Bool {
        guard let other = other as? ChatHistoryListItem else { return false }
        return self.chatModel.id == other.chatModel.id
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
            let node = ChatHistoryListItemNode()
            node.setChatModel(self.chatModel)
            
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
            guard let node = node() as? ChatHistoryListItemNode else { return }
            let layout = self.asyncLayout()
            let (nodeLayout, apply) = layout(self, params, previousItem, nextItem)
            
            Queue.mainQueue().async {
                node.contentSize = nodeLayout.contentSize
                node.insets = nodeLayout.insets
                completion(nodeLayout, { _ in apply().1() })
            }
        }
    }
    
    fileprivate func asyncLayout() -> (
        _ item: ListViewItem,
        _ params: ListViewItemLayoutParams,
        _ previousItem: ListViewItem?,
        _ nextItem: ListViewItem?
    ) -> (ListViewItemNodeLayout, () -> (ChatHistoryListItemNode, () -> Void)) {
        return { [weak self] _, params, _, _ in
            guard let strongSelf = self else {
                return (
                    ListViewItemNodeLayout(contentSize: .zero, insets: .zero),
                    { (ChatHistoryListItemNode(), {}) }
                )
            }
            
            let width = params.width
            
            // 创建临时节点来计算高度
            let tempNode = ChatHistoryListItemNode()
            tempNode.setChatModel(strongSelf.chatModel)
            let height = tempNode.calculateHeight(width: width)
            
            let layout = ListViewItemNodeLayout(
                contentSize: CGSize(width: width, height: height),
                insets: UIEdgeInsets()
            )
            
            return (layout, {
                let node = ChatHistoryListItemNode()
                node.setChatModel(strongSelf.chatModel)
                return (node, {})
            })
        }
    }
}
