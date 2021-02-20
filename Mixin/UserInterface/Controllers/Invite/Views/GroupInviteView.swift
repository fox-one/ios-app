import UIKit

enum UIFactory {
    static func getLabelWithFontSize(_ fontSize: CGFloat,
                                     fontWeight: UIFont.Weight,
                                     textAlignment: NSTextAlignment,
                                     textColor: UIColor,
                                     lines: Int = 1) -> UILabel {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: fontSize, weight: fontWeight)
        label.textAlignment = textAlignment
        label.textColor = textColor
        label.numberOfLines = lines
        return label
    }
    
    static func getBtnWithBgColor(_ bgColor: UIColor,
                                 textColor: UIColor,
                                 text: String,
                                 selectedText: String? = nil,
                                 textFont: UIFont,
                                 roundRadius: CGFloat,
                                 borderColor: UIColor? = nil,
                                 borderWidth: CGFloat = 0) -> UIButton {
        let btn = UIButton(type: .custom)
        btn.titleLabel?.font = textFont
        btn.setTitle(text, for: .normal)
        btn.setTitleColor(textColor, for: .normal)
        
        btn.backgroundColor = bgColor
        btn.layer.cornerRadius = roundRadius
        btn.layer.masksToBounds = true
        
        if let st = selectedText {
            btn.setTitle(st, for: .selected)
            btn.setTitleColor(.white, for: .selected)
        }
        if let br = borderColor {
            btn.layer.borderColor = br.cgColor
            btn.layer.borderWidth = borderWidth
        }
        return btn
    }
}

protocol GroupInviteViewDelegate: class {
    func inviteViewDidClickJoinBtn()
    func inviteViewDidClickIgnoreBtn()
}

class GroupInviteView: UIView {
    weak var delegate: GroupInviteViewDelegate?
    
    private var topInviteView: UIView!
    private var topShapeView: UIImageView!
    private var inviterAvatarView: UIImageView!
    private var inviterNameLabel: UILabel!
    private var inviterCodeLabel: UILabel!
    
    private var inviteMsgLabel: UILabel!
    private var groupAvatarView: UIImageView!
    private var groupNameLabel: UILabel!
    private var groupIntroLabel: UILabel!
    private var groupPersonNumberLabel: UILabel!
    
    private var joinBtn: UIButton!
    private var ignoreBtn: UIButton!
    
    func config(item: GroupInviteItem) {
        inviterAvatarView.sd_setImage(with: URL(string: item.avatarUrl))
        inviterNameLabel.text = item.inviterName
        inviterCodeLabel.text = "\(item.inviterId)"
        
        groupAvatarView.sd_setImage(with: URL(string: item.groupIcon))
        groupNameLabel.text = item.groupName
        groupIntroLabel.text = item.groupDesc
        groupPersonNumberLabel.text = "\(item.membersCount)人已入群"
    }
    
    func setupInviteView() {
        topInviteView = UIView()
        addSubview(topInviteView)
        
        topShapeView = UIImageView()
        topShapeView.image = UIImage(named: "bg_group_invite_top")
        topShapeView.contentMode = .scaleAspectFit
        topInviteView.addSubview(topShapeView)
        
        inviterAvatarView = UIImageView()
        inviterAvatarView.layer.cornerRadius = 31
        inviterAvatarView.layer.masksToBounds = true
        inviterAvatarView.layer.borderColor = UIColor.white.cgColor
        inviterAvatarView.layer.borderWidth = 2.0
        inviterAvatarView.contentMode = .scaleAspectFill
        topInviteView.addSubview(inviterAvatarView)
        
        inviterNameLabel = UIFactory.getLabelWithFontSize(18, fontWeight: .medium,
                                                          textAlignment: .center, textColor: UIColor(rgbValue: 0xF6F6F6))
        topInviteView.addSubview(inviterNameLabel)
        
        let codeTextColor = UIColor(rgbValue: 0xEBF0F5).withAlphaComponent(0.6)
        inviterCodeLabel = UIFactory.getLabelWithFontSize(14, fontWeight: .regular,
                                                          textAlignment: .center, textColor: codeTextColor)
        topInviteView.addSubview(inviterCodeLabel)
        
        topInviteView.snp.makeConstraints {
            $0.top.leading.trailing.equalToSuperview()
            $0.height.equalTo(157)
        }
        topShapeView.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
        inviterAvatarView.snp.makeConstraints {
            $0.top.equalToSuperview().offset(21)
            $0.centerX.equalToSuperview()
            $0.width.height.equalTo(62)
        }
        inviterNameLabel.snp.makeConstraints {
            $0.top.equalTo(inviterAvatarView.snp.bottom).offset(6)
            $0.leading.trailing.equalToSuperview()
        }
        inviterCodeLabel.snp.makeConstraints {
            $0.top.equalTo(inviterNameLabel.snp.bottom).offset(5)
            $0.leading.trailing.equalToSuperview()
        }
    }
    
    func setupGroupView() {
        inviteMsgLabel = UIFactory.getLabelWithFontSize(20, fontWeight: .medium,
                                                        textAlignment: .center, textColor: .black)
        inviteMsgLabel.text = "邀请你加入"
        addSubview(inviteMsgLabel)
        
        groupAvatarView = UIImageView()
        groupAvatarView.layer.cornerRadius = 32
        groupAvatarView.layer.masksToBounds = true
        groupAvatarView.contentMode = .scaleAspectFill
        addSubview(groupAvatarView)
        
        groupNameLabel = UIFactory.getLabelWithFontSize(16, fontWeight: .medium,
                                                        textAlignment: .center, textColor: .black)
        addSubview(groupNameLabel)
        
        let grayTextColor = UIColor(rgbValue: 0x34393E).withAlphaComponent(0.6)
        groupIntroLabel = UIFactory.getLabelWithFontSize(14, fontWeight: .regular,
                                                         textAlignment: .center, textColor: grayTextColor)
        addSubview(groupIntroLabel)
        
        groupPersonNumberLabel = UIFactory.getLabelWithFontSize(13, fontWeight: .regular,
                                                                textAlignment: .center, textColor: grayTextColor)
        addSubview(groupPersonNumberLabel)
        
        inviteMsgLabel.snp.makeConstraints {
            $0.top.equalTo(topInviteView.snp.bottom).offset(20)
            $0.leading.trailing.equalToSuperview()
        }
        groupAvatarView.snp.makeConstraints {
            $0.top.equalTo(inviteMsgLabel.snp.bottom).offset(20)
            $0.centerX.equalToSuperview()
            $0.size.equalTo(CGSize(width: 64, height: 64))
        }
        groupNameLabel.snp.makeConstraints {
            $0.top.equalTo(groupAvatarView.snp.bottom).offset(10)
            $0.leading.trailing.equalToSuperview().inset(47)
        }
        groupIntroLabel.snp.makeConstraints {
            $0.top.equalTo(groupNameLabel.snp.bottom).offset(26)
            $0.leading.trailing.equalToSuperview().inset(30)
        }
        groupPersonNumberLabel.snp.makeConstraints {
            $0.top.equalTo(groupIntroLabel.snp.bottom).offset(10)
            $0.leading.trailing.equalToSuperview()
        }
    }
    
    func setupBottomBtn() {
        let btnTextFont = UIFont.systemFont(ofSize: 16, weight: .semibold)
        joinBtn = UIFactory.getBtnWithBgColor(.black,
                                              textColor: .white,
                                              text: "立刻加入",
                                              textFont: btnTextFont,
                                              roundRadius: 24)
        joinBtn.addTarget(self, action: #selector(didClickJoinBtn), for: .touchUpInside)
        addSubview(joinBtn)
        
        let ignoreBtnBorderColor = UIColor(rgbValue: 0xC6C7C8).withAlphaComponent(0.38)
        ignoreBtn = UIFactory.getBtnWithBgColor(.white,
                                                textColor: .black,
                                                text: "忽略对方的邀请",
                                                textFont: btnTextFont,
                                                roundRadius: 24,
                                                borderColor: ignoreBtnBorderColor,
                                                borderWidth: 1)
        ignoreBtn.addTarget(self, action: #selector(didClickIgnoreBtn), for: .touchUpInside)
        addSubview(ignoreBtn)
        
        let btnSize = CGSize(width: 286, height: 48)
        ignoreBtn.snp.makeConstraints {
            $0.bottom.equalToSuperview().inset(40)
            $0.centerX.equalToSuperview()
            $0.size.equalTo(btnSize)
        }
        joinBtn.snp.makeConstraints {
            $0.bottom.equalTo(ignoreBtn.snp.top).offset(-13)
            $0.centerX.equalToSuperview()
            $0.size.equalTo(btnSize)
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        setupInviteView()
        setupGroupView()
        setupBottomBtn()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        
        setupInviteView()
        setupGroupView()
        setupBottomBtn()
    }
    
    // MARK: Event Method
    @objc func didClickJoinBtn() {
        delegate?.inviteViewDidClickJoinBtn()
    }
    
    @objc func didClickIgnoreBtn() {
        delegate?.inviteViewDidClickIgnoreBtn()
    }
}
