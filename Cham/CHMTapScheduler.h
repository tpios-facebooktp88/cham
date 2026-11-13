#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import "CHMTouchBackend.h"

NS_ASSUME_NONNULL_BEGIN

@interface CHMTapScheduler : NSObject
@property (nonatomic, copy) NSArray<NSValue *> *points;
@property (nonatomic) NSTimeInterval interval;
@property (nonatomic) NSTimeInterval pressDuration;
@property (nonatomic, strong) CHMTouchBackend *backend;
@property (nonatomic, copy, nullable) void (^errorHandler)(NSError *error);
@property (nonatomic, readonly, getter=isRunning) BOOL running;
@property (nonatomic, readonly) BOOL hasUnconfirmedTouch;

- (instancetype)initWithBackend:(CHMTouchBackend *)backend;
- (void)start;
- (void)stop;
@end

NS_ASSUME_NONNULL_END
