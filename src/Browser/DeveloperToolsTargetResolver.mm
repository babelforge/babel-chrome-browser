#import "Browser/DeveloperToolsTargetResolver.h"

@implementation BabelDeveloperToolsTargetResolver

- (NSString*)developerToolsURLStringForInspectedURLString:(NSString*)inspectedURLString
                                                    port:(int)port {
  NSString* targetIdentifier = [self targetIdentifierForURLString:inspectedURLString port:port];
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

/**
 * Finds the remote-debugging target identifier for an inspected page URL.
 *
 * @param inspectedURLString The inspected page URL.
 * @param port The remote debugging port.
 * @return The matching target identifier, or a page fallback when no exact match exists.
 */
- (NSString*)targetIdentifierForURLString:(NSString*)inspectedURLString port:(int)port {
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

    NSString* targetIdentifier = [self targetIdentifierInTargets:(NSArray*)payload
                                              inspectedURLString:inspectedURLString
                                                           port:port];
    if (targetIdentifier) {
      return targetIdentifier;
    }

    [NSThread sleepForTimeInterval:0.1];
  }

  return nil;
}

/**
 * Finds the best target identifier in one remote-debugging target list.
 *
 * @param targets The target dictionaries.
 * @param inspectedURLString The inspected page URL.
 * @param port The remote debugging port.
 * @return The exact target identifier or a fallback page identifier.
 */
- (NSString*)targetIdentifierInTargets:(NSArray*)targets
                    inspectedURLString:(NSString*)inspectedURLString
                                  port:(int)port {
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
        [self shouldIgnoreTargetURLString:urlString port:port]) {
      continue;
    }

    fallbackIdentifier = identifier;
    if ([urlString isEqualToString:inspectedURLString]) {
      return identifier;
    }
  }

  return fallbackIdentifier;
}

/**
 * Reports whether a target URL points to DevTools internals.
 *
 * @param urlString The target URL.
 * @param port The remote debugging port.
 * @return YES when the target must be ignored.
 */
- (BOOL)shouldIgnoreTargetURLString:(NSString*)urlString port:(int)port {
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

@end
