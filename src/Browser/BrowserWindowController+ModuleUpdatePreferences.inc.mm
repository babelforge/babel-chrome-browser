// This file is included by BrowserWindowController.mm.
// It remains in the same translation unit so private Objective-C++ ivars stay accessible.
- (NSURL*)moduleUpdateManifestURLForURLString:(NSString*)urlString {
  NSString* trimmedString =
      [urlString stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
  if (trimmedString.length == 0) {
    return nil;
  }

  NSURL* sourceURL = [NSURL URLWithString:trimmedString];
  if (!sourceURL.scheme.length) {
    return nil;
  }

  if ([sourceURL.path.lastPathComponent isEqualToString:@"modules-release-manifest.json"] ||
      [sourceURL.pathExtension.lowercaseString isEqualToString:@"json"]) {
    return sourceURL;
  }

  NSString* separator = [trimmedString hasSuffix:@"/"] ? @"" : @"/";
  return [NSURL URLWithString:[NSString stringWithFormat:@"%@%@modules-release-manifest.json",
                                                         trimmedString,
                                                         separator]];
}

- (NSString*)moduleUpdateLocalIndexPath {
  return [BabelChromeConfiguration.applicationSupportDirectoryURL.path stringByAppendingPathComponent:kModuleUpdateLocalIndexFilename];
}

- (NSComparisonResult)compareVersion:(NSString*)leftVersion toVersion:(NSString*)rightVersion {
  return [leftVersion compare:rightVersion options:NSNumericSearch];
}

- (NSString*)moduleUpdateURLString {
  NSString* value = [NSUserDefaults.standardUserDefaults stringForKey:kModuleUpdateURLDefaultsKey];
  return [value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] ?: @"";
}

- (NSString*)moduleUpdateLocalDirectoryPath {
  NSString* value = [NSUserDefaults.standardUserDefaults stringForKey:kModuleUpdateLocalDirectoryDefaultsKey];
  return [value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] ?: @"";
}
