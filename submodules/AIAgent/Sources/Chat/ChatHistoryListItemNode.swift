import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import SwiftSignalKit
import AccountContext
import ItemListUI

final class ChatHistoryListItemNode: ListViewItemNode {
    private let titleNode = ASTextNode()
    private let contentNode = ASTextNode()
    private let timeNode = ASTextNode()
    private let separatorNode = ASDisplayNode()
    private let bubbleBackgroundNode = ASDisplayNode()
    
    override init(layerBacked: Bool, dynamicBounce: Bool = true, rotated: Bool = false, seeThrough: Bool = false) {
        super.init(layerBacked: layerBacked, dynamicBounce: dynamicBounce, rotated: rotated, seeThrough: seeThrough)
        
        // 设置为layer-backed以提高性能
        titleNode.isLayerBacked = true
        contentNode.isLayerBacked = true
        timeNode.isLayerBacked = true
        separatorNode.isLayerBacked = true
        bubbleBackgroundNode.isLayerBacked = true
        
        // 设置气泡背景
        bubbleBackgroundNode.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.1)
        bubbleBackgroundNode.cornerRadius = 12.0
        
        // 设置分隔线
        if #available(iOS 13.0, *) {
            separatorNode.backgroundColor = UIColor.separator
        } else {
            // Fallback on earlier versions
        }
        
        // 添加子节点
        addSubnode(bubbleBackgroundNode)
        addSubnode(titleNode)
        addSubnode(contentNode)
        addSubnode(timeNode)
        addSubnode(separatorNode)
    }
    
    convenience init() {
        self.init(layerBacked: true, dynamicBounce: false)
    }
    
    func setChatModel(_ chatModel: AgentChatModel) {
        // 添加调试输出
        print("ChatHistoryListItemNode: 设置聊天模型")
        print("ChatHistoryListItemNode: ID: \(chatModel.id)")
        print("ChatHistoryListItemNode: 用户消息: \(String(chatModel.userMessage.prefix(50)))")
        print("ChatHistoryListItemNode: AI回复长度: \(chatModel.aiResponse.count)")
        print("ChatHistoryListItemNode: AI回复前100字符: \(String(chatModel.aiResponse.prefix(100)))")
        
        // 设置标题
        let titleText = "Chat #\(chatModel.messageCount)"
        let titleColor: UIColor
        if #available(iOS 13.0, *) {
            titleColor = UIColor.label
        } else {
            titleColor = UIColor.black
        }
        
        titleNode.attributedText = NSAttributedString(
            string: titleText,
            attributes: [
                .font: UIFont.boldSystemFont(ofSize: 16),
                .foregroundColor: titleColor
            ]
        )
        
        // 解析和格式化内容
        let formattedContent = parseAndFormatContent(chatModel.aiResponse)
        print("ChatHistoryListItemNode: 最终格式化内容: \(String(formattedContent))")
        
        let textColor: UIColor
        if #available(iOS 13.0, *) {
            textColor = UIColor.secondaryLabel
        } else {
            textColor = UIColor.lightGray
        }
        
        contentNode.attributedText = NSAttributedString(
            string: formattedContent,
            attributes: [
                .font: UIFont.systemFont(ofSize: 14),
                .foregroundColor: textColor
            ]
        )
        
        // 设置时间
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        let timeText = formatter.string(from: chatModel.timestamp)
        
        let timeColor: UIColor
        if #available(iOS 13.0, *) {
            timeColor = UIColor.tertiaryLabel
        } else {
            timeColor = UIColor.darkGray
        }
        
        timeNode.attributedText = NSAttributedString(
            string: timeText,
            attributes: [
                .font: UIFont.systemFont(ofSize: 12),
                .foregroundColor: timeColor
            ]
        )
        
        // 触发布局更新
        setNeedsLayout()
    }
    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
        let leftInset: CGFloat = 16.0
        let rightInset: CGFloat = 16.0
        let topInset: CGFloat = 12.0
        let bottomInset: CGFloat = 12.0
        let verticalSpacing: CGFloat = 4.0
        
        let contentWidth = size.width - leftInset - rightInset - 24.0 // 24.0 for bubble padding
        
        // 计算各个文本节点的布局
        let makeTitleLayout = TextNode.asyncLayout(titleNode)
        let makeContentLayout = TextNode.asyncLayout(contentNode)
        let makeTimeLayout = TextNode.asyncLayout(timeNode)
        
        let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(
            attributedString: titleNode.attributedText,
            backgroundColor: nil,
            maximumNumberOfLines: 1,
            truncationType: .end,
            constrainedSize: CGSize(width: contentWidth, height: .greatestFiniteMagnitude),
            alignment: .natural,
            cutout: nil,
                insets: UIEdgeInsets()
            ))
            
        let (contentLayout, contentApply) = makeContentLayout(TextNodeLayoutArguments(
            attributedString: contentNode.attributedText,
            backgroundColor: nil,
            maximumNumberOfLines: 0,
            truncationType: .end,
            constrainedSize: CGSize(width: contentWidth, height: .greatestFiniteMagnitude),
            alignment: .natural,
            cutout: nil,
            insets: UIEdgeInsets()
        ))
        
        let (timeLayout, timeApply) = makeTimeLayout(TextNodeLayoutArguments(
            attributedString: timeNode.attributedText,
            backgroundColor: nil,
            maximumNumberOfLines: 1,
            truncationType: .end,
            constrainedSize: CGSize(width: contentWidth, height: .greatestFiniteMagnitude),
            alignment: .natural,
            cutout: nil,
            insets: UIEdgeInsets()
        ))
        
        // 应用布局
        let _ = titleApply()
        let _ = contentApply()
        let _ = timeApply()
        
        // 设置节点位置
        let bubblePadding: CGFloat = 12.0
        let bubbleFrame = CGRect(
            x: leftInset,
            y: topInset,
            width: size.width - leftInset - rightInset,
            height: size.height - topInset - bottomInset
        )
        
        transition.updateFrame(node: bubbleBackgroundNode, frame: bubbleFrame)
        
        let titleFrame = CGRect(
            x: leftInset + bubblePadding,
            y: topInset + bubblePadding,
            width: titleLayout.size.width,
            height: titleLayout.size.height
        )
        transition.updateFrame(node: titleNode, frame: titleFrame)
        
        let contentFrame = CGRect(
            x: leftInset + bubblePadding,
            y: titleFrame.maxY + verticalSpacing,
            width: contentLayout.size.width,
            height: contentLayout.size.height
        )
        transition.updateFrame(node: contentNode, frame: contentFrame)
        
        let timeFrame = CGRect(
            x: leftInset + bubblePadding,
            y: contentFrame.maxY + verticalSpacing,
            width: timeLayout.size.width,
            height: timeLayout.size.height
        )
        transition.updateFrame(node: timeNode, frame: timeFrame)
        
        let separatorFrame = CGRect(
            x: leftInset,
            y: size.height - 0.5,
            width: size.width - leftInset,
            height: 0.5
        )
        transition.updateFrame(node: separatorNode, frame: separatorFrame)
    }
    
    override func layout() {
        super.layout()
        
        let bounds = self.bounds
        let leftInset: CGFloat = 16.0
        let rightInset: CGFloat = 16.0
        let topInset: CGFloat = 12.0
        let verticalSpacing: CGFloat = 4.0
        let bubblePadding: CGFloat = 12.0
        let maxWidth = bounds.width - leftInset - rightInset - bubblePadding * 2
        
        let titleSize = titleNode.measure(CGSize(width: maxWidth, height: .greatestFiniteMagnitude))
        let contentSize = contentNode.measure(CGSize(width: maxWidth, height: .greatestFiniteMagnitude))
        let timeSize = timeNode.measure(CGSize(width: maxWidth, height: .greatestFiniteMagnitude))
        
        // 设置气泡背景
        bubbleBackgroundNode.frame = CGRect(
            x: leftInset,
            y: topInset,
            width: bounds.width - leftInset - rightInset,
            height: bounds.height - topInset - 12.0
        )
        
        // 设置文本节点位置
        var currentY = topInset + bubblePadding
        
        titleNode.frame = CGRect(
            x: leftInset + bubblePadding,
            y: currentY,
            width: maxWidth,
            height: titleSize.height
        )
        currentY += titleSize.height + verticalSpacing
        
        contentNode.frame = CGRect(
            x: leftInset + bubblePadding,
            y: currentY,
            width: maxWidth,
            height: contentSize.height
        )
        currentY += contentSize.height + verticalSpacing
        
        timeNode.frame = CGRect(
            x: leftInset + bubblePadding,
            y: currentY,
            width: maxWidth,
            height: timeSize.height
        )
        
        separatorNode.frame = CGRect(
            x: leftInset,
            y: bounds.height - 0.5,
            width: bounds.width - leftInset,
            height: 0.5
        )
        
        print("✅ title size: \(titleSize), content size: \(contentSize), time size: \(timeSize)")
    }

    
    private func updateBubbleBackground(isOutgoing: Bool) {
        let backgroundColor: UIColor
        if #available(iOS 13.0, *) {
            backgroundColor = isOutgoing ? UIColor.systemBlue.withAlphaComponent(0.1) : UIColor.systemGray6
        } else {
            backgroundColor = isOutgoing ? UIColor.blue.withAlphaComponent(0.1) : UIColor.lightGray
        }
        bubbleBackgroundNode.backgroundColor = backgroundColor
    }
    
    private func parseAndFormatContent(_ content: String) -> String {
        print("ChatHistoryListItemNode: 开始解析内容，长度: \(content.count)")
        print("ChatHistoryListItemNode: 内容前100字符: \(String(content.prefix(100)))")
        
        if content.isEmpty {
            print("ChatHistoryListItemNode: 警告 - 内容为空")
            return "暂无内容"
        }
        
        // 尝试解析JSON
        if let data = content.data(using: .utf8),
           let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []) {
            
            print("ChatHistoryListItemNode: 成功解析为JSON")
            if let dict = jsonObject as? [String: Any] {
                let result = formatJSONContent(dict)
                print("ChatHistoryListItemNode: JSON格式化结果: \(String(result.prefix(100)))")
                // 如果JSON格式化结果为空，直接返回原始内容的markdown格式
                if result.isEmpty {
                    let fallbackResult = extractMarkdownContent(content)
                    print("ChatHistoryListItemNode: JSON结果为空，使用markdown格式: \(String(fallbackResult.prefix(100)))")
                    return fallbackResult
                }
                return result
            } else if let array = jsonObject as? [Any] {
                let result = "Array with \(array.count) items"
                print("ChatHistoryListItemNode: JSON数组结果: \(result)")
                return result
            }
        }
        
        // 如果不是JSON，尝试提取markdown内容
        print("ChatHistoryListItemNode: 不是JSON，按markdown处理")
        let result = extractMarkdownContent(content)
        print("ChatHistoryListItemNode: Markdown格式化结果: \(String(result.prefix(100)))")
        return result
    }
    
    private func formatJSONContent(_ jsonObject: [String: Any]) -> String {
        // 检查是否包含text字段
        if let text = jsonObject["text"] as? String {
            let formattedText = formatMarkdownText(text)
            
            // 移除字符限制，显示完整内容
            var result = formattedText
            
            // 添加其他字段信息
            var additionalInfo: [String] = []
            
            if let mainTopic = jsonObject["main-topic"] as? String, !mainTopic.isEmpty {
                additionalInfo.append("🎯 \(mainTopic)")
            }
            
            if let pendingMatters = jsonObject["pending-matters"] as? [Any], !pendingMatters.isEmpty {
                additionalInfo.append("📋 \(pendingMatters.count) pending items")
            }
            
            if !additionalInfo.isEmpty {
                result += "\n\n" + additionalInfo.joined(separator: " • ")
            }
            
            return result
        }
        
        return ""
    }
    
    private func formatJSONObject(_ jsonObject: [String: Any]) -> String {
        var result = ""
        
        for (key, value) in jsonObject {
            result += "**\(key)**: "
            
            if let stringValue = value as? String {
                result += formatMarkdownText(stringValue) + "\n\n"
            } else if let arrayValue = value as? [Any] {
                result += "\n"
                for item in arrayValue {
                    if let dictItem = item as? [String: Any] {
                        result += formatNestedObject(dictItem, indent: "  ")
                    } else {
                        result += "  • \(item)\n"
                    }
                }
                result += "\n"
            } else {
                result += "\(value)\n\n"
            }
        }
        
        return result
    }
    
    private func formatNestedObject(_ object: [String: Any], indent: String) -> String {
        var result = ""
        
        for (key, value) in object {
            result += "\(indent)• **\(key)**: "
            
            if let stringValue = value as? String {
                result += stringValue + "\n"
            } else if let arrayValue = value as? [Any] {
                result += "\n"
                for item in arrayValue {
                    if let dictItem = item as? [String: Any] {
                        result += formatNestedObject(dictItem, indent: indent + "  ")
                    } else {
                        result += "\(indent)  - \(item)\n"
                    }
                }
            } else {
                result += "\(value)\n"
            }
        }
        
        return result
    }
    
    private func formatMarkdownText(_ text: String) -> String {
        // 简单的markdown格式化
        var formatted = text
        
        // 处理JSON代码块 - 使用NSRegularExpression进行更精确的匹配
        let jsonPattern = "```json[\\s\\S]*?```"
        if let regex = try? NSRegularExpression(pattern: jsonPattern, options: []) {
            let range = NSRange(location: 0, length: formatted.utf16.count)
            let matches = regex.matches(in: formatted, options: [], range: range)
            
            for match in matches.reversed() {
                if let matchRange = Range(match.range, in: formatted) {
                    let matchText = String(formatted[matchRange])
                    let content = matchText
                        .replacingOccurrences(of: "```json\\n?", with: "", options: .regularExpression)
                        .replacingOccurrences(of: "\\n?```", with: "", options: .regularExpression)
                    let replacement = "📋 JSON数据:\\n\(content)"
                    formatted.replaceSubrange(matchRange, with: replacement)
                }
            }
        }
        
        // 处理普通代码块
        let codePattern = "```[\\s\\S]*?```"
        if let regex = try? NSRegularExpression(pattern: codePattern, options: []) {
            let range = NSRange(location: 0, length: formatted.utf16.count)
            let matches = regex.matches(in: formatted, options: [], range: range)
            
            for match in matches.reversed() {
                if let matchRange = Range(match.range, in: formatted) {
                    let matchText = String(formatted[matchRange])
                    let content = matchText
                        .replacingOccurrences(of: "```[^\\n]*\\n?", with: "", options: .regularExpression)
                        .replacingOccurrences(of: "\\n?```", with: "", options: .regularExpression)
                    let replacement = "💻 代码:\\n\(content)"
                    formatted.replaceSubrange(matchRange, with: replacement)
                }
            }
        }
        
        // 处理标题
        formatted = formatted.replacingOccurrences(
            of: "### ([^\\n]+)",
            with: "🔸 $1",
            options: .regularExpression
        )
        
        formatted = formatted.replacingOccurrences(
            of: "## ([^\\n]+)",
            with: "🔹 $1",
            options: .regularExpression
        )
        
        formatted = formatted.replacingOccurrences(
            of: "# ([^\\n]+)",
            with: "🔷 $1",
            options: .regularExpression
        )
        
        // 处理粗体
        formatted = formatted.replacingOccurrences(
            of: "\\*\\*([^*]+)\\*\\*",
            with: "$1",
            options: .regularExpression
        )
        
        // 处理列表项
        formatted = formatted.replacingOccurrences(
            of: "^- ([^\\n]+)",
            with: "• $1",
            options: .regularExpression
        )
        
        return formatted
    }
    
    private func extractMarkdownContent(_ text: String) -> String {
        // 如果不是JSON，直接格式化markdown
        let formatted = formatMarkdownText(text)
        
        return formatted
    }
    
    // 添加计算高度的方法
    func calculateHeight(width: CGFloat) -> CGFloat {
        let leftInset: CGFloat = 16.0
        let rightInset: CGFloat = 16.0
        let topInset: CGFloat = 12.0
        let bottomInset: CGFloat = 12.0
        let verticalSpacing: CGFloat = 4.0
        let bubblePadding: CGFloat = 12.0
        let maxWidth = width - leftInset - rightInset - bubblePadding * 2
        
        let titleSize = titleNode.measure(CGSize(width: maxWidth, height: .greatestFiniteMagnitude))
        let contentSize = contentNode.measure(CGSize(width: maxWidth, height: .greatestFiniteMagnitude))
        let timeSize = timeNode.measure(CGSize(width: maxWidth, height: .greatestFiniteMagnitude))
        
        let totalHeight = topInset + bubblePadding + titleSize.height + verticalSpacing + 
                         contentSize.height + verticalSpacing + timeSize.height + bubblePadding + bottomInset
        
        return totalHeight
    }
}
