#import "CHMTapScheduler.h"
#import <dispatch/dispatch.h>

@interface CHMTapScheduler ()
@property (nonatomic, strong) dispatch_source_t timer;
@property (nonatomic) NSUInteger pointIndex;
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
        _interval = 0.5;
        _pressDuration = 0.06;
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
        if (self.pointIndex >= self.points.count) self.pointIndex = 0;
        CGPoint point;
        [self.points[self.pointIndex] getValue:&point];
        self.activePoint = point;

        NSError *error = nil;
        if (![self.backend dispatchPoint:self.activePoint phase:CHMTouchPhaseDown error:&error]) {
            if (self.errorHandler && error) self.errorHandler(error);
            [self stop];
            return;
        }

        self.touchIsDown = YES;
        [self scheduleAfter:MAX(0.0001, self.pressDuration)];
        return;
    }

    NSError *error = nil;
    if (![self.backend dispatchPoint:self.activePoint phase:CHMTouchPhaseUp error:&error]) {
        if (self.errorHandler && error) self.errorHandler(error);
        // Keep the active-touch state if UP cannot be confirmed. stop makes
        // one final release attempt and blocks any later DOWN if it still fails.
        [self stop];
        return;
    }

    self.touchIsDown = NO;
    self.pointIndex++;
    [self scheduleAfter:MAX(0.01, self.interval)];
}

- (void)dealloc {
    [self stop];
}

@end
