#import "CHMOverlay.h"

@interface CHMOverlay ()
@property (nonatomic, weak) UIWindow *hostWindow;
@property (nonatomic, strong) UIButton *handle;
@property (nonatomic, strong) UILabel *panel;
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

- (void)togglePanel {
    if (self.panelVisible) {
        [self.panel removeFromSuperview];
        self.panel = nil;
        self.panelVisible = NO;
        return;
    }
    UILabel *panel = [[UILabel alloc] initWithFrame:CGRectMake(16.0, CGRectGetMaxY(self.handle.frame) + 10.0, 220.0, 74.0)];
    panel.numberOfLines = 0;
    panel.textAlignment = NSTextAlignmentCenter;
    panel.textColor = UIColor.whiteColor;
    panel.font = [UIFont systemFontOfSize:13.0 weight:UIFontWeightMedium];
    panel.text = @"Cham AutoClicker\nTap engine: ready";
    panel.backgroundColor = [UIColor colorWithWhite:0.08 alpha:0.94];
    panel.layer.cornerRadius = 12.0;
    panel.layer.masksToBounds = YES;
    [self.hostWindow addSubview:panel];
    self.panel = panel;
    self.panelVisible = YES;
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
        self.panel.frame = CGRectMake(16.0, CGRectGetMaxY(self.handle.frame) + 10.0, 220.0, 74.0);
    }
}
@end
