// This file is included by BrowserWindowController.mm.
// It remains in the same translation unit so private Objective-C++ ivars stay accessible.
- (BOOL)shouldPropagateBrowserClose {
  return isTerminating_;
}

- (void)updateBrowser:(CefRefPtr<CefBrowser>)browser title:(NSString*)title {
  for (BabelBrowserGroup* group in groups_) {
    for (BabelBrowserTab* tab in group.tabs) {
      if ([tab browser] && [tab browser]->IsSame(browser)) {
        BOOL isGeneratedTitle = [title hasPrefix:@"data:"] || [title containsString:@"data:text"];
        tab.title = title.length > 0 && !isGeneratedTitle ? title : tab.urlString;
        tab.tabItemView.title = [self compactTitleForString:tab.title];
        [self saveGroupsState];
        if (tab == selectedTab_) {
          [self updateWindowTitleForSelectedTab];
        }
        return;
      }
    }
  }
}

- (void)updateBrowser:(CefRefPtr<CefBrowser>)browser urlString:(NSString*)urlString {
  for (BabelBrowserGroup* group in groups_) {
    for (BabelBrowserTab* tab in group.tabs) {
      if ([tab browser] && [tab browser]->IsSame(browser)) {
        if ([urlString hasPrefix:@"data:"]) {
          return;
        }

        tab.urlString = urlString;
        if ([self isStableServerURLString:tab.requestedURLString]) {
          tab.requestedURLString = [self stableServerReloadURLStringForTab:tab];
        } else if (![self isStableBabelChromeURLString:tab.requestedURLString] ||
                   ![self isLocalServiceRuntimeURLString:urlString]) {
          tab.requestedURLString = urlString;
        }
        NSNumber* browserIdentifier = @([tab browser]->GetIdentifier());
        NSArray<NSString*>* pendingRefreshURLStrings =
            pendingRefreshURLStringsByBrowserIdentifier_[browserIdentifier];
        if (pendingRefreshURLStrings.count > 0 &&
            ![self isLocalServiceModuleURLString:urlString]) {
          [pendingRefreshURLStringsByBrowserIdentifier_ removeObjectForKey:browserIdentifier];
          [self reloadRequestedURLStrings:pendingRefreshURLStrings excludingTab:tab];
        }
        NSArray<NSString*>* directRefreshURLStrings =
            [self refreshURLStringsForStableURLString:urlString];
        if (directRefreshURLStrings.count > 0) {
          [self reloadRequestedURLStrings:directRefreshURLStrings excludingTab:tab];
        }
        [self saveGroupsState];
        if (tab == selectedTab_ && !urlTextField_.currentEditor) {
          [self updateAddressBarForTab:tab];
        }
        return;
      }
    }
  }
}

- (void)updateBrowser:(CefRefPtr<CefBrowser>)browser statusText:(NSString*)statusText {
  BabelBrowserTab* tab = [self tabForBrowser:browser];
  if (!tab || tab != selectedTab_) {
    return;
  }

  NSString* displayedStatusText = statusText ?: @"";
  linkStatusBarLabel_.stringValue = displayedStatusText;
  linkStatusBarView_.hidden = displayedStatusText.length == 0;
  if (!linkStatusBarView_.hidden) {
    [rightView_ addSubview:linkStatusBarView_
                positioned:NSWindowAbove
                relativeTo:pagesPanel_];
  }
}

- (void)copyURLStringToPasteboard:(NSString*)urlString {
  if (urlString.length == 0) {
    return;
  }

  NSPasteboard* pasteboard = NSPasteboard.generalPasteboard;
  [pasteboard clearContents];
  [pasteboard setString:urlString forType:NSPasteboardTypeString];
}

- (void)updateBrowser:(CefRefPtr<CefBrowser>)browser faviconImage:(NSImage*)faviconImage {
  if (!faviconImage) {
    return;
  }

  for (BabelBrowserGroup* group in groups_) {
    for (BabelBrowserTab* tab in group.tabs) {
      if ([tab browser] && [tab browser]->IsSame(browser)) {
        tab.faviconImage = faviconImage;
        tab.tabItemView.faviconImage = faviconImage;
        [self cacheFaviconImage:faviconImage forURLString:tab.urlString];
        return;
      }
    }
  }
}

- (void)cacheFaviconImage:(NSImage*)faviconImage forURLString:(NSString*)urlString {
  NSString* originKey = [self faviconOriginKeyForURLString:urlString];
  if (originKey.length == 0 || !faviconImage) {
    return;
  }

  faviconImagesByOrigin_[originKey] = faviconImage;
  [self saveFaviconStore];
}

- (NSImage*)faviconImageForURLString:(NSString*)urlString {
  NSString* originKey = [self faviconOriginKeyForURLString:urlString];
  if (originKey.length == 0) {
    return nil;
  }

  return faviconImagesByOrigin_[originKey];
}

- (NSString*)faviconOriginKeyForURLString:(NSString*)urlString {
  if (urlString.length == 0 ||
      [urlString hasPrefix:@"babelchrome://"] ||
      [urlString hasPrefix:@"data:"] ||
      [urlString hasPrefix:@"view-source:"]) {
    return nil;
  }

  NSURLComponents* components = [NSURLComponents componentsWithString:urlString];
  if (components.scheme.length == 0 || components.host.length == 0) {
    return nil;
  }

  NSString* scheme = components.scheme.lowercaseString;
  NSString* host = components.host.lowercaseString;
  if (components.port) {
    return [NSString stringWithFormat:@"%@://%@:%@", scheme, host, components.port];
  }

  return [NSString stringWithFormat:@"%@://%@", scheme, host];
}

- (void)restoreFaviconStore {
  NSData* data = [NSData dataWithContentsOfURL:BabelChromeConfiguration.faviconStoreFileURL];
  if (data.length == 0) {
    return;
  }

  NSDictionary* state = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
  NSDictionary* icons = [state isKindOfClass:NSDictionary.class] ? state[@"icons"] : nil;
  if (![icons isKindOfClass:NSDictionary.class]) {
    return;
  }

  for (NSString* originKey in icons) {
    NSString* base64Icon = icons[originKey];
    if (![originKey isKindOfClass:NSString.class] ||
        ![base64Icon isKindOfClass:NSString.class]) {
      continue;
    }

    NSData* iconData = [[NSData alloc] initWithBase64EncodedString:base64Icon options:0];
    NSImage* iconImage = [[NSImage alloc] initWithData:iconData];
    if (!iconImage) {
      continue;
    }

    iconImage.size = NSMakeSize(16.0, 16.0);
    faviconImagesByOrigin_[originKey] = iconImage;
  }
}

- (void)saveFaviconStore {
  NSMutableDictionary<NSString*, NSString*>* encodedIcons = [NSMutableDictionary dictionary];
  for (NSString* originKey in faviconImagesByOrigin_) {
    NSString* base64Icon = [self PNGBase64StringForImage:faviconImagesByOrigin_[originKey]];
    if (base64Icon.length == 0) {
      continue;
    }

    encodedIcons[originKey] = base64Icon;
  }

  NSDictionary* state = @{@"icons": encodedIcons};
  NSURL* storeURL = BabelChromeConfiguration.faviconStoreFileURL;
  [NSFileManager.defaultManager createDirectoryAtURL:storeURL.URLByDeletingLastPathComponent
                         withIntermediateDirectories:YES
                                          attributes:nil
                                               error:nil];
  NSData* data = [NSJSONSerialization dataWithJSONObject:state
                                                 options:NSJSONWritingPrettyPrinted
                                                   error:nil];
  [data writeToURL:storeURL atomically:YES];
}

- (NSString*)PNGBase64StringForImage:(NSImage*)image {
  NSData* TIFFData = image.TIFFRepresentation;
  if (TIFFData.length == 0) {
    return nil;
  }

  NSBitmapImageRep* imageRep = [NSBitmapImageRep imageRepWithData:TIFFData];
  NSData* PNGData = [imageRep representationUsingType:NSBitmapImageFileTypePNG
                                           properties:@{}];
  return [PNGData base64EncodedStringWithOptions:0];
}
