import Foundation
import MixinServices

extension SendMessageService {
    
    func sendMessage(message: Message, ownerUser: UserItem?, isGroupMessage: Bool) {
        guard let account = LoginManager.shared.account else {
            return
        }

        var msg = message
        msg.userId = account.user_id
        msg.status = MessageStatus.SENDING.rawValue

        var isSignalMessage = isGroupMessage
        if !isGroupMessage {
            isSignalMessage = !(ownerUser?.isBot ?? true)
        }

        if msg.category.hasSuffix("_TEXT") {
            msg.category = isSignalMessage ? MessageCategory.SIGNAL_TEXT.rawValue : MessageCategory.ENCRYPTED_TEXT.rawValue
        } else if msg.category.hasSuffix("_IMAGE") {
            msg.category = isSignalMessage ? MessageCategory.SIGNAL_IMAGE.rawValue : MessageCategory.ENCRYPTED_IMAGE.rawValue
        } else if msg.category.hasSuffix("_VIDEO") {
            msg.category = isSignalMessage ? MessageCategory.SIGNAL_VIDEO.rawValue : MessageCategory.ENCRYPTED_VIDEO.rawValue
        } else if msg.category.hasSuffix("_DATA") {
            msg.category = isSignalMessage ? MessageCategory.SIGNAL_DATA.rawValue : MessageCategory.ENCRYPTED_DATA.rawValue
        } else if msg.category.hasSuffix("_STICKER") {
            msg.category = isSignalMessage ? MessageCategory.SIGNAL_STICKER.rawValue : MessageCategory.ENCRYPTED_STICKER.rawValue
        } else if msg.category.hasSuffix("_CONTACT") {
            msg.category = isSignalMessage ? MessageCategory.SIGNAL_CONTACT.rawValue : MessageCategory.ENCRYPTED_CONTACT.rawValue
        } else if msg.category.hasSuffix("_AUDIO") {
            msg.category = isSignalMessage ? MessageCategory.SIGNAL_AUDIO.rawValue : MessageCategory.ENCRYPTED_AUDIO.rawValue
        } else if msg.category.hasSuffix("_LIVE") {
            msg.category = isSignalMessage ? MessageCategory.SIGNAL_LIVE.rawValue : MessageCategory.ENCRYPTED_LIVE.rawValue
        } else if msg.category.hasSuffix("_POST") {
            msg.category = isSignalMessage ? MessageCategory.SIGNAL_POST.rawValue : MessageCategory.ENCRYPTED_POST.rawValue
        } else if msg.category.hasSuffix("_LOCATION") {
            msg.category = isSignalMessage ? MessageCategory.SIGNAL_LOCATION.rawValue : MessageCategory.ENCRYPTED_LOCATION.rawValue
        }

        jobCreationQueue.async {
            if msg.conversationId.isEmpty || !ConversationDAO.shared.isExist(conversationId: msg.conversationId) {
                guard let user = ownerUser else {
                    return
                }
                let conversationId = ConversationDAO.shared.makeConversationId(userId: account.user_id, ownerUserId: user.userId)
                msg.conversationId = conversationId
                ConversationDAO.shared.createConversation(conversation: ConversationResponse(conversationId: conversationId, userId: user.userId, avatarUrl: user.avatarUrl), targetStatus: .START)
            }
            if !message.category.hasPrefix("WEBRTC_") {
                if let content = msg.content, ["_TEXT", "_POST"].contains(where: msg.category.hasSuffix), content.utf8.count > maxTextMessageContentLength {
                    msg.content = String(content.prefix(maxTextMessageContentLength))
                }
                MessageDAO.shared.insertMessage(message: msg, messageSource: "")
            }
            if ["_TEXT", "_POST", "_STICKER", "_CONTACT", "_LIVE", "_LOCATION"].contains(where: msg.category.hasSuffix) || msg.category == MessageCategory.APP_CARD.rawValue {
                SendMessageService.shared.sendMessage(message: msg, data: msg.content)
            } else if msg.category.hasSuffix("_IMAGE") {
                let jobId = SendMessageService.shared.saveUploadJob(message: msg)
                UploaderQueue.shared.addJob(job: ImageUploadJob(message: msg, jobId: jobId))
            } else if msg.category.hasSuffix("_VIDEO") {
                let jobId = SendMessageService.shared.saveUploadJob(message: msg)
                UploaderQueue.shared.addJob(job: VideoUploadJob(message: msg, jobId: jobId))
            } else if msg.category.hasSuffix("_DATA") {
                let jobId = SendMessageService.shared.saveUploadJob(message: msg)
                UploaderQueue.shared.addJob(job: FileUploadJob(message: msg, jobId: jobId))
            } else if msg.category.hasSuffix("_AUDIO") {
                let jobId = SendMessageService.shared.saveUploadJob(message: msg)
                UploaderQueue.shared.addJob(job: AudioUploadJob(message: msg, jobId: jobId))
            } else if message.category.hasPrefix("WEBRTC_"), let recipient = ownerUser {
                SendMessageService.shared.sendWebRTCMessage(message: message, recipientId: recipient.userId)
            }
        }
    }
    
}
