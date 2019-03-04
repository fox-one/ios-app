import UIKit

class ConversationExtensionViewController: UIViewController {
    
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var collectionViewLayout: UICollectionViewFlowLayout!
    
    var fixedExtensions = [FixedExtension]() {
        didSet {
            DispatchQueue.main.async {
                self.collectionView.reloadData()
            }
        }
    }
    var apps = [App]() {
        didSet {
            DispatchQueue.main.async {
                self.collectionView.reloadData()
            }
        }
    }
    
    private let cellReuseId = "extension"
    private let itemCountPerLine: CGFloat = 4
    
    private var availableWidth: CGFloat = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        updateCollectionViewSectionInsetIfNeeded()
        collectionView.dataSource = self
        collectionView.delegate = self
    }
    
    @available(iOS 11.0, *)
    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        updateCollectionViewSectionInsetIfNeeded()
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        let width = view.bounds.width
            - view.compatibleSafeAreaInsets.horizontal
            - collectionViewLayout.sectionInset.horizontal
        
        if availableWidth != width {
            availableWidth = width
            let spacing = width
                - itemCountPerLine * collectionViewLayout.itemSize.width
                - collectionViewLayout.sectionInset.horizontal
            collectionViewLayout.minimumInteritemSpacing = floor(spacing / (itemCountPerLine - 1))
        }
    }
    
    private func updateCollectionViewSectionInsetIfNeeded() {
        if view.compatibleSafeAreaInsets.bottom < 20 {
            collectionViewLayout.sectionInset.bottom = 20
        } else {
            collectionViewLayout.sectionInset.bottom = 0
        }
    }
    
}

extension ConversationExtensionViewController: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return fixedExtensions.count + apps.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: cellReuseId, for: indexPath) as! ConversationExtensionCell
        if indexPath.row < fixedExtensions.count {
            let ext = fixedExtensions[indexPath.row]
            cell.imageView.image = ext.image
            cell.label.text = ext.title
        } else {
            let app = apps[indexPath.row - fixedExtensions.count]
            cell.imageView.sd_setImage(with: URL(string: app.iconUrl), completed: nil)
            cell.label.text = app.name
        }
        return cell
    }
    
}

extension ConversationExtensionViewController: UICollectionViewDelegate {
    
}


extension ConversationExtensionViewController {
    
    enum FixedExtension {
        case camera
        case file
        case transfer
        case contact
        case call
        
        var image: UIImage? {
            switch self {
            case .camera:
                return R.image.conversation.ic_extension_camera()
            case .file:
                return R.image.conversation.ic_extension_file()
            case .transfer:
                return R.image.conversation.ic_extension_transfer()
            case .contact:
                return R.image.conversation.ic_extension_contact()
            case .call:
                return R.image.conversation.ic_extension_call()
            }
        }
        
        var title: String {
            switch self {
            case .camera:
                return Localized.CHAT_MENU_CAMERA
            case .file:
                return Localized.CHAT_MENU_FILE
            case .transfer:
                return Localized.CHAT_MENU_TRANSFER
            case .contact:
                return Localized.CHAT_MENU_CONTACT
            case .call:
                return Localized.CHAT_MENU_CALL
            }
        }
    }
    
}
