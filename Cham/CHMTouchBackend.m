#import "CHMTouchBackend.h"
#import <math.h>

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

    NSError *localError = nil;
    NSError **targetError = error ?: &localError;
    BOOL sent = handler(point, phase, targetError);
    if (!sent && !*targetError) {
        *targetError = [NSError errorWithDomain:CHMTouchBackendErrorDomain
                                           code:3
                                       userInfo:@{NSLocalizedDescriptionKey:@"The registered touch provider rejected the event."}];
    }
    return sent;
}

@end
