#import "CHMTouchBackend.h"

NSString * const CHMTouchBackendErrorDomain = @"com.cham.autoclicker.touch";

@implementation CHMTouchBackend

- (BOOL)isAvailable {
    return self.dispatchHandler != nil;
}

- (BOOL)dispatchPoint:(CGPoint)point phase:(CHMTouchPhase)phase error:(NSError **)error {
    CHMTouchDispatchHandler handler = self.dispatchHandler;
    if (!handler) {
        if (error) {
            *error = [NSError errorWithDomain:CHMTouchBackendErrorDomain
                                         code:1
                                     userInfo:@{NSLocalizedDescriptionKey:
                                                    @"No verified iOS touch-event provider is registered."}];
        }
        return NO;
    }
    if (!isfinite(point.x) || !isfinite(point.y)) {
        if (error) {
            *error = [NSError errorWithDomain:CHMTouchBackendErrorDomain
                                         code:2
                                     userInfo:@{NSLocalizedDescriptionKey:@"Touch coordinates must be finite."}];
        }
        return NO;
    }
    return handler(point, phase, error);
}

@end
