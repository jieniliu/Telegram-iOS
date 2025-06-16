import Foundation
import UIKit
import TelegramCore
import SwiftSignalKit
import AccountContext

// MARK: - AIAgentController Extension
extension AIAgentController {
    /// 配置小群组消息管理器
    private func configureSmallGroupsManager() {
        SmallGroupsMessageManager.shared.configure(with: self.context)
    }
    
    /// 公共方法：加载小群组的最新消息（已废弃，现在使用数据链条逻辑）
    public func loadSmallGroupsMessages() {
        print("loadSmallGroupsMessages 方法已废弃，现在使用 triggerDataChainLogic")
        self.triggerDataChainLogic()
    }
    
    /// 获取少于50人群组的未读消息（已废弃，现在使用数据链条逻辑）
    public func getUnreadMessagesForSmallGroups() {
        print("getUnreadMessagesForSmallGroups 方法已废弃，现在使用 triggerDataChainLogic")
        self.triggerDataChainLogic()
    }
    
    /// 清理小群组消息管理器资源
    public func cleanupSmallGroupsManager() {
        SmallGroupsMessageManager.shared.cleanup()
    }
}
