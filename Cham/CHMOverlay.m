#import "CHMOverlay.h"
#import "CHMTapScheduler.h"

static NSString * const CHMSettingsKey = @"com.cham.autoclicker.settings.v1";
static NSInteger const CHMOverlayTag = 0x43484D;

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
@property (nonatomic, strong) NSMutableArray<NSValue *> *points;
@property (nonatomic, strong) NSMutableArray<UIView *> *pointMarkers;
@property (nonatomic, strong) CHMTapScheduler *scheduler;
@property (nonatomic) BOOL panelVisible;
@property (nonatomic) CGFloat panelScale;
@property (nonatomic) CGPoint savedPanelOrigin;
@property (nonatomic) BOOL hasSavedPanelOrigin;
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
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    NSDictionary *saved = [defaults dictionaryForKey:CHMSettingsKey] ?: @{};
    self.points = [NSMutableArray array];
    self.pointMarkers = [NSMutableArray array];
    self.panelScale = [saved[@"panelScale"] respondsToSelector:@selector(doubleValue)]
        ? [saved[@"panelScale"] doubleValue] : 1.0;
    self.panelScale = MIN(1.35, MAX(0.75, self.panelScale));
    NSArray *savedPoints = [saved[@"points"] isKindOfClass:NSArray.class] ? saved[@"points"] : @[];
    for (NSDictionary *item in savedPoints) {
        if (![item isKindOfClass:NSDictionary.class] ||
            ![item[@"x"] respondsToSelector:@selector(doubleValue)] ||
            ![item[@"y"] respondsToSelector:@selector(doubleValue)]) continue;
        CGPoint point = CGPointMake([item[@"x"] doubleValue], [item[@"y"] doubleValue]);
        point.x = MIN(MAX(0.0, point.x), CGRectGetWidth(window.bounds));
        point.y = MIN(MAX(0.0, point.y), CGRectGetHeight(window.bounds));
        [self.points addObject:[NSValue valueWithCGPoint:point]];
    }
    if ([saved[@"panelX"] respondsToSelector:@selector(doubleValue)] &&
        [saved[@"panelY"] respondsToSelector:@selector(doubleValue)]) {
        self.savedPanelOrigin = CGPointMake([saved[@"panelX"] doubleValue], [saved[@"panelY"] doubleValue]);
        self.hasSavedPanelOrigin = YES;
    }

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
        (void)note;
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        BOOL hadPendingTouch = self.scheduler.hasUnconfirmedTouch;
        BOOL wasRunning = self.scheduler.running;
        [self.scheduler stop];
        if (self.scheduler.hasUnconfirmedTouch) {
            self.statusLabel.text = @"STOPPED · RELEASE UNCONFIRMED";
        } else if (hadPendingTouch) {
            self.statusLabel.text = @"Stopped · release requested";
        } else if (wasRunning) {
            self.statusLabel.text = @"App inactive · stopped";
        }
    }];

    self.scheduler = [[CHMTapScheduler alloc] init];
    self.scheduler.errorHandler = ^(NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            weakSelf.statusLabel.text = [NSString stringWithFormat:@"ERROR · %@", error.localizedDescription];
        });
    };

    UIButton *handle = [UIButton buttonWithType:UIButtonTypeSystem];
    CGFloat defaultX = MAX(12.0, CGRectGetWidth(window.bounds) - 72.0);
    CGFloat handleX = [saved[@"handleX"] respondsToSelector:@selector(doubleValue)]
        ? [saved[@"handleX"] doubleValue] : defaultX;
    CGFloat handleY = [saved[@"handleY"] respondsToSelector:@selector(doubleValue)]
        ? [saved[@"handleY"] doubleValue] : window.safeAreaInsets.top + 90.0;
    handle.frame = CGRectMake(handleX, handleY, 56.0, 56.0);
    handle.frame = [self clampedFrame:handle.frame inBounds:window.bounds];
    handle.tag = CHMOverlayTag;
    handle.backgroundColor = [UIColor colorWithRed:0.31 green:0.28 blue:0.96 alpha:0.98];
    handle.layer.cornerRadius = 19.0;
    handle.layer.borderWidth = 1.0;
    handle.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.28].CGColor;
    handle.layer.shadowColor = UIColor.blackColor.CGColor;
    handle.layer.shadowOpacity = 0.28;
    handle.layer.shadowRadius = 9.0;
    handle.layer.shadowOffset = CGSizeMake(0, 4);
    [handle setTitle:@"CHAM" forState:UIControlStateNormal];
    [handle setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    handle.titleLabel.font = [UIFont boldSystemFontOfSize:12.0];
    [handle addTarget:self action:@selector(togglePanel) forControlEvents:UIControlEventTouchUpInside];
    [window addSubview:handle];
    self.handle = handle;

    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(moveHandle:)];
    [handle addGestureRecognizer:pan];
    for (NSUInteger index = 0; index < self.points.count; index++) {
        [self createMarkerAtPoint:self.points[index].CGPointValue index:index];
    }
    [self saveSettings];
}

- (CGRect)clampedFrame:(CGRect)frame inBounds:(CGRect)bounds {
    CGFloat maxX = MAX(0.0, CGRectGetWidth(bounds) - CGRectGetWidth(frame));
    CGFloat maxY = MAX(0.0, CGRectGetHeight(bounds) - CGRectGetHeight(frame));
    frame.origin.x = MIN(MAX(0.0, frame.origin.x), maxX);
    frame.origin.y = MIN(MAX(0.0, frame.origin.y), maxY);
    return frame;
}

- (void)saveSettings {
    if (!self.hostWindow) return;
    NSMutableArray *savedPoints = [NSMutableArray arrayWithCapacity:self.points.count];
    for (NSValue *value in self.points) {
        CGPoint point = value.CGPointValue;
        [savedPoints addObject:@{@"x": @(point.x), @"y": @(point.y)}];
    }

    NSMutableDictionary *settings = [@{
        @"points": savedPoints,
        @"x": @(self.xField.text.doubleValue),
        @"y": @(self.yField.text.doubleValue),
        @"interval": @(MAX(0.01, self.intervalField.text.doubleValue)),
        @"touchTime": @(self.touchTimeSlider ? self.touchTimeSlider.value : 60.0),
        @"handleX": @(self.handle.frame.origin.x),
        @"handleY": @(self.handle.frame.origin.y),
        @"panelScale": @(self.panelScale)
    } mutableCopy];
    if (self.panel) {
        settings[@"panelX"] = @(self.panel.frame.origin.x);
        settings[@"panelY"] = @(self.panel.frame.origin.y);
    } else if (self.hasSavedPanelOrigin) {
        settings[@"panelX"] = @(self.savedPanelOrigin.x);
        settings[@"panelY"] = @(self.savedPanelOrigin.y);
    }
    [NSUserDefaults.standardUserDefaults setObject:settings forKey:CHMSettingsKey];
}

- (UILabel *)label:(NSString *)text frame:(CGRect)frame {
    UILabel *label = [[UILabel alloc] initWithFrame:frame];
    label.text = text;
    label.textColor = UIColor.whiteColor;
    label.font = [UIFont systemFontOfSize:12.0 weight:UIFontWeightSemibold];
    return label;
}

- (UITextField *)field:(NSString *)value frame:(CGRect)frame {
    UITextField *field = [[UITextField alloc] initWithFrame:frame];
    field.text = value;
    field.textColor = UIColor.whiteColor;
    field.font = [UIFont monospacedDigitSystemFontOfSize:14.0 weight:UIFontWeightSemibold];
    field.textAlignment = NSTextAlignmentCenter;
    field.keyboardType = UIKeyboardTypeDecimalPad;
    field.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.10];
    field.layer.cornerRadius = 9.0;
    field.layer.borderWidth = 1.0;
    field.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.14].CGColor;
    [field addTarget:self action:@selector(settingEdited:) forControlEvents:UIControlEventEditingChanged];
    return field;
}

- (UIButton *)button:(NSString *)title frame:(CGRect)frame color:(UIColor *)color action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.frame = frame;
    button.backgroundColor = color;
    button.layer.cornerRadius = 11.0;
    [button setTitle:title forState:UIControlStateNormal];
    [button setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont boldSystemFontOfSize:13.0];
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (void)togglePanel {
    if (self.panelVisible) {
        [self.panel endEditing:YES];
        [self saveSettings];
        [self.panel removeFromSuperview];
        self.panel = nil;
        self.panelVisible = NO;
        return;
    }

    CGFloat width = MIN(326.0, CGRectGetWidth(self.hostWindow.bounds) - 24.0);
    CGFloat height = 370.0;
    CGPoint origin = self.hasSavedPanelOrigin
        ? self.savedPanelOrigin
        : CGPointMake(12.0, MIN(CGRectGetMaxY(self.handle.frame) + 10.0,
                               CGRectGetHeight(self.hostWindow.bounds) - height - 12.0));
    UIView *panel = [[UIView alloc] initWithFrame:[self clampedFrame:CGRectMake(origin.x, origin.y, width, height)
                                                            inBounds:self.hostWindow.bounds]];
    panel.tag = CHMOverlayTag;
    panel.backgroundColor = [UIColor colorWithRed:0.055 green:0.065 blue:0.12 alpha:0.98];
    panel.layer.cornerRadius = 20.0;
    panel.layer.borderWidth = 1.0;
    panel.layer.borderColor = [UIColor colorWithRed:0.42 green:0.40 blue:1.0 alpha:0.48].CGColor;
    panel.layer.shadowColor = UIColor.blackColor.CGColor;
    panel.layer.shadowOpacity = 0.32;
    panel.layer.shadowRadius = 16.0;
    panel.layer.shadowOffset = CGSizeMake(0, 8);
    [self.hostWindow addSubview:panel];
    self.panel = panel;

    UIView *accent = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, 4)];
    accent.backgroundColor = [UIColor colorWithRed:0.40 green:0.34 blue:1.0 alpha:1.0];
    accent.layer.cornerRadius = 2.0;
    [panel addSubview:accent];

    UILabel *title = [self label:@"CHAM  /  POINT" frame:CGRectMake(16, 12, width - 126, 26)];
    title.font = [UIFont boldSystemFontOfSize:15.0];
    title.userInteractionEnabled = YES;
    [panel addSubview:title];
    [title addGestureRecognizer:[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(movePanel:)]];
    [panel addSubview:[self button:@"−" frame:CGRectMake(width - 104, 10, 28, 28)
                              color:[UIColor colorWithWhite:1.0 alpha:0.10] action:@selector(zoomOut)]];
    [panel addSubview:[self button:@"+" frame:CGRectMake(width - 70, 10, 28, 28)
                              color:[UIColor colorWithWhite:1.0 alpha:0.10] action:@selector(zoomIn)]];
    [panel addSubview:[self button:@"×" frame:CGRectMake(width - 36, 10, 28, 28)
                              color:[UIColor colorWithRed:0.85 green:0.20 blue:0.30 alpha:0.9] action:@selector(togglePanel)]];

    UILabel *coordinateTitle = [self label:@"TAP COORDINATES" frame:CGRectMake(16, 48, width - 32, 18)];
    coordinateTitle.textColor = [UIColor colorWithWhite:1.0 alpha:0.68];
    coordinateTitle.font = [UIFont boldSystemFontOfSize:10.0];
    [panel addSubview:coordinateTitle];

    NSDictionary *saved = [NSUserDefaults.standardUserDefaults dictionaryForKey:CHMSettingsKey] ?: @{};
    CGFloat defaultX = CGRectGetMidX(self.hostWindow.bounds);
    CGFloat defaultY = CGRectGetMidY(self.hostWindow.bounds);
    self.xField = [self field:[NSString stringWithFormat:@"%.0f",
                               [saved[@"x"] respondsToSelector:@selector(doubleValue)] ? [saved[@"x"] doubleValue] : defaultX]
                         frame:CGRectMake(16, 70, (width - 44) / 2, 38)];
    self.yField = [self field:[NSString stringWithFormat:@"%.0f",
                               [saved[@"y"] respondsToSelector:@selector(doubleValue)] ? [saved[@"y"] doubleValue] : defaultY]
                         frame:CGRectMake(28 + (width - 44) / 2, 70, (width - 44) / 2, 38)];
    [panel addSubview:self.xField];
    [panel addSubview:self.yField];

    UILabel *intervalTitle = [self label:@"INTERVAL  (SECONDS)" frame:CGRectMake(16, 122, 150, 18)];
    intervalTitle.textColor = [UIColor colorWithWhite:1.0 alpha:0.68];
    intervalTitle.font = [UIFont boldSystemFontOfSize:10.0];
    [panel addSubview:intervalTitle];
    self.intervalField = [self field:[NSString stringWithFormat:@"%.3g",
                                      [saved[@"interval"] respondsToSelector:@selector(doubleValue)] ? [saved[@"interval"] doubleValue] : 0.5]
                                frame:CGRectMake(16, 144, 104, 36)];
    [panel addSubview:self.intervalField];

    UILabel *touchTitle = [self label:@"PRESS DURATION" frame:CGRectMake(140, 122, width - 156, 18)];
    touchTitle.textColor = [UIColor colorWithWhite:1.0 alpha:0.68];
    touchTitle.font = [UIFont boldSystemFontOfSize:10.0];
    [panel addSubview:touchTitle];
    self.touchTimeSlider = [[UISlider alloc] initWithFrame:CGRectMake(136, 148, width - 158, 28)];
    self.touchTimeSlider.minimumValue = 0.1f;
    self.touchTimeSlider.maximumValue = 1000.0f;
    self.touchTimeSlider.value = [saved[@"touchTime"] respondsToSelector:@selector(floatValue)]
        ? [saved[@"touchTime"] floatValue] : 60.0f;
    [self.touchTimeSlider addTarget:self action:@selector(touchTimeChanged:) forControlEvents:UIControlEventValueChanged];
    [panel addSubview:self.touchTimeSlider];
    self.touchTimeLabel = [self label:[NSString stringWithFormat:@"%.1f ms", self.touchTimeSlider.value]
                                frame:CGRectMake(width - 64, 174, 48, 18)];
    self.touchTimeLabel.font = [UIFont systemFontOfSize:10.0 weight:UIFontWeightMedium];
    self.touchTimeLabel.textAlignment = NSTextAlignmentRight;
    self.touchTimeLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.72];
    [panel addSubview:self.touchTimeLabel];

    [panel addSubview:[self button:@"ADD POINT" frame:CGRectMake(16, 202, (width - 44) / 2, 34)
                              color:[UIColor colorWithRed:0.24 green:0.32 blue:0.82 alpha:1.0] action:@selector(addPoint)]];
    [panel addSubview:[self button:@"CLEAR" frame:CGRectMake(28 + (width - 44) / 2, 202, (width - 44) / 2, 34)
                              color:[UIColor colorWithWhite:1.0 alpha:0.12] action:@selector(clearPoints)]];
    self.pointsLabel = [self label:@"" frame:CGRectMake(16, 244, width - 32, 20)];
    self.pointsLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.72];
    [panel addSubview:self.pointsLabel];
    [self updatePointsLabel];

    [panel addSubview:[self button:@"START" frame:CGRectMake(16, 278, (width - 44) / 2, 42)
                              color:[UIColor colorWithRed:0.10 green:0.62 blue:0.38 alpha:1.0] action:@selector(startTapping)]];
    [panel addSubview:[self button:@"STOP" frame:CGRectMake(28 + (width - 44) / 2, 278, (width - 44) / 2, 42)
                              color:[UIColor colorWithRed:0.78 green:0.20 blue:0.29 alpha:1.0] action:@selector(stopTapping)]];
    self.statusLabel = [self label:@"READY  ·  Add a point to begin" frame:CGRectMake(16, 330, width - 32, 24)];
    self.statusLabel.font = [UIFont systemFontOfSize:10.5 weight:UIFontWeightMedium];
    self.statusLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.72];
    self.statusLabel.numberOfLines = 2;
    [panel addSubview:self.statusLabel];
    self.panelVisible = YES;
    self.panel.transform = CGAffineTransformMakeScale(self.panelScale, self.panelScale);
    [self saveSettings];
}

- (void)settingEdited:(UITextField *)field {
    (void)field;
    [self saveSettings];
}

- (void)updatePointsLabel {
    self.pointsLabel.text = [NSString stringWithFormat:@"%lu POINT  ·  Drag markers to move",
                             (unsigned long)self.points.count];
}

- (void)addPoint {
    CGPoint point = CGPointMake(self.xField.text.doubleValue, self.yField.text.doubleValue);
    point.x = MIN(MAX(0.0, point.x), CGRectGetWidth(self.hostWindow.bounds));
    point.y = MIN(MAX(0.0, point.y), CGRectGetHeight(self.hostWindow.bounds));
    [self.points addObject:[NSValue valueWithCGPoint:point]];
    [self createMarkerAtPoint:point index:self.points.count - 1];
    [self updatePointsLabel];
    [self.panel endEditing:YES];
    [self saveSettings];
}

- (void)createMarkerAtPoint:(CGPoint)point index:(NSUInteger)index {
    UIView *marker = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 30, 30)];
    marker.center = point;
    marker.backgroundColor = [UIColor colorWithRed:1.0 green:0.25 blue:0.34 alpha:0.96];
    marker.layer.cornerRadius = 15.0;
    marker.layer.borderWidth = 2.0;
    marker.layer.borderColor = UIColor.whiteColor.CGColor;
    marker.layer.shadowColor = UIColor.blackColor.CGColor;
    marker.layer.shadowOpacity = 0.25;
    marker.layer.shadowRadius = 5.0;
    marker.tag = CHMOverlayTag;
    marker.accessibilityIdentifier = [NSString stringWithFormat:@"%lu", (unsigned long)index];
    UILabel *number = [[UILabel alloc] initWithFrame:marker.bounds];
    number.text = [NSString stringWithFormat:@"%lu", (unsigned long)index + 1];
    number.textAlignment = NSTextAlignmentCenter;
    number.textColor = UIColor.whiteColor;
    number.font = [UIFont boldSystemFontOfSize:12.0];
    [marker addSubview:number];
    marker.userInteractionEnabled = YES;
    [marker addGestureRecognizer:[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(movePointMarker:)]];
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
        self.xField.text = [NSString stringWithFormat:@"%.0f", center.x];
        self.yField.text = [NSString stringWithFormat:@"%.0f", center.y];
        [self saveSettings];
    }
}

- (void)clearPoints {
    [self.points removeAllObjects];
    for (UIView *marker in self.pointMarkers) [marker removeFromSuperview];
    [self.pointMarkers removeAllObjects];
    [self updatePointsLabel];
    [self saveSettings];
}

- (void)touchTimeChanged:(UISlider *)slider {
    self.touchTimeLabel.text = [NSString stringWithFormat:@"%.1f ms", slider.value];
    [self saveSettings];
}

- (void)startTapping {
    [self.panel endEditing:YES];
    if (self.points.count == 0) {
        CGPoint point = CGPointMake(self.xField.text.doubleValue, self.yField.text.doubleValue);
        point.x = MIN(MAX(0.0, point.x), CGRectGetWidth(self.hostWindow.bounds));
        point.y = MIN(MAX(0.0, point.y), CGRectGetHeight(self.hostWindow.bounds));
        [self.points addObject:[NSValue valueWithCGPoint:point]];
        [self createMarkerAtPoint:point index:0];
        [self updatePointsLabel];
    }

    [self saveSettings];
    self.scheduler.points = [self.points copy];
    self.scheduler.interval = MAX(0.01, self.intervalField.text.doubleValue);
    self.scheduler.pressDuration = MAX(0.0001, self.touchTimeSlider.value / 1000.0);
    [self.scheduler start];
    self.statusLabel.text = self.scheduler.running
        ? @"RUNNING  ·  STOP to finish"
        : @"START FAILED  ·  Check touch support";
}

- (void)stopTapping {
    BOOL hadPendingTouch = self.scheduler.hasUnconfirmedTouch;
    [self.scheduler stop];
    if (self.scheduler.hasUnconfirmedTouch) {
        self.statusLabel.text = @"STOPPED  ·  RELEASE UNCONFIRMED";
    } else if (hadPendingTouch) {
        self.statusLabel.text = @"STOPPED  ·  Release requested";
    } else {
        self.statusLabel.text = @"STOPPED";
    }
}

- (void)movePanel:(UIPanGestureRecognizer *)gesture {
    CGPoint delta = [gesture translationInView:self.hostWindow];
    CGPoint origin = self.panel.frame.origin;
    origin.x += delta.x;
    origin.y += delta.y;
    CGRect frame = self.panel.frame;
    frame.origin = origin;
    self.panel.frame = [self clampedFrame:frame inBounds:self.hostWindow.bounds];
    [gesture setTranslation:CGPointZero inView:self.hostWindow];
    if (gesture.state == UIGestureRecognizerStateEnded) {
        self.savedPanelOrigin = self.panel.frame.origin;
        self.hasSavedPanelOrigin = YES;
        [self saveSettings];
    }
}

- (void)zoomIn {
    self.panelScale = MIN(1.35, self.panelScale + 0.05);
    self.panel.transform = CGAffineTransformMakeScale(self.panelScale, self.panelScale);
    [self saveSettings];
}

- (void)zoomOut {
    self.panelScale = MAX(0.75, self.panelScale - 0.05);
    self.panel.transform = CGAffineTransformMakeScale(self.panelScale, self.panelScale);
    [self saveSettings];
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
    if (gesture.state == UIGestureRecognizerStateEnded) [self saveSettings];
}

- (void)dealloc {
    if (self.lifecycleObserver) {
        [[NSNotificationCenter defaultCenter] removeObserver:self.lifecycleObserver];
    }
}

@end
