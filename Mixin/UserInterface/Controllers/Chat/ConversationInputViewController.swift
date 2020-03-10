import UIKit
import Photos
import MixinServices

protocol ConversationInputInteractiveResizableViewController {
    var interactiveResizableScrollView: UIScrollView { get }
}

class ConversationInputViewController: UIViewController {
    
    typealias Quote = (message: MessageItem, thumbnail: UIImage?)
    
    @IBOutlet weak var quotePreviewView: QuotePreviewView!
    @IBOutlet weak var deleteConversationButton: BusyButton!
    @IBOutlet weak var unblockButton: BusyButton!
    @IBOutlet weak var inputBarView: UIView!
    @IBOutlet weak var extensionsSwitch: ConversationExtensionSwitch!
    @IBOutlet weak var textView: ConversationInputTextView!
    @IBOutlet weak var textViewRightAccessoryView: UIView!
    @IBOutlet weak var stickersButton: UIButton!
    @IBOutlet weak var keyboardButton: UIButton!
    @IBOutlet weak var appButton: UIButton!
    @IBOutlet weak var rightActionsStackView: UIStackView!
    @IBOutlet weak var photosButton: UIButton!
    @IBOutlet weak var sendButton: UIButton!
    @IBOutlet weak var audioInputContainerView: UIView!
    @IBOutlet weak var customInputContainerView: UIView!
    
    @IBOutlet weak var quotePreviewHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var quotePreviewWrapperHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var textViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var beginEditingTextViewTrailingConstraint: NSLayoutConstraint!
    @IBOutlet weak var beginEditingRightActionsStackLeadingConstraint: NSLayoutConstraint!
    @IBOutlet weak var endEditingTextViewTrailingConstraint: NSLayoutConstraint!
    @IBOutlet weak var endEditingRightActionsStackTrailingConstraint: NSLayoutConstraint!
    @IBOutlet weak var audioInputContainerWidthConstraint: NSLayoutConstraint!
    @IBOutlet weak var customInputContainerHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var customInputContainerMinHeightConstraint: NSLayoutConstraint!
    
    lazy var extensionViewController = R.storyboard.chat.extension()!
    lazy var stickersViewController = R.storyboard.chat.stickerInput()!
    lazy var photoViewController = R.storyboard.chat.photoInput()!
    lazy var audioViewController = R.storyboard.chat.audioInput()!
    
    var detectsMentionToken = false
    
    var minimizedHeight: CGFloat {
        return quotePreviewWrapperHeightConstraint.constant
            + inputBarView.frame.height
            + view.safeAreaInsets.bottom
    }
    
    var regularHeight: CGFloat {
        return quotePreviewWrapperHeightConstraint.constant
            + inputBarView.frame.height
            + customInputHeight
    }
    
    var maximizedHeight: CGFloat {
        return UIView.layoutFittingExpandedSize.height
    }
    
    var quote: Quote? {
        didSet {
            updateQuotePreview(oldValue: oldValue)
        }
    }
    
    var isMaximizable: Bool {
        return customInputViewController is ConversationInputInteractiveResizableViewController
    }
    
    private let maxInputRow = 5
    private let interactiveDismissResponder = InteractiveDismissResponder(height: 50)
    
    private(set) var opponentApp: App?
    
    private var mentionRanges = Set<NSRange>()
    private var typingAttributes: [NSAttributedString.Key: Any] = [:]
    private var lastSelectedRange: NSRange!
    private var lastTextCountWhenMentionRangeChanges = 0
    private var lastSafeAreaInsetsBottom: CGFloat = 0
    private var reportHeightChangeWhenKeyboardFrameChanges = true
    private var customInputViewController: UIViewController? {
        didSet {
            if let old = oldValue {
                old.willMove(toParent: nil)
                old.view.removeFromSuperview()
                old.removeFromParent()
            }
            if let new = customInputViewController {
                addChild(new)
                customInputContainerView.addSubview(new.view)
                new.view.snp.makeConstraints({ (make) in
                    make.edges.equalToSuperview()
                })
                new.didMove(toParent: self)
            }
        }
    }
    
    // UIViewController's preferredContentSizeDidChange is not fired for same values being set again
    // Also we need more precisive controlling for animations so we declare a custom one
    // Do not set this var directly, use setPreferredContentHeight:animated:
    private var preferredContentHeight: CGFloat = 0
    
    // By changing selection inside textViewDidChangeSelection
    // [textView selectedRange:] triggers another delegate call immediately
    // Resolve the recursion with this flag
    private var isManipulatingSelection = false
    
    private var conversationViewController: ConversationViewController {
        return parent as! ConversationViewController
    }
    
    private var dataSource: ConversationDataSource {
        return conversationViewController.dataSource
    }
    
    private var screenHeight: CGFloat {
        return UIScreen.main.bounds.height
    }
    
    private var height: Height {
        if abs(preferredContentHeight - maximizedHeight) < 1 {
            return .maximized
        } else if abs(preferredContentHeight - minimizedHeight) < 1 {
            return .minimized
        } else {
            return .regular
        }
    }
    
    private var trimmedMessageDraft: String {
        return textView.text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private var customInputHeight: CGFloat {
        let lastKeyboardHeightIsAvailable = KeyboardHeight.last <= KeyboardHeight.maxReasonable
            && KeyboardHeight.last >= KeyboardHeight.minReasonable
        return lastKeyboardHeightIsAvailable ? KeyboardHeight.last : KeyboardHeight.default
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Life cycle
    override func viewDidLoad() {
        super.viewDidLoad()
        lastSelectedRange = textView.selectedRange
        lastTextCountWhenMentionRangeChanges = textView.text.count
        typingAttributes[.font] = textView.font
        typingAttributes[.foregroundColor] = textView.textColor
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardDidShow(_:)), name: UIResponder.keyboardDidShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillChangeFrame(_:)), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(saveDraft), name: UIApplication.willTerminateNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(participantDidChange(_:)), name: .ParticipantDidChange, object: nil)
        textView.inputAccessoryView = interactiveDismissResponder
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
        textView.delegate = self
        lastSafeAreaInsetsBottom = view.safeAreaInsets.bottom
        setPreferredContentHeight(minimizedHeight, animated: false)
        if let draft = AppGroupUserDefaults.User.conversationDraft[dataSource.conversationId], !draft.isEmpty {
            UIView.performWithoutAnimation {
                layoutForTextViewIsEmpty(false, animated: false)
                textView.text = draft
                textViewDidChange(textView)
                textView.contentOffset.y = textView.contentSize.height - textView.frame.height
            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reportHeightChangeWhenKeyboardFrameChanges = true
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        reportHeightChangeWhenKeyboardFrameChanges = false
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        saveDraft()
    }
    
    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        guard let homeContainerVC = UIApplication.homeContainerViewController, !homeContainerVC.galleryIsOnTopMost else {
            return
        }
        let diff = view.safeAreaInsets.bottom - lastSafeAreaInsetsBottom
        lastSafeAreaInsetsBottom = view.safeAreaInsets.bottom
        if abs(diff) > 1 {
            // This function call triggers recursion on iOS 12.0
            // It's fine to breaking out on the UIKit's own but for the correct height value
            // ALWAYS call it after lastSafeAreaInsetsBottom is set
            setPreferredContentHeight(preferredContentHeight + diff, animated: false)
        }
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        if height != .minimized {
            customInputContainerHeightConstraint.constant = view.frame.height
                - quotePreviewWrapperHeightConstraint.constant
                - inputBarView.frame.height
        }
    }
    
    override func preferredContentSizeDidChange(forChildContentContainer container: UIContentContainer) {
        super.preferredContentSizeDidChange(forChildContentContainer: container)
        if (container as? UIViewController) == audioViewController {
            let isExpanding = container.preferredContentSize.width > audioInputContainerWidthConstraint.constant
            audioInputContainerWidthConstraint.constant = container.preferredContentSize.width
            if isExpanding {
                UIView.animate(withDuration: 0.3) {
                    self.inputBarView.layoutIfNeeded()
                }
            } else {
                inputBarView.layoutIfNeeded()
            }
        }
    }
    
    // MARK: - Actions
    @IBAction func unblockAction(_ sender: Any) {
        guard let user = dataSource.ownerUser else {
            return
        }
        unblockButton.isBusy = true
        UserAPI.shared.unblockUser(userId: user.userId) { (result) in
            switch result {
            case .success(let userResponse):
                UserDAO.shared.updateUsers(users: [userResponse], sendNotificationAfterFinished: true)
            case let .failure(error):
                showAutoHiddenHud(style: .error, text: error.localizedDescription)
            }
        }
    }
    
    @IBAction func deleteConversationAction(_ sender: Any) {
        guard !dataSource.conversationId.isEmpty else {
            return
        }
        deleteConversationButton.isBusy = true
        let conversationId = dataSource.conversationId
        DispatchQueue.global().async { [weak self] in
            ConversationDAO.shared.makeQuitConversation(conversationId: conversationId)
            NotificationCenter.default.postOnMain(name: .ConversationDidChange)
            DispatchQueue.main.async {
                self?.navigationController?.backToHome()
            }
        }
    }
    
    @IBAction func toggleExtensionAction(_ sender: ConversationExtensionSwitch) {
        if sender.isOn {
            resignTextViewFirstResponderWithoutReportingContentHeightChange()
            if height == .maximized {
                setPreferredContentHeightAnimated(.regular)
            }
            photosButton.isSelected = false
            setRightAccessoryButton(stickersButton)
            loadCustomInputViewController(extensionViewController)
        } else {
            textView.becomeFirstResponder()
        }
    }
    
    @IBAction func showStickersAction(_ sender: Any) {
        quote = nil
        resignTextViewFirstResponderWithoutReportingContentHeightChange()
        setRightAccessoryButton(keyboardButton)
        extensionsSwitch.isOn = false
        photosButton.isSelected = false
        loadCustomInputViewController(stickersViewController)
    }
    
    @IBAction func showKeyboardAction(_ sender: Any) {
        dismissCustomInput(minimize: false)
        textView.becomeFirstResponder()
        setRightAccessoryButton(stickersButton)
    }
    
    // TODO: use view controller based web view and present it right here
    @IBAction func openOpponentAppAction(_ sender: Any) {
        guard let user = dataSource.ownerUser, user.isBot, let app = opponentApp else {
            return
        }
        dismiss()
        conversationViewController.openOpponentApp(app)
    }
    
    @IBAction func showPhotosAction(_ sender: Any) {
        let status = PHPhotoLibrary.authorizationStatus()
        handlePhotoAuthorizationStatus(status)
    }
    
    @IBAction func sendTextMessageAction(_ sender: Any) {
        textView.unmarkText()
        guard !trimmedMessageDraft.isEmpty else {
            return
        }
        dataSource.sendMessage(type: .SIGNAL_TEXT,
                               quoteMessageId: quote?.message.messageId,
                               value: trimmedMessageDraft)
        mentionRanges.removeAll()
        textView.text = ""
        textViewDidChange(textView)
        quote = nil
    }
    
    // MARK: - Interface
    func finishLoading() {
        customInputContainerMinHeightConstraint.constant = customInputHeight
        
        addChild(audioViewController)
        audioInputContainerView.addSubview(audioViewController.view)
        audioViewController.view.snp.makeConstraints({ (make) in
            make.edges.equalToSuperview()
        })
        audioViewController.didMove(toParent: self)
        
        stickersViewController.loadViewIfNeeded()
        stickersViewController.reload()
        
        extensionViewController.loadViewIfNeeded()
        if dataSource.category == .group {
            let conversationId = dataSource.conversationId
            dataSource.queue.async {
                let apps = AppDAO.shared.getConversationBots(conversationId: conversationId)
                DispatchQueue.main.async { [weak self] in
                    self?.extensionViewController.apps = apps.map { ($0, nil) }
                    self?.reloadFixedExtensions()
                }
            }
        } else if let ownerUser = dataSource.ownerUser {
            dataSource.queue.async { [weak self] in
                let app = AppDAO.shared.getApp(ofUserId: ownerUser.userId)
                DispatchQueue.main.async {
                    if let app = app {
                        self?.opponentApp = app
                        AppGroupUserDefaults.User.insertRecentlyUsedAppId(id: app.appId)
                    } else {
                        self?.loadFavoriteApps(ownerUser: ownerUser)
                    }
                    self?.reloadFixedExtensions()
                }
            }
        }
        
        quotePreviewView.dismissAction = { [weak self] in
            self?.quote = nil
        }
        
        let recognizer = InteractiveResizeGestureRecognizer(target: self, action: #selector(interactiveResizeAction(_:)))
        recognizer.delegate = self
        view.addGestureRecognizer(recognizer)
    }
    
    func update(opponentUser user: UserItem) {
        let isBlocked = user.relationship == Relationship.BLOCKING.rawValue
        unblockButton.isHidden = !isBlocked
        if !isBlocked && unblockButton.isBusy {
            unblockButton.isBusy = false
        }
        appButton.isHidden = !user.isBot
        DispatchQueue.global().async { [weak self] in
            let app = AppDAO.shared.getApp(ofUserId: user.userId)
            DispatchQueue.main.sync {
                self?.opponentApp = app
            }
        }
    }
    
    func dismissCustomInput(minimize: Bool) {
        setRightAccessoryButton(stickersButton)
        photosButton.isSelected = false
        extensionsSwitch.isOn = false
        if minimize {
            setPreferredContentHeightAnimated(.minimized)
        }
        UIView.animate(withDuration: 0.5, animations: {
            UIView.setAnimationCurve(.overdamped)
            self.customInputContainerView.alpha = 0
        }) { (_) in
            self.customInputViewController = nil
        }
    }
    
    func setPreferredContentHeightAnimated(_ height: Height) {
        let heightValue: CGFloat
        switch height {
        case .minimized:
            heightValue = minimizedHeight
        case .regular:
            heightValue = regularHeight
        case .maximized:
            heightValue = maximizedHeight
        }
        setPreferredContentHeight(heightValue, animated: true)
    }
    
    func dismiss() {
        if textView.isFirstResponder {
            textView.resignFirstResponder()
        } else if height != .minimized {
            dismissCustomInput(minimize: true)
        }
    }
    
    func send(asset: PHAsset) {
        dataSource.send(asset: asset, quoteMessageId: quote?.message.messageId)
        quote = nil
    }
    
    func sendAudio(url: URL, metadata: MXNAudioMetadata) {
        dataSource.sendMessage(type: .SIGNAL_AUDIO, quoteMessageId: quote?.message.messageId, value: (url, metadata))
        quote = nil
    }
    
    func sendFile(url: URL) {
        dataSource.sendMessage(type: .SIGNAL_DATA, quoteMessageId: quote?.message.messageId, value: url)
        quote = nil
    }
    
    func sendContact(userIds: [String], completion: @escaping () -> Void) {
        let conversationId = dataSource.conversationId
        let ownerUser = dataSource.ownerUser
        let isGroup = dataSource.conversation.isGroup()
        var quoteMessageId = quote?.message.messageId
        quote = nil
        DispatchQueue.global().async {
            for userId in userIds {
                var message = Message.createMessage(category: MessageCategory.SIGNAL_CONTACT.rawValue,
                                                    conversationId: conversationId,
                                                    userId: myUserId)
                message.sharedUserId = userId
                if let id = quoteMessageId {
                    // Apply quoted message to first message only
                    message.quoteMessageId = id
                    quoteMessageId = nil
                }
                let transferData = TransferContactData(userId: userId)
                message.content = try! JSONEncoder().encode(transferData).base64EncodedString()
                SendMessageService.shared.sendMessage(message: message,
                                                      ownerUser: ownerUser,
                                                      isGroupMessage: isGroup)
            }
            DispatchQueue.main.async(execute: completion)
        }
    }
    
}

// MARK: - Callbacks
extension ConversationInputViewController {
    
    @objc private func keyboardDidShow(_ notification: Notification) {
        guard textView.isFirstResponder else {
            return
        }
        view.backgroundColor = .clear
    }
    
    @objc private func keyboardWillChangeFrame(_ notification: Notification) {
        guard let endFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else {
            return
        }
        let keyboardWillBeInvisible = (screenHeight - endFrame.origin.y) <= 1
        guard textView.isFirstResponder || (keyboardWillBeInvisible && customInputViewController == nil) || (presentedViewController?.isBeingDismissed ?? false) else {
            return
        }
        if !keyboardWillBeInvisible {
            KeyboardHeight.last = endFrame.height - interactiveDismissResponder.height
            customInputContainerMinHeightConstraint.constant = customInputHeight
        }
        guard reportHeightChangeWhenKeyboardFrameChanges else {
            return
        }
        if keyboardWillBeInvisible {
            setPreferredContentHeight(minimizedHeight, animated: false)
        } else {
            var height = quotePreviewWrapperHeightConstraint.constant
                + inputBarView.frame.height
                + screenHeight
                - endFrame.origin.y
                - interactiveDismissResponder.height
            height = max(minimizedHeight, height)
            if view.frame.height != height {
                setPreferredContentHeight(height, animated: false)
            }
        }
    }
    
    @objc private func keyboardWillHide(_ notification: Notification) {
        UIView.performWithoutAnimation {
            self.view.backgroundColor = .background
        }
    }
    
    @objc private func saveDraft() {
        guard parent != nil else {
            return
        }
        AppGroupUserDefaults.User.conversationDraft[dataSource.conversationId] = trimmedMessageDraft
    }
    
    @objc private func participantDidChange(_ notification: Notification) {
        guard parent != nil else {
            return
        }
        guard dataSource.category == .group else {
            return
        }
        guard let conversationId = notification.object as? String, conversationId == dataSource.conversationId else {
            return
        }
        DispatchQueue.global().async { [weak self] in
            let apps = AppDAO.shared.getConversationBots(conversationId: conversationId)
            DispatchQueue.main.sync {
                self?.extensionViewController.apps = apps.map { ($0, nil) }
            }
        }
    }
    
    @objc private func interactiveResizeAction(_ recognizer: InteractiveResizeGestureRecognizer) {
        let location = recognizer.location(in: view)
        let verticalVelocity = recognizer.velocity(in: view).y
        let resizableScrollView = (customInputViewController as? ConversationInputInteractiveResizableViewController)?.interactiveResizableScrollView
        switch recognizer.state {
        case .began:
            recognizer.beganInInputBar = inputBarView.frame.contains(location)
            let downsizeByDraggingOnScrollView = view.frame.height > regularHeight
                && verticalVelocity > 0
                && (resizableScrollView != nil)
                && (resizableScrollView!.contentOffset.y < 1)
                && resizableScrollView!.bounds.contains(recognizer.location(in: resizableScrollView))
            if recognizer.beganInInputBar || downsizeByDraggingOnScrollView {
                recognizer.shouldAdjustContentHeight = true
            }
            recognizer.canSizeToMinimized = view.frame.height <= regularHeight
            recognizer.setTranslation(.zero, in: view)
        case .changed:
            if !recognizer.shouldAdjustContentHeight {
                let canUpsize = preferredContentHeight < maximizedHeight
                    && inputBarView.frame.contains(location)
                if canUpsize {
                    recognizer.shouldAdjustContentHeight = true
                }
            }
            if recognizer.shouldAdjustContentHeight {
                var translation = recognizer.translation(in: view).y
                if !recognizer.beganInInputBar, let scrollView = resizableScrollView {
                    scrollView.contentOffset.y += translation
                }
                if !recognizer.canSizeToMinimized && (view.frame.height - translation) < regularHeight {
                    translation /= 2
                }
                let height = view.frame.height - translation
                setPreferredContentHeight(height, animated: false)
            }
            recognizer.setTranslation(.zero, in: view)
        case .ended:
            if recognizer.shouldAdjustContentHeight {
                if verticalVelocity > 50 {
                    if view.frame.height < regularHeight && recognizer.canSizeToMinimized {
                        dismissCustomInput(minimize: true)
                    } else {
                        setPreferredContentHeightAnimated(.regular)
                    }
                } else {
                    if view.frame.height > regularHeight {
                        setPreferredContentHeightAnimated(.maximized)
                    } else {
                        setPreferredContentHeightAnimated(.regular)
                    }
                }
            }
        default:
            break
        }
    }
    
}

// MARK: - Embedded class
extension ConversationInputViewController {
    
    enum Height {
        case minimized
        case regular
        case maximized
    }
    
    private class InteractiveResizeGestureRecognizer: UIPanGestureRecognizer {
        
        var beganInInputBar = false
        var shouldAdjustContentHeight = false
        var canSizeToMinimized = false
        
        override func reset() {
            super.reset()
            shouldAdjustContentHeight = false
            canSizeToMinimized = false
        }
        
    }
    
}

// MARK: - UIGestureRecognizerDelegate
extension ConversationInputViewController: UIGestureRecognizerDelegate {
    
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return isMaximizable
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return otherGestureRecognizer is UIScreenEdgePanGestureRecognizer
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // Avoid conflicting with audio recording
        return !(otherGestureRecognizer is UILongPressGestureRecognizer)
    }
    
}

// MARK: - UITextViewDelegate
extension ConversationInputViewController: UITextViewDelegate {
    
    func textViewShouldBeginEditing(_ textView: UITextView) -> Bool {
        dismissCustomInput(minimize: false)
        return true
    }
    
    func textViewShouldEndEditing(_ textView: UITextView) -> Bool {
        view.backgroundColor = .background
        return true
    }
    
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        return !audioViewController.isRecording
    }
    
    func textViewDidChange(_ textView: UITextView) {
        let fullRange = NSRange(location: 0, length: textView.attributedText.length)
        var rangeToRemove: NSRange?
        mentionRanges.removeAll()
        textView.attributedText.enumerateAttribute(.mentionLength, in: fullRange, options: [], using: { (value, range, stop) in
            guard let length = value as? Int else {
                return
            }
            if length == range.length {
                mentionRanges.insert(range)
            } else {
                rangeToRemove = range
                stop.pointee = true
            }
        })
        
        if let range = rangeToRemove {
            DispatchQueue.main.async {
                textView.text = (textView.text as NSString).replacingCharacters(in: range, with: "")
                self.textViewDidChange(textView)
            }
            return
        }
        
        lastTextCountWhenMentionRangeChanges = textView.text.count
        
        guard let lineHeight = textView.font?.lineHeight else {
            return
        }
        if sendButton.alpha == 0 && !textView.text.isEmpty {
            layoutForTextViewIsEmpty(false, animated: true)
        } else if sendButton.alpha == 1 && textView.text.isEmpty {
            layoutForTextViewIsEmpty(true, animated: true)
        }
        let maxHeight = ceil(lineHeight * CGFloat(maxInputRow)
            + textView.textContainerInset.top
            + textView.textContainerInset.bottom)
        let sizeToFit = CGSize(width: textView.bounds.width,
                               height: UIView.layoutFittingExpandedSize.height)
        let contentHeight = ceil(textView.sizeThatFits(sizeToFit).height)
        textView.isScrollEnabled = contentHeight > maxHeight
        let newHeight = min(contentHeight, maxHeight)
        let diff = newHeight - textViewHeightConstraint.constant
        if abs(diff) > 0.1 {
            textViewHeightConstraint.constant = newHeight
            setPreferredContentHeight(preferredContentHeight + diff, animated: true)
            interactiveDismissResponder.height += diff
        }
        
        if detectsMentionToken {
            if let range = self.textView.inputingMentionTokenRange, !mentionRanges.contains(where: { $0.intersection(range) != nil }) {
                let text = (self.textView.text as NSString).substring(with: range)
                conversationViewController.inputTextViewDidInputMentionCandidate(text)
            } else {
                conversationViewController.inputTextViewDidInputMentionCandidate(nil)
            }
        }
    }
    
    func textViewDidChangeSelection(_ textView: UITextView) {
        guard !isManipulatingSelection else {
            return
        }
        isManipulatingSelection = true
        defer {
            isManipulatingSelection = false
        }
        
        var selectedRange = textView.selectedRange
        if selectedRange.length == 0 {
            let mentionRangeWithCaretInside = mentionRanges.first { (range) -> Bool in
                selectedRange.location > range.location && selectedRange.location < NSMaxRange(range)
            }
            if textView.text.count == lastTextCountWhenMentionRangeChanges, let range = mentionRangeWithCaretInside {
                let isCaretGoingBackwards = selectedRange.location < lastSelectedRange.location
                let location = isCaretGoingBackwards ? range.location : NSMaxRange(range)
                textView.selectedRange = NSRange(location: location, length: 0)
            }
        } else {
            for mentionRange in mentionRanges {
                if mentionRange.intersection(selectedRange) != nil {
                    selectedRange.formUnion(mentionRange)
                }
            }
            textView.selectedRange = selectedRange
        }
        lastSelectedRange = textView.selectedRange
        textView.typingAttributes = typingAttributes
    }
    
}

// MARK: - Private works
extension ConversationInputViewController {
    
    private func setPreferredContentHeight(_ height: CGFloat, animated: Bool) {
        preferredContentHeight = height
        conversationViewController.updateInputWrapper(for: height, animated: animated)
    }
    
    private func resignTextViewFirstResponderWithoutReportingContentHeightChange() {
        guard textView.isFirstResponder else {
            return
        }
        reportHeightChangeWhenKeyboardFrameChanges = false
        textView.resignFirstResponder()
        reportHeightChangeWhenKeyboardFrameChanges = true
    }
    
    private func reloadFixedExtensions() {
        if dataSource.category == .contact, let ownerUser = dataSource.ownerUser, !ownerUser.isBot {
            extensionViewController.fixedExtensions = [.transfer, .call, .camera, .file, .contact]
        } else if let app = opponentApp, app.creatorId == myUserId {
            extensionViewController.fixedExtensions = [.transfer, .camera, .file, .contact]
        } else {
            extensionViewController.fixedExtensions = [.camera, .file, .contact]
        }
    }
    
    private func loadCustomInputViewController(_ viewController: UIViewController) {
        if view.frame.height < regularHeight {
            setPreferredContentHeightAnimated(.regular)
        }
        customInputContainerView.alpha = 0
        customInputViewController = viewController
        customInputContainerView.layoutIfNeeded()
        UIView.animate(withDuration: 0.5) {
            UIView.setAnimationCurve(.overdamped)
            self.customInputContainerView.alpha = 1
        }
    }
    
    private func loadFavoriteApps(ownerUser: UserItem) {
        guard let account = LoginManager.shared.account else {
            return
        }
        
        let myUserItem = UserItem.createUser(from: account)
        let ownerId = ownerUser.userId
        
        func loadApps() {
            let myFavoriteApps = FavoriteAppsDAO.shared.favoriteAppsOfUser(withId: myUserId)
            let myFavoriteAppIds = Set(myFavoriteApps.map({ $0.appId }))
            let ownerFavoriteApps = FavoriteAppsDAO.shared.favoriteAppsOfUser(withId: ownerUser.userId)
                .filter({ !myFavoriteAppIds.contains($0.appId) })
            let apps: [(app: App, user: UserItem?)] = myFavoriteApps.map({ ($0, myUserItem) }) + ownerFavoriteApps.map({ ($0, ownerUser) })
            DispatchQueue.main.async { [weak self] in
                self?.extensionViewController.apps = apps
            }
        }
        
        DispatchQueue.global().async(execute: loadApps)
        UserAPI.shared.getFavoriteApps(ofUserWith: ownerId) { (result) in
            guard case let .success(favApps) = result else {
                return
            }
            DispatchQueue.global().async {
                FavoriteAppsDAO.shared.updateFavoriteApps(favApps, forUserWith: ownerId)
                let appUserIds = favApps.map({ $0.appId })
                UserAPI.shared.showUsers(userIds: appUserIds) { (result) in
                    guard case let .success(users) = result else {
                        return
                    }
                    UserDAO.shared.updateUsers(users: users)
                    DispatchQueue.global().asyncAfter(deadline: .now() + 1, execute: loadApps)
                }
            }
        }
    }
    
    // The param of button should be either keyboardButton or stickersButton
    private func setRightAccessoryButton(_ button: UIButton) {
        guard button.alpha == 0 else {
            return
        }
        
        func switchButton(from: UIButton, to: UIButton) {
            let t = CGAffineTransform(scaleX: 0.6, y: 0.6)
            to.transform = t
            to.alpha = 0
            let duration = 0.2
            let options: UIView.AnimationOptions = [
                .overrideInheritedDuration,
                .overrideInheritedOptions,
                .overrideInheritedCurve
            ]
            UIView.animate(withDuration: duration, delay: 0, options: options, animations: {
                from.alpha = 0
                to.alpha = 1
            }, completion: nil)
            UIView.animate(withDuration: duration / 2, delay: 0, options: options, animations: {
                from.transform = t
            }, completion: nil)
            UIView.animate(withDuration: duration / 2, delay: duration / 2, options: options, animations: {
                to.transform = .identity
            }) { (_) in
                from.transform = .identity
            }
        }
        
        if button == stickersButton {
            switchButton(from: keyboardButton, to: stickersButton)
        } else {
            switchButton(from: stickersButton, to: keyboardButton)
        }
    }
    
    private func layoutForTextViewIsEmpty(_ isEmpty: Bool, animated: Bool) {
        if animated {
            UIView.beginAnimations(nil, context: nil)
            UIView.setAnimationDuration(0.2)
        }
        if isEmpty {
            beginEditingTextViewTrailingConstraint.priority = .almostInexist
            beginEditingRightActionsStackLeadingConstraint.priority = .almostInexist
            endEditingTextViewTrailingConstraint.priority = .almostRequired
            endEditingRightActionsStackTrailingConstraint.priority = .almostRequired
            sendButton.alpha = 0
            rightActionsStackView.alpha = 1
            audioInputContainerView.alpha = 1
            textViewRightAccessoryView.alpha = 1
        } else {
            beginEditingTextViewTrailingConstraint.priority = .almostRequired
            beginEditingRightActionsStackLeadingConstraint.priority = .almostRequired
            endEditingTextViewTrailingConstraint.priority = .almostInexist
            endEditingRightActionsStackTrailingConstraint.priority = .almostInexist
            sendButton.alpha = 1
            rightActionsStackView.alpha = 0
            audioInputContainerView.alpha = 0
            textViewRightAccessoryView.alpha = 0
        }
        inputBarView.layoutIfNeeded()
        if animated {
            UIView.commitAnimations()
        }
    }
    
    private func updateQuotePreview(oldValue: Quote?) {
        let quotePreviewHeight = quotePreviewHeightConstraint.constant
        if let quote = quote {
            audioViewController.cancelIfRecording()
            UIView.performWithoutAnimation {
                quotePreviewView.render(message: quote.message, contentImageThumbnail: quote.thumbnail)
                quotePreviewView.layoutIfNeeded()
            }
            if oldValue == nil {
                quotePreviewView.alpha = 1
                quotePreviewWrapperHeightConstraint.constant = quotePreviewHeight
                interactiveDismissResponder.height += quotePreviewHeight
            }
            if textView.isFirstResponder || customInputViewController != nil {
                if oldValue == nil {
                    setPreferredContentHeight(preferredContentHeight + quotePreviewHeight, animated: true)
                }
            } else if customInputViewController == nil {
                textView.becomeFirstResponder()
            }
        } else if oldValue != nil {
            quotePreviewView.alpha = 0
            interactiveDismissResponder.height -= quotePreviewHeight
            let newHeight = preferredContentHeight - quotePreviewHeight
            quotePreviewWrapperHeightConstraint.constant = 0
            setPreferredContentHeight(newHeight, animated: true)
        }
    }
    
    private func loadPhotoInput() {
        resignTextViewFirstResponderWithoutReportingContentHeightChange()
        photosButton.isSelected.toggle()
        extensionsSwitch.isOn = false
        setRightAccessoryButton(stickersButton)
        if photosButton.isSelected {
            loadCustomInputViewController(photoViewController)
        } else {
            dismissCustomInput(minimize: true)
        }
    }
    
    private func handlePhotoAuthorizationStatus(_ status: PHAuthorizationStatus) {
        switch status {
        case .authorized:
            performSynchronouslyOnMainThread(loadPhotoInput)
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(handlePhotoAuthorizationStatus)
        case .denied, .restricted:
            DispatchQueue.main.async {
                self.alertSettings(Localized.PERMISSION_DENIED_PHOTO_LIBRARY)
            }
        @unknown default:
            DispatchQueue.main.async {
                self.alertSettings(Localized.PERMISSION_DENIED_PHOTO_LIBRARY)
            }
        }
    }
    
}
