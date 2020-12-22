import UIKit
import MixinServices

class StickersViewController: StickersCollectionViewController, ConversationInputAccessible {
    
    var stickers = [StickerItem]()
    
    override var isEmpty: Bool {
        return stickers.isEmpty
    }
    
    func load(stickers: [StickerItem]) {
        self.stickers = stickers
        collectionView.reloadData()
        collectionView.setContentOffset(.zero, animated: false)
    }
    
    func send(sticker: StickerItem) {
        dataSource?.sendMessage(type: .SIGNAL_STICKER, value: sticker)
        if updateUsedAtAfterSent {
            DispatchQueue.global().async {
                let newUsedAt = Date().toUTCString()
                StickerDAO.shared.updateUsedAt(stickerId: sticker.stickerId, usedAt: newUsedAt)
                var newSticker = sticker
                newSticker.lastUseAt = newUsedAt
                NotificationCenter.default.post(onMainThread: .StickerUsedAtDidUpdate, object: newSticker)
            }
        }
    }
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return stickers.count
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: cellReuseId, for: indexPath) as! StickerPreviewCell
        let sticker = stickers[indexPath.row]
        cell.stickerView.load(sticker: sticker)
        return cell
    }
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        send(sticker: stickers[indexPath.row])
    }
    
}
