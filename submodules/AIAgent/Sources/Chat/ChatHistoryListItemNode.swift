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
            return formatChatSummaryText(text)
        }
        
        return ""
    }
    
    private func formatChatSummaryText(_ text: String) -> String {
        var formatted = text
        
        // 处理JSON代码块，提取并格式化聊天摘要数据
        let jsonPattern = "```json[\\s\\S]*?```"
        if let regex = try? NSRegularExpression(pattern: jsonPattern, options: []) {
            let range = NSRange(location: 0, length: formatted.utf16.count)
            let matches = regex.matches(in: formatted, options: [], range: range)
            
            for match in matches.reversed() {
                if let matchRange = Range(match.range, in: formatted) {
                    let matchText = String(formatted[matchRange])
                    let jsonContent = matchText
                        .replacingOccurrences(of: "```json\\n?", with: "", options: .regularExpression)
                        .replacingOccurrences(of: "\\n?```", with: "", options: .regularExpression)
                    
                    let formattedSummary = formatSummaryContent(jsonContent)
                    formatted.replaceSubrange(matchRange, with: formattedSummary)
                }
            }
        }
        
        // 处理HTML注释标记 - 只有当内容不为空时才转换为显示格式
        // 首先检查并移除空的HTML注释块
        let emptyJsonPattern = "<!-- json-start: [^>]+ -->\\s*\\[\\s*\\]\\s*<!-- json-end -->"
        formatted = formatted.replacingOccurrences(
            of: emptyJsonPattern,
            with: "",
            options: .regularExpression
        )
        
        // 移除孤立的HTML注释标记（没有内容的）
        formatted = formatted.replacingOccurrences(
            of: "<!-- json-start: [^>]+ -->\\s*<!-- json-end -->",
            with: "",
            options: .regularExpression
        )
        
        // 对于剩余的有内容的HTML注释，转换为显示格式
        formatted = formatted.replacingOccurrences(
            of: "<!-- json-start: ([^>]+) -->",
            with: "\n📊 $1:",
            options: .regularExpression
        )
        
        formatted = formatted.replacingOccurrences(
            of: "<!-- json-end -->",
            with: "",
            options: .regularExpression
        )
        
        // 处理其他markdown格式
        formatted = formatMarkdownText(formatted)
        
        return formatted.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func formatSummaryContent(_ jsonContent: String) -> String {
        print("ChatHistoryListItemNode: formatSummaryContent输入内容: \(jsonContent.prefix(200))")
        
        // 清理JSON内容，移除HTML注释
        var cleanedContent = jsonContent
        
        // 移除HTML注释标记
        cleanedContent = cleanedContent.replacingOccurrences(
            of: "<!-- json-start: [^>]+ -->",
            with: "",
            options: .regularExpression
        )
        
        cleanedContent = cleanedContent.replacingOccurrences(
            of: "<!-- json-end -->",
            with: "",
            options: .regularExpression
        )
        
        // 清理多余的空白字符
        cleanedContent = cleanedContent.trimmingCharacters(in: .whitespacesAndNewlines)
        
        print("ChatHistoryListItemNode: 清理后的JSON内容: \(cleanedContent.prefix(200))")
        
        // 尝试解析JSON内容
        guard let data = cleanedContent.data(using: .utf8) else {
            print("ChatHistoryListItemNode: 无法转换为Data")
            return "📋 聊天摘要数据"
        }
        
        // 尝试解析为JSON数组
        if let jsonArray = try? JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]] {
            print("ChatHistoryListItemNode: 成功解析为JSON数组，包含\(jsonArray.count)个项目")
            
            // 验证数组是否包含有意义的内容
            if !hasValidContent(in: jsonArray) {
                print("ChatHistoryListItemNode: JSON数组没有有效内容，过滤掉")
                return ""
            }
            
            return formatJSONArray(jsonArray)
        }
        
        // 尝试解析为单个JSON对象
        if let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
            print("ChatHistoryListItemNode: 成功解析为JSON对象")
            
            // 验证对象是否包含有意义的内容
            if !hasValidContent(in: jsonObject) {
                print("ChatHistoryListItemNode: JSON对象没有有效内容，过滤掉")
                return ""
            }
            
            return formatSingleJSONObject(jsonObject)
        }
        
        print("ChatHistoryListItemNode: JSON解析失败")
        return "📋 聊天摘要数据"
    }
    
    // 验证JSON数组是否包含有意义的内容
    private func hasValidContent(in jsonArray: [[String: Any]]) -> Bool {
        for item in jsonArray {
            if hasValidContent(in: item) {
                return true
            }
        }
        return false
    }
    
    // 验证JSON对象是否包含有意义的内容
    private func hasValidContent(in jsonObject: [String: Any]) -> Bool {
        for (key, value) in jsonObject {
            // 检查字符串值是否有意义
            if let stringValue = value as? String {
                let trimmedValue = stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
                // 过滤掉空字符串、纯数字ID、或只包含特殊字符的值
                if !trimmedValue.isEmpty && 
                   !isOnlyNumericOrSpecialChars(trimmedValue) &&
                   hasSubstantialContent(trimmedValue) {
                    return true
                }
            }
            // 检查数组值
            else if let arrayValue = value as? [Any], !arrayValue.isEmpty {
                // 检查数组中是否有有意义的内容
                for arrayItem in arrayValue {
                    if let dictItem = arrayItem as? [String: Any] {
                        if hasValidContent(in: dictItem) {
                            return true
                        }
                    } else if let stringItem = arrayItem as? String {
                        let trimmedItem = stringItem.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmedItem.isEmpty && 
                           !isOnlyNumericOrSpecialChars(trimmedItem) &&
                           hasSubstantialContent(trimmedItem) {
                            return true
                        }
                    }
                }
            }
            // 检查嵌套对象
            else if let nestedObject = value as? [String: Any] {
                if hasValidContent(in: nestedObject) {
                    return true
                }
            }
        }
        return false
    }
    
    // 检查字符串是否只包含数字或特殊字符
    private func isOnlyNumericOrSpecialChars(_ string: String) -> Bool {
        let pattern = "^[0-9\\-_@#$%^&*()+={}\\[\\]|\\\\:;\"'<>,.?/~`!]*$"
        return string.range(of: pattern, options: .regularExpression) != nil
    }
    
    // 检查字符串是否包含实质性内容（至少3个字符且包含字母）
    private func hasSubstantialContent(_ string: String) -> Bool {
        // 至少3个字符
        guard string.count >= 3 else { return false }
        
        // 必须包含至少一个字母
        let letterPattern = "[a-zA-Z\\u{4e00}-\\u{9fff}]"
        return string.range(of: letterPattern, options: .regularExpression) != nil
    }

    private func formatJSONArray(_ jsonArray: [[String: Any]]) -> String {
        var result = ""
        var hasContent = false
        
        for (index, item) in jsonArray.enumerated() {
            var itemContent = ""
            var itemHasContent = false
            
            // 检查是否为主话题格式 (main-topic)
            if let title = item["title"] as? String, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                itemContent += "\n📝 \(title)\n"
                itemHasContent = true
                
                // 处理summaryItems
                if let summaryItems = item["summaryItems"] as? [[String: Any]] {
                    for summaryItem in summaryItems {
                        if let subtitle = summaryItem["subtitle"] as? String, !subtitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            itemContent += "  • \(subtitle)\n"
                        }
                    }
                }
                
                // 处理summaryChatIds
                if let chatIds = item["summaryChatIds"] as? [String], !chatIds.isEmpty {
                    itemContent += "  💬 相关聊天: \(chatIds.count)个\n"
                }
                
            } else if let chatId = item["chatId"] as? String, !chatId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                      let summary = item["summary"] as? String, !summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                
                // 检查是否为垃圾消息格式 (garbage-message)
                if let level = item["level"] as? String {
                    let levelIcon = level == "high" ? "🚨" : "⚠️"
                    let chatTitle = item["chatTitle"] as? String ?? "Unknown Chat"
                    itemContent += "\n\(levelIcon) 垃圾消息\n"
                    itemContent += "  📱 \(chatTitle)\n"
                    itemContent += "  📄 \(summary)\n"
                    
                    if let messageIds = item["relevantMessageIds"] as? [Any], !messageIds.isEmpty {
                        itemContent += "  🔗 相关消息: \(messageIds.count)条\n"
                    }
                    
                } else {
                    // 待办事项格式 (pending-matters)
                    let chatTitle = item["chatTitle"] as? String ?? "Unknown Chat"
                    itemContent += "\n✅ 待办事项\n"
                    itemContent += "  📱 \(chatTitle)\n"
                    itemContent += "  📋 \(summary)\n"
                    
                    if let messageIds = item["relevantMessageIds"] as? [Any], !messageIds.isEmpty {
                        itemContent += "  🔗 相关消息: \(messageIds.count)条\n"
                    }
                }
                itemHasContent = true
                
            } else {
                // 处理其他格式的项目
                var otherContent = ""
                for (key, value) in item {
                    if let stringValue = value as? String, !stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        otherContent += "  \(key): \(stringValue)\n"
                        itemHasContent = true
                    } else if let arrayValue = value as? [Any], !arrayValue.isEmpty {
                        otherContent += "  \(key): [\(arrayValue.count) 项]\n"
                        itemHasContent = true
                    }
                }
                
                if itemHasContent {
                    itemContent += "\n📄 项目 \(index + 1)\n"
                    itemContent += otherContent
                }
            }
            
            if itemHasContent {
                result += itemContent
                hasContent = true
            } else {
                print("ChatHistoryListItemNode: 数据没有内容，不展示 - 项目\(index)")
            }
        }
        
        if !hasContent {
            print("ChatHistoryListItemNode: 数据没有内容，不展示 - 整个数组为空")
            return ""
        }
        
        return result
    }
    
    private func formatSingleJSONObject(_ jsonObject: [String: Any]) -> String {
        var result = ""
        var hasContent = false
        
        for (key, value) in jsonObject {
            if let stringValue = value as? String, !stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                if !hasContent {
                    result += "\n📋 聊天摘要\n"
                    hasContent = true
                }
                result += "\n**\(key)**: \(stringValue)\n"
            } else if let arrayValue = value as? [[String: Any]], !arrayValue.isEmpty {
                var arrayContent = ""
                for item in arrayValue {
                    if let title = item["title"] as? String, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        arrayContent += "  • \(title)\n"
                    }
                }
                
                if !arrayContent.isEmpty {
                    if !hasContent {
                        result += "\n📋 聊天摘要\n"
                        hasContent = true
                    }
                    result += "\n**\(key)**:\n"
                    result += arrayContent
                }
            }
        }
        
        if !hasContent {
            print("ChatHistoryListItemNode: 数据没有内容，不展示 - JSON对象为空")
            return ""
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
