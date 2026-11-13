#import "CHMTouchBackend.h"
#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <dlfcn.h>
#import <mach/mach_time.h>
#import <math.h>

typedef struct __IOHIDEvent *CHMIOHIDEventRef;
typedef struct __IOHIDEventSystemClient *CHMIOHIDEventSystemClientRef;

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
    return UIApplication.sharedApplication.keyWindow;
}

static BOOL CHMDispatchHIDTouch(CGPoint point, CHMTouchPhase phase, NSError **error) {
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

    CHMSetDigitizerInfo(parent, contextID, 0, 0, NULL, 0, 0);

    UIApplication *application = UIApplication.sharedApplication;
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
        self.dispatchHandler = ^BOOL(CGPoint point, CHMTouchPhase phase, NSError **error) {
            return CHMDispatchHIDTouch(point, phase, error);
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
