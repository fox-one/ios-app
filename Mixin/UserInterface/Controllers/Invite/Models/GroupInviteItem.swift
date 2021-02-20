import Foundation

struct GroupInviteItem {
    let groupName: String
    let groupId: String
    let groupAppId: String
    let groupDesc: String
    let groupIcon: String
    let inviterName: String
    let inviterId: Int
    let membersCount: Int
    let avatarUrl: String
    let invitationCode: String
}

extension GroupInviteItem: Codable {
    public enum CodingKeys: String, CodingKey {
        case groupName = "group_name"
        case groupId = "group_id"
        case groupAppId = "group_app_id"
        case groupDesc = "group_desc"
        case groupIcon = "group_icon"
        case inviterName = "inviter_name"
        case inviterId = "inviter_id"
        case membersCount = "members_count"
        case avatarUrl = "avatar_url"
        case invitationCode = "invitation_code"
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        groupName = try container.decode(String.self, forKey: .groupName)
        groupId = try container.decode(String.self, forKey: .groupId)
        groupDesc = try container.decode(String.self, forKey: .groupDesc)
        inviterName = try container.decode(String.self, forKey: .inviterName)
        inviterId = try container.decode(Int.self, forKey: .inviterId)
        membersCount = try container.decode(Int.self, forKey: .membersCount)
        avatarUrl = try container.decode(String.self, forKey: .avatarUrl)
        invitationCode = try container.decode(String.self, forKey: .invitationCode)
        groupAppId = try container.decode(String.self, forKey: .groupAppId)
        groupIcon = try container.decode(String.self, forKey: .groupIcon)
    }
}
