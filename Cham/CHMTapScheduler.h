#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import "CHMTouchBackend.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, CHMTapMode) {
    CHMTapModePoint = 0, CHMTapModeDouble, CHMTapModeHold,
    CHMTapModeHuman, CHMTapModeExtreme, CHMTapModeUltra
};

@interface CHMTapScheduler : NSObject
@property (nonatomic, copy) NSArray<NSValue *> *points;
@property (nonatomic) CHMTapMode mode;
@property (nonatomic) NSTimeInterval interval;
@property (nonatomic) NSTimeInterval holdDuration;
@property (nonatomic) NSUInteger repeatCount; // 0 repeats until stopped.
@property (nonatomic) NSTimeInterval doubleTapGap;
@property (nonatomic, strong) CHMTouchBackend *backend;
@property (nonatomic, copy, nullable) void (^errorHandler)(NSError *error);
@property (nonatomic, readonly, getter=isRunning) BOOL running;

- (instancetype)initWithBackend:(CHMTouchBackend *)backend;
- (void)start;
- (void)stop;
@end

NS_ASSUME_NONNULL_END
