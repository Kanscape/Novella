#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NovellaRsBridge : NSObject
+ (nullable NSData *)convertWoff2ToTtf:(NSData *)data
    NS_SWIFT_NAME(convertWoff2ToTtf(_:));
+ (NSArray<NSNumber *> *)extractInvisibleCodepoints:(NSData *)data;
@end

NS_ASSUME_NONNULL_END
