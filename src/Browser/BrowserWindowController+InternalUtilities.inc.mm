// This file is included by BrowserWindowController.mm.
// It remains in the same translation unit so private Objective-C++ ivars stay accessible.
- (NSString*)queryEscapedString:(NSString*)value {
  NSCharacterSet* allowedCharacters = NSCharacterSet.URLQueryAllowedCharacterSet;
  return [value stringByAddingPercentEncodingWithAllowedCharacters:allowedCharacters] ?: @"";
}

- (NSString*)pathEscapedString:(NSString*)value {
  NSCharacterSet* allowedCharacters = NSCharacterSet.URLPathAllowedCharacterSet;
  return [value stringByAddingPercentEncodingWithAllowedCharacters:allowedCharacters] ?: @"";
}

- (NSString*)shellQuotedString:(NSString*)value {
  return [NSString stringWithFormat:@"'%@'",
                                    [value stringByReplacingOccurrencesOfString:@"'"
                                                                     withString:@"'\\''"]];
}

- (NSString*)trashIconHTML {
  return @"<svg class='buttonIcon' viewBox='0 0 24 24' aria-hidden='true'>"
          "<path d='M9 3h6l1 2h4v2H4V5h4l1-2z'/>"
          "<path d='M6 9h12l-1 12H7L6 9zm4 2v8h2v-8h-2zm4 0v8h2v-8h-2z'/>"
          "</svg>";
}

- (NSString*)resourceSVGIconHTMLNamed:(NSString*)resourceName fallback:(NSString*)fallbackHTML {
  NSString* resourcePath = [NSBundle.mainBundle pathForResource:resourceName ofType:@"svg"];
  if (resourcePath.length == 0) {
    return fallbackHTML ?: @"";
  }

  NSError* error = nil;
  NSString* iconHTML = [NSString stringWithContentsOfFile:resourcePath
                                                 encoding:NSUTF8StringEncoding
                                                    error:&error];
  if (error || iconHTML.length == 0) {
    return fallbackHTML ?: @"";
  }

  NSMutableString* normalizedIconHTML = [NSMutableString stringWithString:iconHTML];
  [normalizedIconHTML replaceOccurrencesOfString:@"<svg "
                                      withString:@"<svg class='buttonIcon gearIcon' aria-hidden='true' "
                                         options:0
                                           range:NSMakeRange(0, normalizedIconHTML.length)];
  [normalizedIconHTML replaceOccurrencesOfString:@"fill=\"#17345a\""
                                      withString:@"fill=\"currentColor\""
                                         options:0
                                           range:NSMakeRange(0, normalizedIconHTML.length)];

  return normalizedIconHTML;
}

- (BOOL)isInternalModuleCapability:(NSString*)capability {
  static NSSet<NSString*>* internalCapabilities = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    internalCapabilities = [NSSet setWithArray:@[
      @"app.did-start",
      @"app.will-quit",
      @"drop.local-paths",
      @"settings.section.register"
    ]];
  });

  return [internalCapabilities containsObject:capability ?: @""];
}

- (void)restartApplication {
  NSString* bundlePath = NSBundle.mainBundle.bundlePath;
  if (bundlePath.length == 0) {
    [self requestApplicationTermination];
    return;
  }

  int processIdentifier = NSProcessInfo.processInfo.processIdentifier;
  NSString* script = [NSString stringWithFormat:
      @"while /bin/kill -0 %d 2>/dev/null; do /bin/sleep 0.2; done; /usr/bin/open %@",
      processIdentifier,
      [self shellQuotedString:bundlePath]];

  NSTask* task = [[NSTask alloc] init];
  task.executableURL = [NSURL fileURLWithPath:@"/usr/bin/nohup"];
  task.arguments = @[@"/bin/sh", @"-c", script];
  NSFileHandle* nullHandle = [NSFileHandle fileHandleForWritingAtPath:@"/dev/null"];
  if (nullHandle) {
    task.standardOutput = nullHandle;
    task.standardError = nullHandle;
  }
  [task launchAndReturnError:nil];
  [self requestApplicationTermination];
}

- (NSString*)internalPageHTMLWithTitle:(NSString*)title body:(NSString*)body {
  return [internalPageRenderer_ internalPageHTMLWithTitle:title body:body];
}

- (NSString*)htmlEscapedString:(NSString*)value {
  return [internalPageRenderer_ htmlEscapedString:value];
}
