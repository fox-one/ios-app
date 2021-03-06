import Foundation

public enum PreKeyUtil {
    
    internal static let batchSize: Int = 700
    internal static let prekeyMiniNum = 500
    
    public static func getIdentityKeyPair() throws -> KeyPair {
        guard let identity = IdentityDAO.shared.getLocalIdentity() else {
            throw SignalError.noData
        }
        return identity.getIdentityKeyPair()
    }
    
    public static func generateKeys() throws -> SignalKeyRequest {
        let identityKeyPair = try PreKeyUtil.getIdentityKeyPair()
        let oneTimePreKeys = try PreKeyUtil.generatePreKeys()
        let signedPreKey = try PreKeyUtil.generateSignedPreKey(identityKeyPair: identityKeyPair)
        return SignalKeyRequest(identityKey: identityKeyPair.publicKey.base64EncodedString(),
                                signedPreKey: SignedPreKeyRequest(signed: signedPreKey),
                                oneTimePreKeys: oneTimePreKeys)
    }
    
    internal static func generatePreKeys() throws -> [OneTimePreKey] {
        let preKeyIdOffset = AppGroupUserDefaults.Crypto.Offset.prekey ?? makeRandomPrekeyOffset()
        let records = try Signal.generatePreKeys(start: preKeyIdOffset, count: batchSize)
        AppGroupUserDefaults.Crypto.Offset.prekey = preKeyIdOffset + UInt32(batchSize) + 1
        let preKeys = try records.map { PreKey(preKeyId: Int($0.id), record: try $0.data()) }
        MixinPreKeyStore().store(preKeys: preKeys)
        return records.map { OneTimePreKey(keyId: $0.id, preKey: $0) }
    }
    
    internal static func generateSignedPreKey(identityKeyPair : KeyPair) throws -> SessionSignedPreKey {
        let signedPreKeyOffset = AppGroupUserDefaults.Crypto.Offset.signedPrekey ?? makeRandomPrekeyOffset()
        let timestamp = UInt64(Date().timeIntervalSince1970 * 1000)
        let record = try Signal.generate(signedPreKey: signedPreKeyOffset, identity: identityKeyPair, timestamp: timestamp)
        let store = MixinSignedPreKeyStore()
        _ = store.store(signedPreKey: try record.data(), for: record.id)
        AppGroupUserDefaults.Crypto.Offset.signedPrekey = signedPreKeyOffset + 1
        return record
    }
    
    private static func makeRandomPrekeyOffset() -> UInt32 {
        let min: UInt32 = 1000
        let max: UInt32 = .max / 2
        return min + UInt32(arc4random_uniform(max - min))
    }
    
}
