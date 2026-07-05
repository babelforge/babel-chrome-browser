#import "Browser/DeveloperTools/Panel/DeveloperToolsPanelController.h"

#import "Browser/UI/Models/BrowserModels.h"
#import "Browser/UI/Views/BrowserViews.h"
#import "Browser/DeveloperTools/Layout/DeveloperToolsLayoutCalculator.h"
#import "Browser/DeveloperTools/Targeting/DeveloperToolsTargetResolver.h"

@implementation BabelDeveloperToolsPanelController {
  BabelDeveloperToolsTargetResolver* targetResolver_;
  BabelDeveloperToolsLayoutCalculator* layoutCalculator_;
  BabelDeveloperToolsBrowserLookupBlock browserLookupBlock_;
  BabelDeveloperToolsCreateBrowserBlock createBrowserBlock_;
  CGFloat toolbarHeight_;
  CGFloat resizeHandleThickness_;
}

- (instancetype)initWithTargetResolver:(BabelDeveloperToolsTargetResolver*)targetResolver
                      layoutCalculator:(BabelDeveloperToolsLayoutCalculator*)layoutCalculator
                    browserLookupBlock:(BabelDeveloperToolsBrowserLookupBlock)browserLookupBlock
                    createBrowserBlock:(BabelDeveloperToolsCreateBrowserBlock)createBrowserBlock
                         toolbarHeight:(CGFloat)toolbarHeight
                 resizeHandleThickness:(CGFloat)resizeHandleThickness {
  self = [super init];
  if (self) {
    targetResolver_ = targetResolver;
    layoutCalculator_ = layoutCalculator;
    browserLookupBlock_ = [browserLookupBlock copy];
    createBrowserBlock_ = [createBrowserBlock copy];
    toolbarHeight_ = toolbarHeight;
    resizeHandleThickness_ = resizeHandleThickness;
  }
  return self;
}

- (void)loadDeveloperToolsForTab:(BabelBrowserTab*)tab
               inspectingBrowser:(CefRefPtr<CefBrowser>)browser
                            port:(int)port {
  if (!tab || !browser) {
    return;
  }

  NSString* inspectedURLString =
      [NSString stringWithUTF8String:browser->GetMainFrame()->GetURL().ToString().c_str()];

  dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
    NSString* developerToolsURLString =
        [targetResolver_ developerToolsURLStringForInspectedURLString:inspectedURLString
                                                                  port:port];

    dispatch_async(dispatch_get_main_queue(), ^{
      if (browserLookupBlock_ && !browserLookupBlock_(browser)) {
        return;
      }

      if ([tab developerToolsBrowser]) {
        [tab developerToolsBrowser]->GetMainFrame()->LoadURL(
            std::string(developerToolsURLString.UTF8String));
        return;
      }

      if (createBrowserBlock_) {
        createBrowserBlock_(tab, developerToolsURLString);
      }
    });
  });
}

- (void)hideDeveloperToolsForTab:(BabelBrowserTab*)tab
                      pagesPanel:(NSView*)pagesPanel
                        dockMode:(NSString*)dockMode
                       sizeRatio:(CGFloat)sizeRatio {
  if (!tab) {
    return;
  }

  [tab setDeveloperToolsBrowser:nullptr];
  [tab.developerToolsHostView setBrowser:nullptr];
  tab.developerToolsSourceWindow = nil;
  tab.developerToolsVisible = NO;
  tab.developerToolsPanelView.hidden = YES;

  NSArray<NSView*>* subviews = [tab.developerToolsHostView.subviews copy];
  for (NSView* subview in subviews) {
    [subview removeFromSuperview];
  }

  [self layoutBrowserViewsForTab:tab
                      pagesPanel:pagesPanel
                        dockMode:dockMode
                       sizeRatio:sizeRatio];
}

- (void)closeDeveloperToolsForTab:(BabelBrowserTab*)tab
                       pagesPanel:(NSView*)pagesPanel
                         dockMode:(NSString*)dockMode
                        sizeRatio:(CGFloat)sizeRatio {
  if (!tab) {
    return;
  }

  CefRefPtr<CefBrowser> developerToolsBrowser = [tab developerToolsBrowser];
  if (developerToolsBrowser) {
    developerToolsBrowser->GetHost()->CloseBrowser(true);
  }
  [self hideDeveloperToolsForTab:tab
                      pagesPanel:pagesPanel
                        dockMode:dockMode
                       sizeRatio:sizeRatio];
}

- (void)reparentDeveloperToolsBrowser:(CefRefPtr<CefBrowser>)browser
                              intoTab:(BabelBrowserTab*)tab
                          ownerWindow:(NSWindow*)ownerWindow {
  NSView* developerToolsView = (__bridge NSView*)browser->GetHost()->GetWindowHandle();
  if (!developerToolsView || !tab.developerToolsHostView) {
    return;
  }

  NSWindow* sourceWindow = developerToolsView.window;
  [developerToolsView removeFromSuperview];
  [tab.developerToolsHostView addSubview:developerToolsView];
  developerToolsView.frame = tab.developerToolsHostView.bounds;
  developerToolsView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;

  if (sourceWindow && sourceWindow != ownerWindow) {
    tab.developerToolsSourceWindow = sourceWindow;
    [self hideExternalDeveloperToolsWindow:sourceWindow ownerWindow:ownerWindow];
  }
}

- (void)layoutBrowserViewsForTab:(BabelBrowserTab*)tab
                      pagesPanel:(NSView*)pagesPanel
                        dockMode:(NSString*)dockMode
                       sizeRatio:(CGFloat)sizeRatio {
  if (!tab || !pagesPanel) {
    return;
  }

  NSRect bounds = pagesPanel.bounds;
  if (!tab.developerToolsVisible) {
    tab.hostView.frame = bounds;
    tab.developerToolsPanelView.frame = NSZeroRect;
    return;
  }

  BabelDeveloperToolsPageLayout* layout =
      [layoutCalculator_ pageLayoutForBounds:bounds
                                    dockMode:dockMode
                                   sizeRatio:sizeRatio];
  tab.hostView.frame = layout.browserFrame;
  tab.developerToolsPanelView.frame = layout.panelFrame;

  [self layoutDeveloperToolsPanelForTab:tab dockMode:dockMode];
  [tab.hostView layoutSubtreeIfNeeded];
  [tab.developerToolsPanelView layoutSubtreeIfNeeded];
}

- (void)hideExternalDeveloperToolsWindow:(NSWindow*)window ownerWindow:(NSWindow*)ownerWindow {
  if (!window || window == ownerWindow) {
    return;
  }

  [window setReleasedWhenClosed:NO];
  [window setIgnoresMouseEvents:YES];
  [window setHasShadow:NO];
  [window setAlphaValue:0.0];
  [window setOpaque:NO];
  [window setFrame:NSMakeRect(-20000.0, -20000.0, 1.0, 1.0) display:NO];
  [window orderOut:nil];

  [self scheduleExternalDeveloperToolsWindowHide:window afterDelay:0.0];
  [self scheduleExternalDeveloperToolsWindowHide:window afterDelay:0.2];
  [self scheduleExternalDeveloperToolsWindowHide:window afterDelay:0.8];
  [self scheduleExternalDeveloperToolsWindowHide:window afterDelay:1.6];
}

- (void)scheduleExternalDeveloperToolsWindowHide:(NSWindow*)window
                                      afterDelay:(NSTimeInterval)delay {
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)),
                 dispatch_get_main_queue(), ^{
    [window setAlphaValue:0.0];
    [window setFrame:NSMakeRect(-20000.0, -20000.0, 1.0, 1.0) display:NO];
    [window orderOut:nil];
  });
}

- (void)layoutDeveloperToolsPanelForTab:(BabelBrowserTab*)tab dockMode:(NSString*)dockMode {
  NSRect panelBounds = tab.developerToolsPanelView.bounds;
  BabelDeveloperToolsPanelLayout* layout =
      [layoutCalculator_ panelLayoutForBounds:panelBounds
                                     dockMode:dockMode
                                toolbarHeight:toolbarHeight_
                        resizeHandleThickness:resizeHandleThickness_];
  tab.developerToolsToolbarView.frame = layout.toolbarFrame;
  tab.developerToolsResizeHandleView.frame = layout.resizeHandleFrame;
  [tab.developerToolsResizeHandleView.window invalidateCursorRectsForView:tab.developerToolsResizeHandleView];
  tab.developerToolsHostView.frame = layout.hostFrame;
  [tab.developerToolsPanelView addSubview:tab.developerToolsHostView
                               positioned:NSWindowBelow
                               relativeTo:tab.developerToolsToolbarView];
  [tab.developerToolsPanelView addSubview:tab.developerToolsToolbarView
                               positioned:NSWindowAbove
                               relativeTo:nil];
  [tab.developerToolsPanelView addSubview:tab.developerToolsResizeHandleView
                               positioned:NSWindowAbove
                               relativeTo:nil];
  [tab.developerToolsHostView layoutSubtreeIfNeeded];
}

@end
