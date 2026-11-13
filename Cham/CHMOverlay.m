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
@property (nonatomic, strong) UITextField *holdField;
@property (nonatomic, strong) UISegmentedControl *modeControl;
@property (nonatomic, strong) NSMutableArray<NSValue *> *points;
@property (nonatomic, strong) CHMTapScheduler *scheduler;
@property (nonatomic) BOOL panelVisible;
@end

@implementation CHMOverlay

- (void)attachToApplicationWindow {
    UIWindow *window = nil;
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class]) continue;
        for (UIWindow *candidate in ((UIWindowScene *)scene).windows) {
            if (candidate.isKeyWindow) { window = candidate; break; }
        }
        if (window) break;
    }
    if (!window || self.handle) return;

    self.hostWindow = window;
    self.points = [NSMutableArray array];
    self.scheduler = [[CHMTapScheduler alloc] init];
    __weak typeof(self) weakSelf = self;
    self.scheduler.errorHandler = ^(NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            weakSelf.statusLabel.text = error.localizedDescription;
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
    field.returnKeyType = UIReturnKeyDone;
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
    CGFloat height = 340.0;
    CGFloat y = MIN(CGRectGetMaxY(self.handle.frame) + 10.0,
                    CGRectGetHeight(self.hostWindow.bounds) - height - 12.0);
    UIView *panel = [[UIView alloc] initWithFrame:CGRectMake(12.0, MAX(12.0, y), width, height)];
    panel.backgroundColor = [UIColor colorWithWhite:0.07 alpha:0.97];
    panel.layer.cornerRadius = 14.0;
    panel.layer.borderWidth = 1.0;
    panel.layer.borderColor = [UIColor colorWithWhite:0.32 alpha:1.0].CGColor;
    [self.hostWindow addSubview:panel];
    self.panel = panel;

    UILabel *title = [self label:@"CHAM AUTOCLICKER · TAP MODE" frame:CGRectMake(12, 9, width - 52, 25)];
    title.font = [UIFont boldSystemFontOfSize:13.0];
    [panel addSubview:title];
    [panel addSubview:[self button:@"×" frame:CGRectMake(width - 38, 7, 28, 28)
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
    [panel addSubview:[self label:@"HOLD (s)" frame:CGRectMake(166, 148, 58, 25)]];
    self.holdField = [self field:@"0.1" frame:CGRectMake(226, 146, 58, 30)];
    [panel addSubview:self.holdField];

    [panel addSubview:[self button:@"ADD POINT" frame:CGRectMake(12, 190, (width - 32) / 2, 34)
                               color:[UIColor colorWithRed:0.18 green:0.38 blue:0.62 alpha:1.0]
                              action:@selector(addPoint)]];
    [panel addSubview:[self button:@"CLEAR POINTS" frame:CGRectMake(20 + (width - 32) / 2, 190, (width - 32) / 2, 34)
                               color:[UIColor colorWithWhite:0.28 alpha:1.0]
                              action:@selector(clearPoints)]];
    self.pointsLabel = [self label:@"Points: 0 · Add a point or use X/Y directly"
                              frame:CGRectMake(12, 230, width - 24, 22)];
    [panel addSubview:self.pointsLabel];

    [panel addSubview:[self button:@"START" frame:CGRectMake(12, 264, (width - 32) / 2, 38)
                               color:[UIColor colorWithRed:0.12 green:0.58 blue:0.30 alpha:1.0]
                              action:@selector(startTapping)]];
    [panel addSubview:[self button:@"STOP" frame:CGRectMake(20 + (width - 32) / 2, 264, (width - 32) / 2, 38)
                               color:[UIColor colorWithRed:0.72 green:0.18 blue:0.18 alpha:1.0]
                              action:@selector(stopTapping)]];
    self.statusLabel = [self label:@"Ready · Coordinates are screen points"
                              frame:CGRectMake(12, 308, width - 24, 24)];
    self.statusLabel.numberOfLines = 2;
    self.statusLabel.font = [UIFont systemFontOfSize:11.0];
    [panel addSubview:self.statusLabel];
    self.panelVisible = YES;
}

- (void)addPoint {
    CGPoint point = CGPointMake(self.xField.text.doubleValue, self.yField.text.doubleValue);
    [self.points addObject:[NSValue valueWithCGPoint:point]];
    self.pointsLabel.text = [NSString stringWithFormat:@"Points: %lu · Multi-point sequence", (unsigned long)self.points.count];
    [self.panel endEditing:YES];
}

- (void)clearPoints {
    [self.points removeAllObjects];
    self.pointsLabel.text = @"Points: 0 · X/Y will be used at START";
}

- (void)startTapping {
    [self.panel endEditing:YES];
    if (self.points.count == 0) {
        CGPoint point = CGPointMake(self.xField.text.doubleValue, self.yField.text.doubleValue);
        [self.points addObject:[NSValue valueWithCGPoint:point]];
    }

    self.scheduler.points = [self.points copy];
    self.scheduler.mode = (CHMTapMode)MAX(0, self.modeControl.selectedSegmentIndex);
    self.scheduler.interval = MAX(0.01, self.intervalField.text.doubleValue);
    self.scheduler.holdDuration = MAX(0.05, self.holdField.text.doubleValue);
    self.scheduler.repeatCount = 0;
    [self.scheduler start];
    self.statusLabel.text = self.scheduler.isRunning ? @"Running · Tap STOP to finish" : @"Not started · Check HID availability";
    self.pointsLabel.text = [NSString stringWithFormat:@"Points: %lu · Sequence active", (unsigned long)self.points.count];
}

- (void)stopTapping {
    [self.scheduler stop];
    self.statusLabel.text = @"Stopped";
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
    if (self.panelVisible) {
        CGFloat height = CGRectGetHeight(self.panel.bounds);
        CGFloat y = MIN(CGRectGetMaxY(self.handle.frame) + 10.0,
                        CGRectGetHeight(self.hostWindow.bounds) - height - 12.0);
        self.panel.frame = CGRectMake(12.0, MAX(12.0, y), CGRectGetWidth(self.panel.bounds), height);
    }
}

@end
