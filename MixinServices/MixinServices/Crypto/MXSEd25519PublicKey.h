#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(Ed25519PublicKey)
@interface MXSEd25519PublicKey : NSObject

@property (nonatomic, strong, readonly) NSData *rawRepresentation;
@property (nonatomic, strong, readonly) NSData *x25519Representation;

- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
