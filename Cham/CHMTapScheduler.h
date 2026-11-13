#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

NS_ASSUME_NONNULL_BEGIN
typedef NS_ENUM(NSInteger, CHMTapMode) {
    CHMTapModePoint = 0, CHMTapModeDouble, CHMTapModeHold,
    CHMTapModeHuman, CHMTapModeExtreme, CHMTapModeUltra
};
typedef void (^CHMTapEventHandler)(CGPoint point, BOOL isPress, NSTimeInterval holdDuration);

@interface CHMTapScheduler : NSObject
@property (nonatomic, copy) NSArray<NSValue *> *points;
@property (nonatomic) CHMTapMode mode;
@property (nonatomic) NSTimeInterval interval;
@property (nonatomic) NSTimeInterval holdDuration;
@property (nonatomic) NSUInteger repeatCount; // 0 repeats until stopped.
@property (nonatomic, copy, nullable) CHMTapEventHandler eventHandler;
@property (nonatomic, readonly, getter=isRunning) BOOL running;
- (void)start;
- (void)stop;
@end
NS_ASSUME_NONNULL_END
