#import "CHMTapScheduler.h"
#import <UIKit/UIKit.h>

@interface CHMTapScheduler ()
@property (nonatomic, strong) dispatch_source_t timer;
@property (nonatomic) NSUInteger pointIndex;
@property (nonatomic) NSUInteger completedCycles;
@property (nonatomic) NSUInteger tapsAtCurrentPoint;
@property (nonatomic) BOOL touchIsDown;
@property (nonatomic) CGPoint activePoint;
@property (nonatomic, getter=isRunning) BOOL running;
@end

@implementation CHMTapScheduler

- (instancetype)init {
    return [self initWithBackend:[[CHMTouchBackend alloc] init]];
}

- (instancetype)initWithBackend:(CHMTouchBackend *)backend {
    self = [super init];
    if (self) {
        _backend = backend;
        _points = @[];
        _mode = CHMTapModePoint;
        _interval = 0.5;
        _holdDuration = 0.1;
        _doubleTapGap = 0.08;
    }
    return self;
}

- (BOOL)hasUnconfirmedTouch {
    return self.touchIsDown;
}

- (void)start {
    [self stop];
    if (self.touchIsDown) {
        NSError *error = [NSError errorWithDomain:@"com.cham.autoclicker.tap"
                                             code:3
                                         userInfo:@{NSLocalizedDescriptionKey:
                                                        @"A previous touch has not been confirmed as released; start was blocked."}];
        if (self.errorHandler) self.errorHandler(error);
        return;
    }
    if (self.points.count == 0 || !self.backend.available) {
        NSError *error = [NSError errorWithDomain:@"com.cham.autoclicker.tap"
                                             code:1
                                         userInfo:@{NSLocalizedDescriptionKey:
                                                        self.points.count == 0 ? @"Add at least one tap point." :
                                                        @"Tap backend is unavailable; no touch was sent."}];
        if (self.errorHandler) self.errorHandler(error);
        return;
    }

    self.pointIndex = 0;
    self.completedCycles = 0;
    self.tapsAtCurrentPoint = 0;
    self.touchIsDown = NO;
    self.running = YES;
    [self scheduleAfter:0];
}

- (void)stop {
    if (self.timer) {
        dispatch_source_cancel(self.timer);
        self.timer = nil;
    }
    if (self.touchIsDown) {
        NSError *error = nil;
        BOOL ended = [self.backend dispatchPoint:self.activePoint phase:CHMTouchPhaseUp error:&error];
        if (ended) {
            self.touchIsDown = NO;
        } else if (self.errorHandler) {
            self.errorHandler(error ?: [NSError errorWithDomain:@"com.cham.autoclicker.tap"
                                                            code:2
                                                        userInfo:@{NSLocalizedDescriptionKey:
                                                                       @"Touch release was not confirmed; the scheduler remains blocked from starting another touch."}]);
        }
    }
    self.running = NO;
}

- (NSUInteger)tapsPerPoint {
    return self.mode == CHMTapModeDouble ? 2 : 1;
}

- (NSTimeInterval)tapHoldDuration {
    return MAX(0.0001, self.holdDuration);
}

- (NSTimeInterval)nextInterval {
    NSTimeInterval value = MAX(0.01, self.interval);
    switch (self.mode) {
        case CHMTapModeHuman:
            value *= 0.8 + ((double)arc4random_uniform(401) / 1000.0);
            break;
        case CHMTapModeExtreme:
            value = MIN(value, 0.03);
            break;
        case CHMTapModeUltra:
            value = MIN(value, 0.01);
            break;
        case CHMTapModePoint:
        case CHMTapModeDouble:
        case CHMTapModeHold:
            break;
    }
    return value;
}

- (void)scheduleAfter:(NSTimeInterval)delay {
    if (!self.running) return;
    if (self.timer) {
        dispatch_source_cancel(self.timer);
        self.timer = nil;
    }
    dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
    self.timer = timer;
    uint64_t nanos = (uint64_t)(MAX(0.0, delay) * NSEC_PER_SEC);
    dispatch_source_set_timer(timer, dispatch_time(DISPATCH_TIME_NOW, nanos), DISPATCH_TIME_FOREVER, 1 * NSEC_PER_MSEC);
    __weak typeof(self) weakSelf = self;
    dispatch_source_set_event_handler(timer, ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        dispatch_source_cancel(self.timer);
        self.timer = nil;
        [self advance];
    });
    dispatch_resume(timer);
}

- (void)advance {
    if (!self.running) return;

    if (!self.touchIsDown) {
        if (self.pointIndex >= self.points.count) {
            self.completedCycles++;
            if (self.repeatCount > 0 && self.completedCycles >= self.repeatCount) {
                [self stop];
                return;
            }
            self.pointIndex = 0;
        }

        self.activePoint = self.points[self.pointIndex].CGPointValue;
        NSError *error = nil;
        if (![self.backend dispatchPoint:self.activePoint phase:CHMTouchPhaseDown error:&error]) {
            if (self.errorHandler && error) self.errorHandler(error);
            [self stop];
            return;
        }
        self.touchIsDown = YES;
        [self scheduleAfter:[self tapHoldDuration]];
        return;
    }

    NSError *error = nil;
    if (![self.backend dispatchPoint:self.activePoint phase:CHMTouchPhaseUp error:&error]) {
        if (self.errorHandler && error) self.errorHandler(error);
        // Keep touchIsDown set. stop will make one release attempt and retain
        // the blocked state if the backend still cannot confirm the UP event.
        [self stop];
        return;
    }
    self.touchIsDown = NO;
    self.tapsAtCurrentPoint++;

    if (self.tapsAtCurrentPoint < [self tapsPerPoint]) {
        [self scheduleAfter:MAX(0.02, self.doubleTapGap)];
        return;
    }

    self.tapsAtCurrentPoint = 0;
    self.pointIndex++;
    [self scheduleAfter:[self nextInterval]];
}

- (void)dealloc {
    [self stop];
}

@end
