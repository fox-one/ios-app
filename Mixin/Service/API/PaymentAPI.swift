import MixinServices

final class PaymentAPI: MixinAPI {

    private enum url {
        static let transactions = "transactions"
        static let transfers = "transfers"
        static let payments = "payments"
    }
    static let shared = PaymentAPI()

    func payments(assetId: String, opponentId: String, amount: String, traceId: String) -> MixinAPI.Result<PaymentResponse> {
        let param: [String : Any] = ["asset_id": assetId, "opponent_id": opponentId, "amount": amount, "trace_id": traceId]
        return request(method: .post, url: url.payments, parameters: param)
    }

    func payments(assetId: String, addressId: String, amount: String, traceId: String) -> MixinAPI.Result<PaymentResponse> {
        let param: [String : Any] = ["asset_id": assetId, "address_id": addressId, "amount": amount, "trace_id": traceId]
        return request(method: .post, url: url.payments, parameters: param)
    }

    func transactions(transactionRequest: RawTransactionRequest, pin: String, completion: @escaping (MixinAPI.Result<Snapshot>) -> Void) {
        var transactionRequest = transactionRequest
        KeyUtil.aesEncrypt(pin: pin, completion: completion) { [weak self](encryptedPin) in
            transactionRequest.pin = encryptedPin
            self?.request(method: .post, url: url.transactions, parameters: transactionRequest.toParameters(), encoding: EncodableParameterEncoding<RawTransactionRequest>(), completion: completion)
        }
    }

    func transfer(assetId: String, opponentId: String, amount: String, memo: String, pin: String, traceId: String, completion: @escaping (MixinAPI.Result<Snapshot>) -> Void) {
        KeyUtil.aesEncrypt(pin: pin, completion: completion) { [weak self](encryptedPin) in
            let param: [String : Any] = ["asset_id": assetId, "opponent_id": opponentId, "amount": amount, "memo": memo, "pin": encryptedPin, "trace_id": traceId]
            self?.request(method: .post, url: url.transfers, parameters: param, completion: completion)
        }
    }

}
