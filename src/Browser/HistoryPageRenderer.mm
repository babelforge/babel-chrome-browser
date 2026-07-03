#import "Browser/HistoryPageRenderer.h"

NSString* const BabelHistoryRowTitleKey = @"title";
NSString* const BabelHistoryRowURLStringKey = @"urlString";
NSString* const BabelHistoryRowGroupNameKey = @"groupName";
NSString* const BabelHistoryRowReopenIndexKey = @"reopenIndex";

@implementation BabelHistoryPageRenderer

- (NSString*)historyPageBodyWithOpenTabRows:(NSArray<NSDictionary*>*)openTabRows
                      recentlyClosedTabRows:(NSArray<NSDictionary*>*)recentlyClosedTabRows {
  NSMutableString* body = [NSMutableString string];
  [body appendString:@"<h1>History</h1>"];
  [body appendString:@"<h2>Open Tabs</h2><ul>"];
  for (NSDictionary* row in openTabRows ?: @[]) {
    [body appendFormat:@"<li><span>%@</span><small>%@</small><em>%@</em></li>",
                       [self htmlEscapedString:[self stringValueForKey:BabelHistoryRowTitleKey inRow:row]],
                       [self htmlEscapedString:[self stringValueForKey:BabelHistoryRowURLStringKey inRow:row]],
                       [self htmlEscapedString:[self stringValueForKey:BabelHistoryRowGroupNameKey inRow:row]]];
  }
  [body appendString:@"</ul>"];

  [body appendString:@"<h2>Recently Closed Tabs</h2>"];
  if (recentlyClosedTabRows.count == 0) {
    [body appendString:@"<p class='empty'>No recently closed tab.</p>"];
  } else {
    [body appendString:@"<ul>"];
    for (NSDictionary* row in recentlyClosedTabRows ?: @[]) {
      NSNumber* reopenIndex = [row[BabelHistoryRowReopenIndexKey] isKindOfClass:NSNumber.class]
          ? row[BabelHistoryRowReopenIndexKey]
          : @0;
      [body appendFormat:
          @"<li><span>%@</span><small>%@</small><em>%@</em>"
           "<div class='actions'><a class='smallButton' href='babelchrome://history?reopen=%ld'>Re-open</a></div></li>",
          [self htmlEscapedString:[self stringValueForKey:BabelHistoryRowTitleKey inRow:row]],
          [self htmlEscapedString:[self stringValueForKey:BabelHistoryRowURLStringKey inRow:row]],
          [self htmlEscapedString:[self stringValueForKey:BabelHistoryRowGroupNameKey inRow:row]],
          reopenIndex.longValue];
    }
    [body appendString:@"</ul>"];
  }
  return body;
}

- (NSString*)stringValueForKey:(NSString*)key inRow:(NSDictionary*)row {
  NSString* value = [row[key] isKindOfClass:NSString.class] ? row[key] : @"";
  return value ?: @"";
}

- (NSString*)htmlEscapedString:(NSString*)value {
  NSMutableString* escapedString = [NSMutableString stringWithString:value ?: @""];
  [escapedString replaceOccurrencesOfString:@"&"
                                 withString:@"&amp;"
                                    options:0
                                      range:NSMakeRange(0, escapedString.length)];
  [escapedString replaceOccurrencesOfString:@"<"
                                 withString:@"&lt;"
                                    options:0
                                      range:NSMakeRange(0, escapedString.length)];
  [escapedString replaceOccurrencesOfString:@">"
                                 withString:@"&gt;"
                                    options:0
                                      range:NSMakeRange(0, escapedString.length)];
  [escapedString replaceOccurrencesOfString:@"\""
                                 withString:@"&quot;"
                                    options:0
                                      range:NSMakeRange(0, escapedString.length)];
  return escapedString;
}

@end
