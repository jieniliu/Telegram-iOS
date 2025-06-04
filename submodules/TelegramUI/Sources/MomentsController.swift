import Foundation
import UIKit
import Display
import AsyncDisplayKit
import AccountContext

public final class MomentsController: ViewController {
    private let context: AccountContext
    
    public init(context: AccountContext) {
        self.context = context
        super.init(navigationBarPresentationData: nil)
        
        self.title = "动态"
        self.tabBarItem.title = "动态"
        if let image = UIImage(named: "TabMoments") {
            self.tabBarItem.image = image
        } else {
            if #available(iOS 13.0, *) {
                self.tabBarItem.image = UIImage(systemName: "person.2.square.stack")
            }
        }
    }
    
    @available(*, unavailable)
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func loadDisplayNode() {
        self.displayNode = ASDisplayNode()
        self.displayNode.backgroundColor = .white
        let label = UILabel()
        label.text = "朋友圈/动态占位页"
        label.textAlignment = .center
        label.textColor = .gray
        label.frame = CGRect(x: 0, y: 200, width: UIScreen.main.bounds.width, height: 40)
        self.displayNode.view.addSubview(label)
    }
} 
