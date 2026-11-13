#import <UIKit/UIKit.h>
#import "CHMOverlay.h"

static CHMOverlay *CHMSharedOverlay;

%ctor {
    @autoreleasepool {
        dispatch_async(dispatch_get_main_queue(), ^{
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
                if (!CHMSharedOverlay) {
                    CHMSharedOverlay = [[CHMOverlay alloc] init];
                    [CHMSharedOverlay attachToApplicationWindow];
                }
            });
        });
    }
}
