#import "App/ApplicationDelegate.h"

#import "App/MainMenuBuilder.h"
#import "Browser/BrowserWindowController.h"

@implementation BabelApplicationDelegate {
  BabelBrowserWindowController* browserWindowController_;
  NSMutableArray<NSURL*>* pendingURLs_;
  NSTimer* startupCollectionTimer_;
  NSWindow* startupWindow_;
  BOOL didOpenInitialURL_;
}

static const NSTimeInterval kStartupInitialCollectionDuration = 2.0;
static const NSTimeInterval kStartupURLQuietDuration = 6.0;
static const NSTimeInterval kStartupWindowMinimumDisplayDuration = 5.0;

- (instancetype)init {
  self = [super init];
  if (self) {
    pendingURLs_ = [NSMutableArray array];
    startupCollectionTimer_ = nil;
    startupWindow_ = nil;
    didOpenInitialURL_ = NO;
    [NSAppleEventManager.sharedAppleEventManager setEventHandler:self
                                                    andSelector:@selector(handleGetURLEvent:
                                                                            withReplyEvent:)
                                                  forEventClass:kInternetEventClass
                                                     andEventID:kAEGetURL];
  }
  return self;
}

- (void)createBrowserWindow {
  [self configureApplicationIcon];
  [self showStartupWindow];
  [BabelMainMenuBuilder installMainMenuWithTarget:self];
  browserWindowController_ = [[BabelBrowserWindowController alloc] init];

  if (pendingURLs_.count > 0) {
    [browserWindowController_ openURLs:[pendingURLs_ copy]];
    [pendingURLs_ removeAllObjects];
    didOpenInitialURL_ = YES;
    [self closeStartupWindowWhenInitialTabsAreReady];
    return;
  }

  [browserWindowController_ openURLs:@[]];
  didOpenInitialURL_ = YES;
  [self closeStartupWindowWhenInitialTabsAreReady];
}

- (void)configureApplicationIcon {
  NSImage* iconImage = [NSImage imageNamed:@"BabelForgeIcon"];
  if (iconImage) {
    NSApp.applicationIconImage = iconImage;
  }
}

- (void)showStartupWindow {
  if (startupWindow_) {
    return;
  }

  NSRect windowFrame = NSMakeRect(0.0, 0.0, 560.0, 470.0);
  startupWindow_ = [[NSWindow alloc] initWithContentRect:windowFrame
                                                styleMask:NSWindowStyleMaskBorderless
                                                  backing:NSBackingStoreBuffered
                                                    defer:NO];
  startupWindow_.opaque = YES;
  startupWindow_.backgroundColor = [NSColor colorWithCalibratedRed:0.955
                                                             green:0.976
                                                              blue:1.0
                                                             alpha:1.0];
  startupWindow_.hasShadow = YES;
  startupWindow_.level = NSFloatingWindowLevel;
  startupWindow_.releasedWhenClosed = NO;

  NSView* backgroundView = [[NSView alloc] initWithFrame:windowFrame];
  backgroundView.wantsLayer = YES;
  backgroundView.layer.backgroundColor = startupWindow_.backgroundColor.CGColor;

  NSImageView* logoView = [[NSImageView alloc] initWithFrame:NSMakeRect(180.0, 190.0, 200.0, 200.0)];
  logoView.image = [NSImage imageNamed:@"BabelForgeIcon"];
  logoView.imageScaling = NSImageScaleProportionallyUpOrDown;
  [backgroundView addSubview:logoView];

  NSTextField* titleLabel = [NSTextField labelWithString:@"BabelForge"];
  titleLabel.frame = NSMakeRect(40.0, 112.0, 480.0, 64.0);
  titleLabel.alignment = NSTextAlignmentCenter;
  titleLabel.font = [NSFont systemFontOfSize:54.0 weight:NSFontWeightBold];
  titleLabel.textColor = [NSColor colorWithCalibratedRed:0.02 green:0.09 blue:0.23 alpha:1.0];
  [backgroundView addSubview:titleLabel];

  NSTextField* subtitleLabel = [NSTextField labelWithString:@"Software, Tools & AI"];
  subtitleLabel.frame = NSMakeRect(40.0, 74.0, 480.0, 32.0);
  subtitleLabel.alignment = NSTextAlignmentCenter;
  subtitleLabel.font = [NSFont systemFontOfSize:22.0 weight:NSFontWeightSemibold];
  subtitleLabel.textColor = [NSColor colorWithCalibratedRed:0.02 green:0.09 blue:0.23 alpha:0.88];
  [backgroundView addSubview:subtitleLabel];

  NSProgressIndicator* progressIndicator =
      [[NSProgressIndicator alloc] initWithFrame:NSMakeRect(258.0, 28.0, 44.0, 16.0)];
  progressIndicator.style = NSProgressIndicatorStyleSpinning;
  progressIndicator.controlSize = NSControlSizeSmall;
  progressIndicator.indeterminate = YES;
  [progressIndicator startAnimation:nil];
  [backgroundView addSubview:progressIndicator];

  startupWindow_.contentView = backgroundView;
  [startupWindow_ center];
  [startupWindow_ orderFrontRegardless];
}

- (void)closeStartupWindowWhenInitialTabsAreReady {
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                               (int64_t)(kStartupWindowMinimumDisplayDuration * NSEC_PER_SEC)),
                 dispatch_get_main_queue(), ^{
    [self closeStartupWindow];
  });
}

- (void)closeStartupWindow {
  if (!startupWindow_) {
    return;
  }

  NSWindow* window = startupWindow_;
  startupWindow_ = nil;
  [NSAnimationContext runAnimationGroup:^(NSAnimationContext* context) {
    context.duration = 0.18;
    window.animator.alphaValue = 0.0;
  } completionHandler:^{
    [window close];
  }];
}

- (void)beginStartupEventCollection {
  [self rescheduleStartupCollectionTimerWithDelay:kStartupInitialCollectionDuration];
}

- (void)rescheduleStartupCollectionTimerWithDelay:(NSTimeInterval)delay {
  [startupCollectionTimer_ invalidate];
  startupCollectionTimer_ = [NSTimer scheduledTimerWithTimeInterval:delay
                                                             target:self
                                                           selector:@selector(finishStartupEventCollection:)
                                                           userInfo:nil
                                                            repeats:NO];
}

- (void)finishStartupEventCollection:(NSTimer*)timer {
  startupCollectionTimer_ = nil;
  [NSApp stop:nil];

  NSEvent* event = [NSEvent otherEventWithType:NSEventTypeApplicationDefined
                                      location:NSZeroPoint
                                 modifierFlags:0
                                     timestamp:NSProcessInfo.processInfo.systemUptime
                                  windowNumber:0
                                       context:nil
                                       subtype:0
                                         data1:0
                                         data2:0];
  [NSApp postEvent:event atStart:NO];
}

- (void)application:(NSApplication*)application openURLs:(NSArray<NSURL*>*)urls {
  [self routeURLs:urls];
}

- (void)application:(NSApplication*)application openFiles:(NSArray<NSString*>*)filenames {
  NSMutableArray<NSURL*>* fileURLs = [NSMutableArray array];
  for (NSString* filename in filenames) {
    if (filename.length == 0) {
      continue;
    }

    [fileURLs addObject:[NSURL fileURLWithPath:filename]];
  }

  if (fileURLs.count > 0) {
    [self routeURLs:fileURLs];
    [application replyToOpenOrPrint:NSApplicationDelegateReplySuccess];
    return;
  }

  [application replyToOpenOrPrint:NSApplicationDelegateReplyFailure];
}

- (void)handleGetURLEvent:(NSAppleEventDescriptor*)event
           withReplyEvent:(NSAppleEventDescriptor*)replyEvent {
  NSString* urlString = [event paramDescriptorForKeyword:keyDirectObject].stringValue;
  if (urlString.length == 0) {
    return;
  }

  NSURL* url = [NSURL URLWithString:urlString];
  if (!url) {
    return;
  }

  [self routeURLs:@[ url ]];
}

- (void)routeURLs:(NSArray<NSURL*>*)urls {
  if (!browserWindowController_) {
    [pendingURLs_ addObjectsFromArray:urls];
    [self rescheduleStartupCollectionTimerWithDelay:kStartupURLQuietDuration];
    return;
  }

  didOpenInitialURL_ = YES;
  [browserWindowController_ openURLs:urls];
}

- (void)applicationDidFinishLaunching:(NSNotification*)notification {
  if (browserWindowController_ && !didOpenInitialURL_) {
    [browserWindowController_ openURLs:@[]];
    didOpenInitialURL_ = YES;
  }
}

- (BOOL)applicationShouldHandleReopen:(NSApplication*)application
                    hasVisibleWindows:(BOOL)hasVisibleWindows {
  [browserWindowController_ showMainWindow];
  return NO;
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication*)sender {
  [self tryToTerminateApplication];
  return NSTerminateCancel;
}

- (BOOL)applicationSupportsSecureRestorableState:(NSApplication*)app {
  return YES;
}

- (void)tryToTerminateApplication {
  [browserWindowController_ requestApplicationTermination];
}

- (void)newTab:(id)sender {
  [browserWindowController_ openNewTab];
}

- (void)newAdjacentTab:(id)sender {
  [browserWindowController_ openAdjacentNewTab];
}

- (void)closeTab:(id)sender {
  [browserWindowController_ closeSelectedTab];
}

- (void)reopenLastClosedTab:(id)sender {
  [browserWindowController_ reopenLastClosedTab];
}

- (void)selectNextTab:(id)sender {
  [browserWindowController_ selectNextTab];
}

- (void)selectPreviousTab:(id)sender {
  [browserWindowController_ selectPreviousTab];
}

- (void)openDeveloperTools:(id)sender {
  [browserWindowController_ openDeveloperToolsForSelectedTab];
}

- (BOOL)validateUserInterfaceItem:(id<NSValidatedUserInterfaceItem>)item {
  if (item.action == @selector(openDeveloperTools:)) {
    return [browserWindowController_ canOpenDeveloperToolsForSelectedTab];
  }
  return YES;
}

- (void)navigateBack:(id)sender {
  [browserWindowController_ navigateSelectedTabBack];
}

- (void)navigateForward:(id)sender {
  [browserWindowController_ navigateSelectedTabForward];
}

- (void)reloadTab:(id)sender {
  [browserWindowController_ reloadSelectedTab];
}

- (void)reloadTabIgnoringCache:(id)sender {
  [browserWindowController_ reloadSelectedTabIgnoringCache];
}

- (void)openHistory:(id)sender {
  [browserWindowController_ openHistoryPage];
}

- (void)openSettings:(id)sender {
  [browserWindowController_ openSettingsPage];
}

- (void)openExtensions:(id)sender {
  [browserWindowController_ openExtensionsPage];
}

@end
