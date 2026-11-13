#import "CHMOverlay.h"
#import "CHMTapScheduler.h"

@interface CHMOverlay ()
@property (nonatomic, weak) UIWindow *hostWindow;
@property (nonatomic, strong) UIButton *handle;
@property (nonatomic, strong) UIView *panel;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UILabel *pointsLabel;
@property (nonatomic, strong) UITextField *xField;
@property (nonatomic, strong) UITextField *yField;
@property (nonatomic, strong) UITextField *intervalField;
@property (nonatomic, strong) UISlider *touchTimeSlider;
@property (nonatomic, strong) UILabel *touchTimeLabel;
@property (nonatomic, strong) UISegmentedControl *modeControl;
@property (nonatomic, strong) NSMutableArray<NSValue *> *points;
@property (nonatomic, strong) NSMutableArray<UIView *> *pointMarkers;
@property (nonatomic, strong) CHMTapScheduler *scheduler;
@property (nonatomic) BOOL panelVisible;
@property (nonatomic) CGFloat panelScale;
@property (nonatomic, strong) id lifecycleObserver;
@end

@implementation CHMOverlay

- (void)attachToApplicationWindow {
    UIWindow *window = nil;
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class]) continue;
        for (UIWindow *candidate in ((UIWindowScene *)scene).windows) {
            if (candidate.keyWindow) { window = candidate; break; }
        }
        if (window) break;
    }
    if (!window || self.handle) return;

    self.hostWindow = window;
    __weak typeof(self) weakSelf = self;
    NSNotificationName lifecycleName = window.windowScene
        ? UISceneWillDeactivateNotification
        : UIApplicationWillResignActiveNotification;
    id lifecycleObject = window.windowScene ? (id)window.windowScene : (id)UIApplication.sharedApplication;
    self.lifecycleObserver = [[NSNotificationCenter defaultCenter]
        addObserverForName:lifecycleName
                    object:lifecycleObject
                     queue:NSOperationQueue.mainQueue
                usingBlock:^(NSNotification *note) {
        (void)note; // The observer only needs the notification timing.
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        BOOL hadPendingTouch = self.scheduler.hasUnconfirmedTouch;
        BOOL wasRunning = self.scheduler.running;
        [self.scheduler stop];
        if (self.scheduler.hasUnconfirmedTouch) {
            self.statusLabel.text = @"STOPPED · RELEASE UNCONFIRMED";
        } else if (hadPendingTouch) {
            self.statusLabel.text = @"Stopped · UP dispatch path invoked (delivery unverified)";
        } else if (wasRunning) {
            self.statusLabel.text = @"Scene inactive · scheduler stopped";
        }
    }];
    self.points = [NSMutableArray array];
    self.pointMarkers = [NSMutableArray array];
    self.panelScale = 1.0;
    self.scheduler = [[CHMTapScheduler alloc] init];
    self.scheduler.errorHandler = ^(NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            weakSelf.statusLabel.text = [NSString stringWithFormat:@"ERROR: %@", error.localizedDescription];
        });
    };

    UIButton *handle = [UIButton buttonWithType:UIButtonTypeSystem];
    handle.frame = CGRectMake(MAX(12.0, window.bounds.size.width - 72.0),
                              window.safeAreaInsets.top + 90.0, 56.0, 56.0);
    handle.backgroundColor = [UIColor colorWithRed:0.12 green:0.48 blue:0.92 alpha:0.94];
    handle.layer.cornerRadius = 28.0;
    [handle setTitle:@"CH" forState:UIControlStateNormal];
    [handle setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    handle.titleLabel.font = [UIFont boldSystemFontOfSize:17.0];
    [handle addTarget:self action:@selector(togglePanel) forControlEvents:UIControlEventTouchUpInside];
    [window addSubview:handle];
    self.handle = handle;

    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(moveHandle:)];
    [handle addGestureRecognizer:pan];
}

- (UILabel *)label:(NSString *)text frame:(CGRect)frame {
    UILabel *label = [[UILabel alloc] initWithFrame:frame];
    label.text = text;
    label.textColor = UIColor.whiteColor;
    label.font = [UIFont systemFontOfSize:12.0 weight:UIFontWeightMedium];
    return label;
}

- (UITextField *)field:(NSString *)value frame:(CGRect)frame {
    UITextField *field = [[UITextField alloc] initWithFrame:frame];
    field.text = value;
    field.textColor = UIColor.whiteColor;
    field.font = [UIFont systemFontOfSize:13.0];
    field.textAlignment = NSTextAlignmentCenter;
    field.keyboardType = UIKeyboardTypeDecimalPad;
    field.backgroundColor = [UIColor colorWithWhite:0.22 alpha:1.0];
    field.layer.cornerRadius = 6.0;
    field.layer.borderWidth = 1.0;
    field.layer.borderColor = [UIColor colorWithWhite:0.4 alpha:1.0].CGColor;
    return field;
}

- (UIButton *)button:(NSString *)title frame:(CGRect)frame color:(UIColor *)color action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.frame = frame;
    button.backgroundColor = color;
    button.layer.cornerRadius = 8.0;
    [button setTitle:title forState:UIControlStateNormal];
    [button setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont boldSystemFontOfSize:13.0];
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (void)togglePanel {
    if (self.panelVisible) {
        [self.panel removeFromSuperview];
        self.panel = nil;
        self.panelVisible = NO;
        return;
    }

    CGFloat width = MIN(320.0, CGRectGetWidth(self.hostWindow.bounds) - 24.0);
    CGFloat height = 390.0;
    CGFloat y = MIN(CGRectGetMaxY(self.handle.frame) + 10.0,
                    CGRectGetHeight(self.hostWindow.bounds) - height - 12.0);
    UIView *panel = [[UIView alloc] initWithFrame:CGRectMake(12.0, MAX(12.0, y), width, height)];
    panel.backgroundColor = [UIColor colorWithWhite:0.07 alpha:0.97];
    panel.layer.cornerRadius = 14.0;
    panel.layer.borderWidth = 1.0;
    panel.layer.borderColor = [UIColor colorWithWhite:0.32 alpha:1.0].CGColor;
    [self.hostWindow addSubview:panel];
    self.panel = panel;

    UILabel *title = [self label:@"CHAM AUTOCLICKER · TAP MODE  ↕ DRAG" frame:CGRectMake(12, 8, width - 112, 28)];
    title.font = [UIFont boldSystemFontOfSize:11.0];
    title.userInteractionEnabled = YES;
    [panel addSubview:title];
    UIPanGestureRecognizer *panelPan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(movePanel:)];
    [title addGestureRecognizer:panelPan];
    [panel addSubview:[self button:@"−" frame:CGRectMake(width - 92, 7, 26, 28)
                              color:[UIColor colorWithWhite:0.25 alpha:1.0] action:@selector(zoomOut)]];
    [panel addSubview:[self button:@"+" frame:CGRectMake(width - 62, 7, 26, 28)
                              color:[UIColor colorWithWhite:0.25 alpha:1.0] action:@selector(zoomIn)]];
    [panel addSubview:[self button:@"×" frame:CGRectMake(width - 32, 7, 26, 28)
                              color:[UIColor colorWithWhite:0.25 alpha:1.0] action:@selector(togglePanel)]];

    [panel addSubview:[self label:@"MODE" frame:CGRectMake(12, 42, 48, 22)]];
    self.modeControl = [[UISegmentedControl alloc] initWithItems:@[@"POINT", @"DOUBLE", @"HOLD", @"HUMAN", @"EXT", @"ULTRA"]];
    self.modeControl.frame = CGRectMake(12, 65, width - 24, 32);
    self.modeControl.selectedSegmentIndex = 0;
    self.modeControl.apportionsSegmentWidthsByContent = NO;
    self.modeControl.tintColor = [UIColor colorWithRed:0.12 green:0.48 blue:0.92 alpha:1.0];
    [panel addSubview:self.modeControl];

    [panel addSubview:[self label:@"X" frame:CGRectMake(12, 108, 20, 25)]];
    self.xField = [self field:[NSString stringWithFormat:@"%.0f", CGRectGetMidX(self.hostWindow.bounds)]
                         frame:CGRectMake(34, 106, 78, 30)];
    [panel addSubview:self.xField];
    [panel addSubview:[self label:@"Y" frame:CGRectMake(126, 108, 20, 25)]];
    self.yField = [self field:[NSString stringWithFormat:@"%.0f", CGRectGetMidY(self.hostWindow.bounds)]
                         frame:CGRectMake(148, 106, 78, 30)];
    [panel addSubview:self.yField];

    [panel addSubview:[self label:@"INTERVAL (s)" frame:CGRectMake(12, 148, 82, 25)]];
    self.intervalField = [self field:@"0.5" frame:CGRectMake(94, 146, 58, 30)];
    [panel addSubview:self.intervalField];

    [panel addSubview:[self label:@"TOUCH TIME" frame:CGRectMake(166, 148, 86, 25)]];
    self.touchTimeSlider = [[UISlider alloc] initWithFrame:CGRectMake(12, 184, width - 86, 28)];
    self.touchTimeSlider.minimumValue = 0.1f;
    self.touchTimeSlider.maximumValue = 1000.0f;
    self.touchTimeSlider.value = 60.0f;
    [self.touchTimeSlider addTarget:self action:@selector(touchTimeChanged:) forControlEvents:UIControlEventValueChanged];
    [panel addSubview:self.touchTimeSlider];
    self.touchTimeLabel = [self label:@"60.0 ms" frame:CGRectMake(width - 70, 184, 62, 28)];
    self.touchTimeLabel.textAlignment = NSTextAlignmentRight;
    [panel addSubview:self.touchTimeLabel];
    [panel addSubview:[self button:@"−" frame:CGRectMake(12, 216, 42, 28)
                              color:[UIColor colorWithWhite:0.25 alpha:1.0] action:@selector(decreaseTouchTime)]];
    [panel addSubview:[self button:@"+" frame:CGRectMake(60, 216, 42, 28)
                              color:[UIColor colorWithWhite:0.25 alpha:1.0] action:@selector(increaseTouchTime)]];
    [panel addSubview:[self label:@"0.1–1000 ms · press duration" frame:CGRectMake(112, 216, width - 124, 28)]];

    [panel addSubview:[self button:@"ADD POINT" frame:CGRectMake(12, 252, (width - 32) / 2, 34)
                               color:[UIColor colorWithRed:0.18 green:0.38 blue:0.62 alpha:1.0]
                              action:@selector(addPoint)]];
    [panel addSubview:[self button:@"CLEAR POINTS" frame:CGRectMake(20 + (width - 32) / 2, 252, (width - 32) / 2, 34)
                               color:[UIColor colorWithWhite:0.28 alpha:1.0]
                              action:@selector(clearPoints)]];
    self.pointsLabel = [self label:@"Points: 0 · Drag the numbered dots to reposition"
                              frame:CGRectMake(12, 290, width - 24, 22)];
    [panel addSubview:self.pointsLabel];

    [panel addSubview:[self button:@"START" frame:CGRectMake(12, 320, (width - 32) / 2, 38)
                               color:[UIColor colorWithRed:0.12 green:0.58 blue:0.30 alpha:1.0]
                              action:@selector(startTapping)]];
    [panel addSubview:[self button:@"STOP" frame:CGRectMake(20 + (width - 32) / 2, 320, (width - 32) / 2, 38)
                               color:[UIColor colorWithRed:0.72 green:0.18 blue:0.18 alpha:1.0]
                              action:@selector(stopTapping)]];
    self.statusLabel = [self label:@"Ready · No touch sent yet"
                              frame:CGRectMake(12, 364, width - 24, 22)];
    self.statusLabel.numberOfLines = 2;
    self.statusLabel.font = [UIFont systemFontOfSize:10.5];
    [panel addSubview:self.statusLabel];
    self.panelVisible = YES;
}

- (void)addPoint {
    CGPoint point = CGPointMake(self.xField.text.doubleValue, self.yField.text.doubleValue);
    point.x = MIN(MAX(0.0, point.x), CGRectGetWidth(self.hostWindow.bounds));
    point.y = MIN(MAX(0.0, point.y), CGRectGetHeight(self.hostWindow.bounds));
    [self.points addObject:[NSValue valueWithCGPoint:point]];
    [self createMarkerAtPoint:point index:self.points.count - 1];
    self.pointsLabel.text = [NSString stringWithFormat:@"Points: %lu · Drag dots to move", (unsigned long)self.points.count];
    [self.panel endEditing:YES];
}

- (void)createMarkerAtPoint:(CGPoint)point index:(NSUInteger)index {
    UIView *marker = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 30, 30)];
    marker.center = point;
    marker.backgroundColor = [UIColor colorWithRed:1.0 green:0.22 blue:0.18 alpha:0.92];
    marker.layer.cornerRadius = 15.0;
    marker.layer.borderWidth = 2.0;
    marker.layer.borderColor = UIColor.whiteColor.CGColor;
    marker.tag = 0x43484D;
    marker.accessibilityIdentifier = [NSString stringWithFormat:@"%lu", (unsigned long)index];
    UILabel *number = [[UILabel alloc] initWithFrame:marker.bounds];
    number.text = [NSString stringWithFormat:@"%lu", (unsigned long)index + 1];
    number.textAlignment = NSTextAlignmentCenter;
    number.textColor = UIColor.whiteColor;
    number.font = [UIFont boldSystemFontOfSize:12.0];
    [marker addSubview:number];
    marker.userInteractionEnabled = YES;
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(movePointMarker:)];
    [marker addGestureRecognizer:pan];
    [self.hostWindow addSubview:marker];
    [self.pointMarkers addObject:marker];
}

- (void)movePointMarker:(UIPanGestureRecognizer *)gesture {
    UIView *marker = gesture.view;
    CGPoint delta = [gesture translationInView:self.hostWindow];
    CGPoint center = marker.center;
    center.x = MIN(MAX(15.0, center.x + delta.x), CGRectGetWidth(self.hostWindow.bounds) - 15.0);
    center.y = MIN(MAX(15.0, center.y + delta.y), CGRectGetHeight(self.hostWindow.bounds) - 15.0);
    marker.center = center;
    [gesture setTranslation:CGPointZero inView:self.hostWindow];
    NSUInteger index = (NSUInteger)marker.accessibilityIdentifier.integerValue;
    if (index < self.points.count) {
        self.points[index] = [NSValue valueWithCGPoint:center];
    }
    self.xField.text = [NSString stringWithFormat:@"%.0f", center.x];
    self.yField.text = [NSString stringWithFormat:@"%.0f", center.y];
}

- (void)clearPoints {
    [self.points removeAllObjects];
    for (UIView *marker in self.pointMarkers) [marker removeFromSuperview];
    [self.pointMarkers removeAllObjects];
    self.pointsLabel.text = @"Points: 0 · X/Y will be used at START";
}

- (void)touchTimeChanged:(UISlider *)slider {
    self.touchTimeLabel.text = [NSString stringWithFormat:@"%.1f ms", slider.value];
}

- (void)decreaseTouchTime {
    self.touchTimeSlider.value = MAX(0.1f, self.touchTimeSlider.value - 0.1f);
    [self touchTimeChanged:self.touchTimeSlider];
}

- (void)increaseTouchTime {
    self.touchTimeSlider.value = MIN(1000.0f, self.touchTimeSlider.value + 0.1f);
    [self touchTimeChanged:self.touchTimeSlider];
}

- (void)startTapping {
    [self.panel endEditing:YES];
    if (self.points.count == 0) {
        CGPoint point = CGPointMake(self.xField.text.doubleValue, self.yField.text.doubleValue);
        [self.points addObject:[NSValue valueWithCGPoint:point]];
        [self createMarkerAtPoint:point index:0];
        self.pointsLabel.text = @"Points: 1 · Drag the red dot to reposition";
    }

    self.scheduler.points = [self.points copy];
    self.scheduler.mode = (CHMTapMode)MAX(0, self.modeControl.selectedSegmentIndex);
    self.scheduler.interval = MAX(0.0001, self.intervalField.text.doubleValue);
    self.scheduler.holdDuration = MAX(0.0001, self.touchTimeSlider.value / 1000.0);
    self.scheduler.repeatCount = 0;
    [self.scheduler start];
    self.statusLabel.text = self.scheduler.running
        ? @"RUNNING · STOP to finish (delivery not yet verified)"
        : @"START FAILED · Check HID support; see error above";
}

- (void)stopTapping {
    BOOL hadPendingTouch = self.scheduler.hasUnconfirmedTouch;
    [self.scheduler stop];
    if (self.scheduler.hasUnconfirmedTouch) {
        self.statusLabel.text = @"STOPPED · RELEASE UNCONFIRMED";
    } else if (hadPendingTouch) {
        self.statusLabel.text = @"Stopped · UP dispatch path invoked (delivery unverified)";
    } else {
        self.statusLabel.text = @"Stopped";
    }
}

- (void)dealloc {
    if (self.lifecycleObserver) {
        [[NSNotificationCenter defaultCenter] removeObserver:self.lifecycleObserver];
    }
}

- (void)movePanel:(UIPanGestureRecognizer *)gesture {
    CGPoint delta = [gesture translationInView:self.hostWindow];
    CGPoint origin = self.panel.frame.origin;
    origin.x = MIN(MAX(0.0, origin.x + delta.x), CGRectGetWidth(self.hostWindow.bounds) - CGRectGetWidth(self.panel.frame));
    origin.y = MIN(MAX(0.0, origin.y + delta.y), CGRectGetHeight(self.hostWindow.bounds) - CGRectGetHeight(self.panel.frame));
    self.panel.frame = (CGRect){origin, self.panel.frame.size};
    [gesture setTranslation:CGPointZero inView:self.hostWindow];
}

- (void)zoomIn {
    self.panelScale = MIN(1.35, self.panelScale + 0.05);
    self.panel.transform = CGAffineTransformMakeScale(self.panelScale, self.panelScale);
}

- (void)zoomOut {
    self.panelScale = MAX(0.75, self.panelScale - 0.05);
    self.panel.transform = CGAffineTransformMakeScale(self.panelScale, self.panelScale);
}

- (void)moveHandle:(UIPanGestureRecognizer *)gesture {
    CGPoint delta = [gesture translationInView:self.hostWindow];
    CGPoint center = self.handle.center;
    center.x += delta.x;
    center.y += delta.y;
    CGFloat halfW = CGRectGetWidth(self.handle.bounds) * 0.5;
    CGFloat halfH = CGRectGetHeight(self.handle.bounds) * 0.5;
    center.x = MIN(MAX(halfW, center.x), CGRectGetWidth(self.hostWindow.bounds) - halfW);
    center.y = MIN(MAX(halfH, center.y), CGRectGetHeight(self.hostWindow.bounds) - halfH);
    self.handle.center = center;
    [gesture setTranslation:CGPointZero inView:self.hostWindow];
}

@end
