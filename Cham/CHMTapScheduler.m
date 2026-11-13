#import "CHMTapScheduler.h"

@interface CHMTapScheduler ()
@property (nonatomic, strong) dispatch_source_t timer;
@property (nonatomic) NSUInteger pointIndex;
@property (nonatomic) NSUInteger completedCycles;
@property (nonatomic, getter=isRunning) BOOL running;
@end

@implementation CHMTapScheduler
- (instancetype)init {
    self = [super init];
    if (self) { _points = @[]; _mode = CHMTapModePoint; _interval = 0.5; _holdDuration = 0.1; }
    return self;
}

- (void)start {
    [self stop];
    if (self.points.count == 0 || !self.eventHandler) return;
    self.pointIndex = 0;
    self.completedCycles = 0;
    self.running = YES;
    dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
    self.timer = timer;
    dispatch_source_set_timer(timer, DISPATCH_TIME_NOW, [self nextIntervalNanos], 2 * NSEC_PER_MSEC);
    __weak typeof(self) weakSelf = self;
    dispatch_source_set_event_handler(timer, ^{ [weakSelf emitNextTap]; });
    dispatch_resume(timer);
}

- (void)stop {
    if (self.timer) { dispatch_source_cancel(self.timer); self.timer = nil; }
    self.running = NO;
}

- (uint64_t)nextIntervalNanos {
    NSTimeInterval value = MAX(0.01, self.interval);
    switch (self.mode) {
        case CHMTapModeDouble: value = MIN(value, 0.12); break;
        case CHMTapModeHold: value = MAX(value, self.holdDuration); break;
        case CHMTapModeHuman: value *= 0.8 + ((double)arc4random_uniform(401) / 1000.0); break;
        case CHMTapModeExtreme: value = MIN(value, 0.03); break;
        case CHMTapModeUltra: value = MIN(value, 0.01); break;
        case CHMTapModePoint: break;
    }
    return (uint64_t)(value * NSEC_PER_SEC);
}

- (void)emitNextTap {
    if (!self.running || self.points.count == 0) { [self stop]; return; }
    CGPoint point = self.points[self.pointIndex % self.points.count].CGPointValue;
    NSTimeInterval hold = self.mode == CHMTapModeHold ? MAX(0.05, self.holdDuration) : 0.05;
    self.eventHandler(point, YES, hold);
    self.eventHandler(point, NO, hold);
    self.pointIndex++;
    if (self.pointIndex % self.points.count == 0) {
        self.completedCycles++;
        if (self.repeatCount > 0 && self.completedCycles >= self.repeatCount) { [self stop]; return; }
    }
    if (self.timer) {
        uint64_t next = [self nextIntervalNanos];
        dispatch_source_set_timer(self.timer, dispatch_time(DISPATCH_TIME_NOW, next), next, 2 * NSEC_PER_MSEC);
    }
}
- (void)dealloc { [self stop]; }
@end
