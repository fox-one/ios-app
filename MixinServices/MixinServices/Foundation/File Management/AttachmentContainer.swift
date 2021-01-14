import Foundation

public enum AttachmentContainer {
    
    public static var url: URL {
        let url = AppGroupContainer.accountUrl.appendingPathComponent("Chat", isDirectory: true)
        try? FileManager.default.createDirectoryIfNotExists(atPath: url.path)
        return url
    }
    
    public static func url(for category: Category, filename: String?) -> URL {
        let url = Self.url.appendingPathComponent(category.pathComponent)
        try? FileManager.default.createDirectoryIfNotExists(atPath: url.path)
        if let filename = filename {
            assert(!filename.isEmpty)
            return url.appendingPathComponent(filename)
        } else {
            return url
        }
    }
    
    public static func removeMediaFiles(mediaUrl: String, category: String) {
        guard let messageCategory = AttachmentContainer.Category(messageCategory: category) else {
            return
        }
        guard !mediaUrl.isEmpty else {
            return
        }
        let url = AttachmentContainer.url(for: messageCategory, filename: mediaUrl)
        try? FileManager.default.removeItem(at: url)
        if category.hasSuffix("_VIDEO") {
            let thumbFilename = mediaUrl.substring(endChar: ".") + ExtensionName.jpeg.withDot
            let thumbUrl = AttachmentContainer.url(for: .videos, filename: thumbFilename)
            try? FileManager.default.removeItem(at: thumbUrl)
        }
    }
    
}

public extension AttachmentContainer {
    
    enum Category {
        
        case audios
        case files
        case photos
        case videos
        
        public var pathComponent: String {
            switch self {
            case .audios:
                return "Audios"
            case .files:
                return "Files"
            case .photos:
                return "Photos"
            case .videos:
                return "Videos"
            }
        }
        
        public var messageCategorySuffix: String {
            switch self {
            case .photos:
                return "_IMAGE"
            case .files:
                return "_DATA"
            case .videos:
                return "_VIDEO"
            case .audios:
                return "_AUDIO"
            }
        }
        
        public var messageCategory: [MessageCategory] {
            switch self {
            case .photos:
                return [.SIGNAL_IMAGE, .PLAIN_IMAGE, .ENCRYPTED_IMAGE]
            case .files:
                return [.SIGNAL_DATA, .PLAIN_DATA, .ENCRYPTED_DATA]
            case .videos:
                return [.SIGNAL_VIDEO, .PLAIN_VIDEO, .ENCRYPTED_VIDEO]
            case .audios:
                return [.SIGNAL_AUDIO, .PLAIN_AUDIO, .ENCRYPTED_AUDIO]
            }
        }
        
        public init?(messageCategory: String) {
            if messageCategory.hasSuffix("_IMAGE") {
                self = .photos
            } else if messageCategory.hasSuffix("_DATA") {
                self = .files
            } else if messageCategory.hasSuffix("_AUDIO") {
                self = .audios
            } else if messageCategory.hasSuffix("_VIDEO") {
                self = .videos
            } else {
                return nil
            }
        }
        
    }
    
}
