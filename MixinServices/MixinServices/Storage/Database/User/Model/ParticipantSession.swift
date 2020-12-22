import Foundation
import GRDB

public enum SenderKeyStatus: Int {
    case UNKNOWN = 0
    case SENT = 1
}

public struct ParticipantSession {
    
    public let conversationId: String
    public let userId: String
    public let sessionId: String
    public let sentToServer: Int?
    public let createdAt: String
    
    public init(conversationId: String, userId: String, sessionId: String, sentToServer: Int?, createdAt: String) {
        self.conversationId = conversationId
        self.userId = userId
        self.sessionId = sessionId
        self.sentToServer = sentToServer
        self.createdAt = createdAt
    }
    
}

extension ParticipantSession: Codable, DatabaseColumnConvertible, MixinFetchableRecord, MixinEncodableRecord {

    public enum CodingKeys: String, CodingKey {
        case conversationId = "conversation_id"
        case userId = "user_id"
        case sessionId = "session_id"
        case sentToServer = "sent_to_server"
        case createdAt = "created_at"
    }
    
}

extension ParticipantSession: TableRecord, PersistableRecord {
    
    public static let databaseTableName = "participant_session"
    
}

extension ParticipantSession {
    
    public var uniqueIdentifier: String {
        return "\(userId)\(sessionId)"
    }
    
}