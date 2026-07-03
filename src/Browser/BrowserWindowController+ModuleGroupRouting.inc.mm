// This file is included by BrowserWindowController.mm.
// It remains in the same translation unit so private Objective-C++ ivars stay accessible.
- (NSString*)localServiceModuleIdentifierForURLComponents:(NSURLComponents*)components {
  return [moduleActionService_ localServiceModuleIdentifierForURLComponents:components];
}

- (NSString*)defaultGroupNameForModuleIdentifier:(NSString*)moduleIdentifier {
  return [moduleActionService_ defaultGroupNameForModuleIdentifier:moduleIdentifier];
}

- (BabelBrowserGroup*)targetGroupForModuleIdentifier:(NSString*)moduleIdentifier
                                      fallbackGroup:(BabelBrowserGroup*)fallbackGroup {
  NSString* defaultGroupName = [self defaultGroupNameForModuleIdentifier:moduleIdentifier];
  if (defaultGroupName.length > 0) {
    return [self ensureGroupNamed:defaultGroupName];
  }

  return fallbackGroup ?: [self ensureGroupNamed:kDefaultGroupName];
}
