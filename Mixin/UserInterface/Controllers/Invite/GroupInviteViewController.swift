import UIKit
import Alamofire

class GroupInviteViewController: UIViewController {
    private var inviteContainerView: UIView!
    private var inviteView: GroupInviteView!
    private var inviteItem: GroupInviteItem!
    
    init(inviteItem: GroupInviteItem) {
        self.inviteItem = inviteItem
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setupInviteView() {
        inviteContainerView = UIView()
        inviteContainerView.layer.applySketchShadow(color: .black, alpha: 0.05, x: 0, y: 2, blur: 16, spread: 0)
        view.addSubview(inviteContainerView)
        
        inviteView = GroupInviteView()
        inviteView.delegate = self
        inviteView.backgroundColor = .white
        inviteView.layer.cornerRadius = 12
        inviteContainerView.addSubview(inviteView)
        
        inviteContainerView.snp.makeConstraints {
            $0.centerY.equalToSuperview()
            $0.leading.trailing.equalToSuperview().inset(33)
            $0.height.equalTo(587)
        }
        inviteView.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .white
        setupInviteView()
        inviteView.config(item: inviteItem)
    }
}

extension GroupInviteViewController: GroupInviteViewDelegate {
    func inviteViewDidClickJoinBtn() {
        dismiss(animated: true, completion: nil)
        UIApplication.shared.openURL(url: "mixin://apps/\(inviteItem.groupAppId)/")
    }
    
    func inviteViewDidClickIgnoreBtn() {
        dismiss(animated: true, completion: nil)
    }
}
