#import "CHMTouchBackend.h"
#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <dlfcn.h>
#import <mach/mach_time.h>
#import <math.h>

typedef struct __IOHIDEvent *CHMIOHIDEventRef;
typedef struct __IOHIDEventSystemClient *CHMIOHIDEventSystemClientRef;

@interface UITouch (CHMPrivate)
- (void)setWindow:(UIWindow *)window;
- (void)setView:(UIView *)view;
- (void)setGestureView:(UIView *)view;
- (void)setTapCount:(NSUInteger)tapCount;
- (void)setPhase:(UITouchPhase)phase;
- (void)setTimestamp:(NSTimeInterval)timestamp;
- (void)_setLocationInWindow:(CGPoint)point resetPrevious:(BOOL)resetPrevious;
- (void)_setIsFirstTouchForView:(BOOL)firstTouch;
- (void)setIsTap:(BOOL)isTap;
- (void)_setHidEvent:(CHMIOHIDEventRef)event;
@end

@interface UIEvent (CHMPrivate)
- (void)_clearTouches;
- (void)_setHIDEvent:(CHMIOHIDEventRef)event;
- (void)_setTimestamp:(NSTimeInterval)timestamp;
- (void)_addTouch:(UITouch *)touch forDelayedDelivery:(BOOL)delayed;
@end

@interface UIApplication (CHMPrivate)
- (UIEvent *)_touchesEvent;
@end

@interface CHMTouchBackend ()
@property (nonatomic, strong) UITouch *activeTouch;
@end

typedef CHMIOHIDEventRef (*CHMCreateDigitizerEventFn)(
    CFAllocatorRef, uint64_t, uint32_t, uint32_t, uint32_t, uint32_t, uint32_t,
    double, double, double, double, double, uint8_t, uint8_t, uint32_t);
typedef CHMIOHIDEventRef (*CHMCreateFingerEventFn)(
    CFAllocatorRef, uint64_t, uint32_t, uint32_t, uint32_t,
    double, double, double, double, double, uint8_t, uint8_t, uint32_t);
typedef CHMIOHIDEventSystemClientRef (*CHMCreateClientFn)(CFAllocatorRef);
typedef void (*CHMSetSenderIDFn)(CHMIOHIDEventRef, uint64_t);
typedef void (*CHMSetIntegerValueFn)(CHMIOHIDEventRef, uint32_t, int);
typedef void (*CHMSetFloatValueFn)(CHMIOHIDEventRef, uint32_t, double);
typedef void (*CHMAppendEventFn)(CHMIOHIDEventRef, CHMIOHIDEventRef, uint32_t);
typedef void (*CHMDispatchEventFn)(CHMIOHIDEventSystemClientRef, CHMIOHIDEventRef);
typedef void (*CHMSetDigitizerInfoFn)(
    CHMIOHIDEventRef, uint32_t, uint8_t, uint8_t, CFStringRef, CFTimeInterval, float);

static void *CHMIOKitHandle;
static void *CHMBackBoardHandle;
static CHMIOHIDEventSystemClientRef CHMEventClient;
static CHMCreateDigitizerEventFn CHMCreateDigitizerEvent;
static CHMCreateFingerEventFn CHMCreateFingerEvent;
static CHMCreateClientFn CHMCreateClient;
static CHMSetSenderIDFn CHMSetSenderID;
static CHMSetIntegerValueFn CHMSetIntegerValue;
static CHMSetFloatValueFn CHMSetFloatValue;
static CHMAppendEventFn CHMAppendEvent;
static CHMDispatchEventFn CHMDispatchEvent;
static CHMSetDigitizerInfoFn CHMSetDigitizerInfo;

NSString * const CHMTouchBackendErrorDomain = @"com.cham.autoclicker.touch";

static void CHMSetError(NSError **error, NSInteger code, NSString *message) {
    if (error) {
        *error = [NSError errorWithDomain:CHMTouchBackendErrorDomain
                                     code:code
                                 userInfo:@{NSLocalizedDescriptionKey: message}];
    }
}

static BOOL CHMLoadHIDAPI(void) {
    static dispatch_once_t onceToken;
    static BOOL available = NO;
    dispatch_once(&onceToken, ^{
        CHMIOKitHandle = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_NOW);
        if (!CHMIOKitHandle) {
            CHMIOKitHandle = dlopen("/System/Library/PrivateFrameworks/IOKit.framework/IOKit", RTLD_NOW);
        }
        CHMBackBoardHandle = dlopen(
            "/System/Library/PrivateFrameworks/BackBoardServices.framework/BackBoardServices",
            RTLD_NOW);
        if (!CHMIOKitHandle || !CHMBackBoardHandle) return;

        CHMCreateDigitizerEvent = (CHMCreateDigitizerEventFn)dlsym(CHMIOKitHandle, "IOHIDEventCreateDigitizerEvent");
        CHMCreateFingerEvent = (CHMCreateFingerEventFn)dlsym(CHMIOKitHandle, "IOHIDEventCreateDigitizerFingerEvent");
        CHMCreateClient = (CHMCreateClientFn)dlsym(CHMIOKitHandle, "IOHIDEventSystemClientCreate");
        CHMSetSenderID = (CHMSetSenderIDFn)dlsym(CHMIOKitHandle, "IOHIDEventSetSenderID");
        CHMSetIntegerValue = (CHMSetIntegerValueFn)dlsym(CHMIOKitHandle, "IOHIDEventSetIntegerValue");
        CHMSetFloatValue = (CHMSetFloatValueFn)dlsym(CHMIOKitHandle, "IOHIDEventSetFloatValue");
        CHMAppendEvent = (CHMAppendEventFn)dlsym(CHMIOKitHandle, "IOHIDEventAppendEvent");
        CHMDispatchEvent = (CHMDispatchEventFn)dlsym(CHMIOKitHandle, "IOHIDEventSystemClientDispatchEvent");
        CHMSetDigitizerInfo = (CHMSetDigitizerInfoFn)dlsym(CHMBackBoardHandle, "BKSHIDEventSetDigitizerInfo");

        if (!CHMCreateDigitizerEvent || !CHMCreateFingerEvent || !CHMCreateClient ||
            !CHMSetSenderID || !CHMSetIntegerValue || !CHMSetFloatValue ||
            !CHMAppendEvent || !CHMDispatchEvent || !CHMSetDigitizerInfo) return;

        CHMEventClient = CHMCreateClient(kCFAllocatorDefault);
        available = CHMEventClient != NULL;
    });
    return available;
}

static UIWindow *CHMActiveWindow(void) {
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class]) continue;
        for (UIWindow *window in ((UIWindowScene *)scene).windows) {
            if (window.isKeyWindow) return window;
        }
    }
    return nil;
}

static BOOL CHMDispatchHIDTouch(CGPoint point, CHMTouchPhase phase, CHMTouchBackend *backend, NSError **error) {
    if (!NSThread.isMainThread) {
        CHMSetError(error, 4, @"HID touch events must be dispatched on the main thread.");
        return NO;
    }
    if (!CHMLoadHIDAPI()) {
        CHMSetError(error, 5, @"The required IOKit or BackBoardServices HID entry points are unavailable.");
        return NO;
    }

    UIWindow *window = CHMActiveWindow();
    SEL contextSelector = NSSelectorFromString(@"_contextId");
    if (!window || ![window respondsToSelector:contextSelector]) {
        CHMSetError(error, 6, @"The active application window does not expose a HID context ID.");
        return NO;
    }
    uint32_t contextID = ((uint32_t (*)(id, SEL))objc_msgSend)(window, contextSelector);
    if (contextID == 0) {
        CHMSetError(error, 7, @"The active application window returned an invalid HID context ID.");
        return NO;
    }

    const uint32_t eventMask = phase == CHMTouchPhaseDown ? 0x27 : 0x24;
    const uint64_t senderID = 0xDEFACEDBEEFFECE5ULL;
    const double force = 0.5;
    const double radius = 0.04;
    const uint32_t fingerIndex = 1; // The scheduler currently drives one active finger.

    uint64_t timestamp = mach_absolute_time();
    CHMIOHIDEventRef parent = CHMCreateDigitizerEvent(
        kCFAllocatorDefault, timestamp, 3, 0, 0, eventMask, 0,
        point.x, point.y, 0.0, force, 0.0, 1, 1, 0);
    if (!parent) {
        CHMSetError(error, 8, @"IOHIDEventCreateDigitizerEvent returned null.");
        return NO;
    }

    CHMIOHIDEventRef finger = CHMCreateFingerEvent(
        kCFAllocatorDefault, timestamp, fingerIndex, fingerIndex, eventMask,
        point.x, point.y, 0.0, force, 0.0, 1, 1, 0);
    if (!finger) {
        CFRelease(parent);
        CHMSetError(error, 9, @"IOHIDEventCreateDigitizerFingerEvent returned null.");
        return NO;
    }

    CHMSetSenderID(parent, senderID);
    CHMSetSenderID(finger, senderID);

    // These field IDs and values are copied from the verified Cham HID call sites.
    CHMSetIntegerValue(parent, 0xB002F, 1);
    CHMSetIntegerValue(parent, 0xB0039, 3);
    CHMSetIntegerValue(parent, 0xB003A, 1);
    CHMSetIntegerValue(parent, 0xB003B, 1);
    CHMSetFloatValue(finger, 0xB0030, radius);
    CHMSetFloatValue(finger, 0xB0031, radius * 0.8);
    CHMAppendEvent(parent, finger, 0);

    UIApplication *application = UIApplication.sharedApplication;
    UIView *hitView = [window hitTest:point withEvent:nil] ?: window.rootViewController.view;
    UITouch *touch = backend.activeTouch;
    if (!touch && phase == CHMTouchPhaseUp) {
        CFRelease(finger);
        CFRelease(parent);
        CHMSetError(error, 11, @"Cannot end a touch that has no active UITouch object.");
        return NO;
    }
    if (!hitView || ![application respondsToSelector:@selector(_touchesEvent)]) {
        CFRelease(finger);
        CFRelease(parent);
        CHMSetError(error, 12, @"UIKit could not provide a hit-tested view or touch event.");
        return NO;
    }
    if (!touch) touch = [[UITouch alloc] init];
    UIEvent *touchEvent = [application _touchesEvent];
    if (!touch || !touchEvent ||
        ![touch respondsToSelector:@selector(setWindow:)] ||
        ![touch respondsToSelector:@selector(setView:)] ||
        ![touch respondsToSelector:@selector(setTapCount:)] ||
        ![touch respondsToSelector:@selector(setPhase:)] ||
        ![touch respondsToSelector:@selector(setTimestamp:)] ||
        ![touch respondsToSelector:@selector(_setLocationInWindow:resetPrevious:)] ||
        ![touch respondsToSelector:@selector(_setIsFirstTouchForView:)] ||
        ![touch respondsToSelector:@selector(_setHidEvent:)] ||
        ![touchEvent respondsToSelector:@selector(_clearTouches)] ||
        ![touchEvent respondsToSelector:@selector(_setHIDEvent:)] ||
        ![touchEvent respondsToSelector:@selector(_setTimestamp:)] ||
        ![touchEvent respondsToSelector:@selector(_addTouch:forDelayedDelivery:)]) {
        CFRelease(finger);
        CFRelease(parent);
        CHMSetError(error, 13, @"The required private UIKit touch selectors are unavailable.");
        return NO;
    }

    NSTimeInterval eventTime = NSProcessInfo.processInfo.systemUptime;
    [touch setWindow:window];
    [touch setView:hitView];
    if ([touch respondsToSelector:@selector(setGestureView:)]) [touch setGestureView:hitView];
    [touch setTapCount:1];
    // Cham keeps the UITouch in Stationary; the HID event carries DOWN/UP.
    [touch setPhase:UITouchPhaseStationary];
    [touch setTimestamp:eventTime];
    [touch _setLocationInWindow:point resetPrevious:NO];
    [touch _setIsFirstTouchForView:YES];
    if ([touch respondsToSelector:@selector(setIsTap:)]) [touch setIsTap:YES];
    [touch _setHidEvent:parent];

    [touchEvent _clearTouches];
    [touchEvent _setHIDEvent:parent];
    [touchEvent _setTimestamp:eventTime];
    [touchEvent _addTouch:touch forDelayedDelivery:NO];
    backend.activeTouch = touch;

    CHMSetDigitizerInfo(parent, contextID, 0, 0, NULL, 0, 0);

    SEL enqueueSelector = NSSelectorFromString(@"_enqueueHIDEvent:");
    if ([application respondsToSelector:enqueueSelector]) {
        ((void (*)(id, SEL, CHMIOHIDEventRef))objc_msgSend)(application, enqueueSelector, parent);
    }
    CHMDispatchEvent(CHMEventClient, parent);

    CFRelease(finger);
    CFRelease(parent);
    return YES;
}

@implementation CHMTouchBackend

- (instancetype)init {
    self = [super init];
    if (self && CHMLoadHIDAPI()) {
        __weak typeof(self) weakSelf = self;
        self.dispatchHandler = ^BOOL(CGPoint point, CHMTouchPhase phase, NSError **error) {
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) {
                CHMSetError(error, 14, @"The touch backend is no longer available.");
                return NO;
            }
            return CHMDispatchHIDTouch(point, phase, self, error);
        };
    }
    return self;
}

- (BOOL)isAvailable {
    return self.dispatchHandler != nil && CHMLoadHIDAPI();
}

- (BOOL)dispatchPoint:(CGPoint)point phase:(CHMTouchPhase)phase error:(NSError **)error {
    CHMTouchDispatchHandler handler = self.dispatchHandler;
    if (!handler) {
        CHMSetError(error, 1, @"No usable iOS HID touch provider is available.");
        return NO;
    }
    if (!isfinite(point.x) || !isfinite(point.y)) {
        CHMSetError(error, 2, @"Touch coordinates must be finite.");
        return NO;
    }
    if (phase != CHMTouchPhaseDown && phase != CHMTouchPhaseUp) {
        CHMSetError(error, 3, @"Unsupported touch phase.");
        return NO;
    }

    NSError *localError = nil;
    NSError **targetError = error ?: &localError;
    BOOL sent = handler(point, phase, targetError);
    if (!sent && !*targetError) {
        CHMSetError(targetError, 10, @"The HID touch provider rejected the event.");
    }
    return sent;
}

@end
