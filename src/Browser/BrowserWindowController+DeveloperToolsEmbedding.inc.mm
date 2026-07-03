// This file is included by BrowserWindowController.mm.
// It remains in the same translation unit so private Objective-C++ ivars stay accessible.
- (void)loadDeveloperToolsForTab:(BabelBrowserTab*)tab
                inspectingBrowser:(CefRefPtr<CefBrowser>)browser {
  int port = BabelChromeConfiguration.remoteDebuggingPort;
  NSString* inspectedURLString =
      [NSString stringWithUTF8String:browser->GetMainFrame()->GetURL().ToString().c_str()];

  dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
    NSString* targetIdentifier =
        [self developerToolsTargetIdentifierForURLString:inspectedURLString port:port];
    NSString* developerToolsURLString =
        [self developerToolsURLStringForTargetIdentifier:targetIdentifier port:port];

    dispatch_async(dispatch_get_main_queue(), ^{
      if (![self tabForBrowser:browser]) {
        return;
      }

      if ([tab developerToolsBrowser]) {
        [tab developerToolsBrowser]->GetMainFrame()->LoadURL(
            std::string(developerToolsURLString.UTF8String));
        return;
      }

      [self createDeveloperToolsBrowserForTab:tab urlString:developerToolsURLString];
    });
  });
}

- (NSString*)developerToolsURLStringForTargetIdentifier:(NSString*)targetIdentifier
                                                  port:(int)port {
  if (!targetIdentifier) {
    return @"data:text/html,<html><body style='font-family:-apple-system;padding:24px'>"
        "Unable to find the inspected page in the local DevTools target list.</body></html>";
  }

  return [NSString stringWithFormat:
      @"http://127.0.0.1:%d/devtools/inspector.html?ws=127.0.0.1:%d/devtools/page/%@&panel=console",
      port,
      port,
      targetIdentifier];
}

- (void)createDeveloperToolsBrowserForTab:(BabelBrowserTab*)tab
                                urlString:(NSString*)urlString {
  pendingDeveloperToolsTab_ = tab;

  CefWindowInfo windowInfo;
  NSRect bounds = tab.developerToolsHostView.bounds;
  windowInfo.SetAsChild((__bridge CefWindowHandle)tab.developerToolsHostView,
                        CefRect(0, 0, bounds.size.width, bounds.size.height));
  windowInfo.runtime_style = CEF_RUNTIME_STYLE_ALLOY;

  CefBrowserSettings settings;
  CefBrowserHost::CreateBrowser(windowInfo,
                                browserClient_,
                                std::string(urlString.UTF8String),
                                settings,
                                nullptr,
                                nullptr);
}

- (NSString*)developerToolsTargetIdentifierForURLString:(NSString*)inspectedURLString
                                                  port:(int)port {
  NSURL* targetsURL = [NSURL URLWithString:
      [NSString stringWithFormat:@"http://127.0.0.1:%d/json/list", port]];
  for (NSUInteger attempt = 0; attempt < 10; attempt++) {
    NSData* data = [NSData dataWithContentsOfURL:targetsURL];
    if (!data) {
      [NSThread sleepForTimeInterval:0.1];
      continue;
    }

    NSError* error = nil;
    id payload = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    if (error || ![payload isKindOfClass:NSArray.class]) {
      [NSThread sleepForTimeInterval:0.1];
      continue;
    }

    NSArray* targets = (NSArray*)payload;
    NSString* fallbackIdentifier = nil;
    for (NSDictionary* target in targets) {
      if (![target isKindOfClass:NSDictionary.class]) {
        continue;
      }

      NSString* type = target[@"type"];
      NSString* urlString = target[@"url"];
      NSString* identifier = target[@"id"];
      if (![type isEqualToString:@"page"] ||
          ![identifier isKindOfClass:NSString.class] ||
          ![urlString isKindOfClass:NSString.class] ||
          [self shouldIgnoreDeveloperToolsTargetURLString:urlString port:port]) {
        continue;
      }

      fallbackIdentifier = identifier;
      if ([urlString isEqualToString:inspectedURLString]) {
        return identifier;
      }
    }

    if (fallbackIdentifier) {
      return fallbackIdentifier;
    }

    [NSThread sleepForTimeInterval:0.1];
  }

  return nil;
}

- (BOOL)shouldIgnoreDeveloperToolsTargetURLString:(NSString*)urlString port:(int)port {
  if ([urlString hasPrefix:@"data:text/html"]) {
    return YES;
  }

  NSURLComponents* components = [NSURLComponents componentsWithString:urlString ?: @""];
  NSString* path = components.path ?: @"";
  NSInteger targetPort = components.port.integerValue;

  return [components.host isEqualToString:@"127.0.0.1"] &&
         targetPort == port &&
         ([path hasPrefix:@"/devtools/"] || [path isEqualToString:@"/json/list"]);
}

- (void)hideDeveloperToolsForTab:(BabelBrowserTab*)tab {
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

  [self layoutBrowserViewsForTab:tab];
}

- (void)closeDeveloperToolsForTab:(BabelBrowserTab*)tab {
  if (!tab) {
    return;
  }

  CefRefPtr<CefBrowser> developerToolsBrowser = [tab developerToolsBrowser];
  if (developerToolsBrowser) {
    developerToolsBrowser->GetHost()->CloseBrowser(true);
  }
  [self hideDeveloperToolsForTab:tab];
}

- (void)reparentDeveloperToolsBrowser:(CefRefPtr<CefBrowser>)browser
                              intoTab:(BabelBrowserTab*)tab {
  NSView* developerToolsView = (__bridge NSView*)browser->GetHost()->GetWindowHandle();
  if (!developerToolsView || !tab.developerToolsHostView) {
    return;
  }

  NSWindow* sourceWindow = developerToolsView.window;
  [developerToolsView removeFromSuperview];
  [tab.developerToolsHostView addSubview:developerToolsView];
  developerToolsView.frame = tab.developerToolsHostView.bounds;
  developerToolsView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
  tab.developerToolsPanelView.hidden = tab != selectedTab_;

  if (sourceWindow && sourceWindow != self.window) {
    tab.developerToolsSourceWindow = sourceWindow;
    [self hideExternalDeveloperToolsWindow:sourceWindow];
  }
}

- (void)hideExternalDeveloperToolsWindow:(NSWindow*)window {
  if (!window || window == self.window) {
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

- (void)layoutBrowserViewsForTab:(BabelBrowserTab*)tab {
  if (!tab) {
    return;
  }

  NSRect bounds = pagesPanel_.bounds;
  if (!tab.developerToolsVisible) {
    tab.hostView.frame = bounds;
    tab.developerToolsPanelView.frame = NSZeroRect;
    return;
  }

  BabelDeveloperToolsPageLayout* layout =
      [developerToolsLayoutCalculator_ pageLayoutForBounds:bounds
                                                  dockMode:developerToolsDockMode_
                                                 sizeRatio:developerToolsSizeRatio_];
  tab.hostView.frame = layout.browserFrame;
  tab.developerToolsPanelView.frame = layout.panelFrame;

  [self layoutDeveloperToolsPanelForTab:tab];
  [tab.hostView layoutSubtreeIfNeeded];
  [tab.developerToolsPanelView layoutSubtreeIfNeeded];
}

- (void)layoutDeveloperToolsPanelForTab:(BabelBrowserTab*)tab {
  NSRect panelBounds = tab.developerToolsPanelView.bounds;
  BabelDeveloperToolsPanelLayout* layout =
      [developerToolsLayoutCalculator_ panelLayoutForBounds:panelBounds
                                                   dockMode:developerToolsDockMode_
                                              toolbarHeight:kDeveloperToolsToolbarHeight
                                      resizeHandleThickness:kDeveloperToolsResizeHandleThickness];
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
