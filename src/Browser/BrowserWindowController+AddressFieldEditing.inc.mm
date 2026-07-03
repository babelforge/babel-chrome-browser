// This file is included by BrowserWindowController.mm.
// It remains in the same translation unit so private Objective-C++ ivars stay accessible.
- (void)navigateFromAddressField:(id)sender {
  if (!selectedTab_) {
    return;
  }

  [self hideOmniboxSuggestions];
  NSString* urlString = [self normalizedURLStringFromAddress:[self addressFieldNavigationString]];
  NSString* requestedURLString = [self stableViewerURLStringForSupportedURLString:urlString] ?: urlString;
  NSString* navigationURLString = [self navigationURLStringForStableBabelChromeURLString:requestedURLString];
  if (navigationURLString.length == 0) {
    if ([stableViewerURLResolver_ isStableViewerURLString:requestedURLString] ||
        [self stableViewerURLStringForSupportedURLString:urlString]) {
      [self updateAddressBarForTab:selectedTab_];
      return;
    }
    navigationURLString = urlString;
  }
  selectedTab_.urlString = navigationURLString;
  selectedTab_.requestedURLString = requestedURLString;
  [self updateAddressBarForTab:selectedTab_];

  if ([selectedTab_ browser]) {
    [selectedTab_ browser]->GetMainFrame()->LoadURL(std::string(navigationURLString.UTF8String));
    [self saveGroupsState];
    return;
  }

  [self selectTab:selectedTab_];
  [self saveGroupsState];
}

- (void)closeSelectedTab {
  if (!selectedTab_) {
    return;
  }

  [self closeTabFromItem:selectedTab_.tabItemView];
}

- (void)controlTextDidEndEditing:(NSNotification*)notification {
  if (notification.object == urlTextField_) {
    [self hideOmniboxSuggestions];
  }

  NSNumber* movement = notification.userInfo[@"NSTextMovement"];
  if (movement.integerValue == NSReturnTextMovement) {
    [self navigateFromAddressField:notification.object];
  }
}

- (void)controlTextDidChange:(NSNotification*)notification {
  if (notification.object != urlTextField_) {
    return;
  }

  [self updateOmniboxSuggestionsForQuery:urlTextField_.stringValue];
}

- (BOOL)control:(NSControl*)control
       textView:(NSTextView*)textView
doCommandBySelector:(SEL)commandSelector {
  if (control != urlTextField_) {
    return NO;
  }

  if (commandSelector == @selector(moveDown:)) {
    [self selectNextOmniboxSuggestion];
    return YES;
  }

  if (commandSelector == @selector(moveUp:)) {
    [self selectPreviousOmniboxSuggestion];
    return YES;
  }

  if (commandSelector == @selector(insertNewline:)) {
    if ([self acceptSelectedOmniboxSuggestion]) {
      return YES;
    }
    [self navigateFromAddressField:control];
    return YES;
  }

  if (commandSelector == @selector(cancelOperation:)) {
    [self hideOmniboxSuggestions];
    urlTextField_.stringValue = selectedTab_ ? [self displayURLStringForTab:selectedTab_] : @"";
    return YES;
  }

  return NO;
}
