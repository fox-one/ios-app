#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(AudioMetadata)
@interface MXMAudioMetadata : NSObject

@property (nonatomic, assign, readonly) NSUInteger duration; // in milliseconds
@property (nonatomic, copy, readonly) NSData *waveform;

+ (instancetype)metadataWithDuration:(NSUInteger)duration waveform:(NSData *)waveform;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithDuration:(NSUInteger)duration waveform:(NSData *)waveform;

@end

NS_ASSUME_NONNULL_END
