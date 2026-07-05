#import "Browser/Address/Suggestions/OmniboxLocalSuggestionBuilder.h"

NSString* const BabelOmniboxLocalRowTitleKey = @"title";
NSString* const BabelOmniboxLocalRowURLStringKey = @"urlString";
NSString* const BabelOmniboxLocalRowRequestedURLStringKey = @"requestedURLString";
NSString* const BabelOmniboxLocalRowGroupNameKey = @"groupName";
NSString* const BabelOmniboxLocalRowTabIdentifierKey = @"tabIdentifier";

@implementation BabelOmniboxLocalSuggestionBuilder

- (NSArray<NSDictionary*>*)localSuggestionsForQuery:(NSString*)query
                                       openTabRows:(NSArray<NSDictionary*>*)openTabRows
                                     closedTabRows:(NSArray<NSDictionary*>*)closedTabRows
                                      maximumCount:(NSUInteger)maximumCount {
  NSString* trimmedQuery = [query stringByTrimmingCharactersInSet:
      NSCharacterSet.whitespaceAndNewlineCharacterSet];
  if (trimmedQuery.length == 0 || 0 == maximumCount) {
    return @[];
  }

  NSMutableArray<NSDictionary*>* suggestions = [NSMutableArray array];
  NSMutableSet<NSString*>* seenSuggestionKeys = [NSMutableSet set];

  for (NSDictionary* row in openTabRows ?: @[]) {
    if (suggestions.count >= maximumCount) {
      return suggestions;
    }

    NSString* title = [self stringValueForKey:BabelOmniboxLocalRowTitleKey inRow:row];
    NSString* urlString = [self stringValueForKey:BabelOmniboxLocalRowURLStringKey inRow:row];
    NSString* requestedURLString = [self stringValueForKey:BabelOmniboxLocalRowRequestedURLStringKey inRow:row];
    if (![self query:trimmedQuery matchesTitle:title urlString:urlString] &&
        ![self query:trimmedQuery matchesTitle:title urlString:requestedURLString]) {
      continue;
    }

    [self addSuggestionTo:suggestions
                    title:title
                urlString:urlString.length > 0 ? urlString : requestedURLString
                groupName:[self stringValueForKey:BabelOmniboxLocalRowGroupNameKey inRow:row]
            tabIdentifier:[self stringValueForKey:BabelOmniboxLocalRowTabIdentifierKey inRow:row]
                    action:@"focus-tab"
                  seenKeys:seenSuggestionKeys];
  }

  for (NSDictionary* row in closedTabRows ?: @[]) {
    if (suggestions.count >= maximumCount) {
      break;
    }

    NSString* title = [self stringValueForKey:BabelOmniboxLocalRowTitleKey inRow:row];
    NSString* urlString = [self stringValueForKey:BabelOmniboxLocalRowURLStringKey inRow:row];
    NSString* requestedURLString = [self stringValueForKey:BabelOmniboxLocalRowRequestedURLStringKey inRow:row];
    if (![self query:trimmedQuery matchesTitle:title urlString:urlString] &&
        ![self query:trimmedQuery matchesTitle:title urlString:requestedURLString]) {
      continue;
    }

    [self addSuggestionTo:suggestions
                    title:title
                urlString:urlString.length > 0 ? urlString : requestedURLString
                groupName:[self stringValueForKey:BabelOmniboxLocalRowGroupNameKey inRow:row]
            tabIdentifier:@""
                    action:@"navigate"
                  seenKeys:seenSuggestionKeys];
  }

  return suggestions;
}

- (BOOL)query:(NSString*)query matchesTitle:(NSString*)title urlString:(NSString*)urlString {
  NSString* normalizedQuery = query.lowercaseString;
  return [[title ?: @"" lowercaseString] containsString:normalizedQuery] ||
         [[urlString ?: @"" lowercaseString] containsString:normalizedQuery];
}

- (void)addSuggestionTo:(NSMutableArray<NSDictionary*>*)suggestions
                  title:(NSString*)title
              urlString:(NSString*)urlString
              groupName:(NSString*)groupName
          tabIdentifier:(NSString*)tabIdentifier
                  action:(NSString*)action
                seenKeys:(NSMutableSet<NSString*>*)seenKeys {
  if (urlString.length == 0) {
    return;
  }

  NSString* key = [NSString stringWithFormat:@"%@|%@", action ?: @"", tabIdentifier.length > 0 ? tabIdentifier : urlString];
  if ([seenKeys containsObject:key]) {
    return;
  }

  [seenKeys addObject:key];
  [suggestions addObject:@{
    @"title" : title.length > 0 ? title : urlString,
    @"url" : urlString,
    @"group" : groupName.length > 0 ? groupName : @"default",
    @"tabId" : tabIdentifier ?: @"",
    @"action" : action ?: @"navigate",
  }];
}

- (NSString*)stringValueForKey:(NSString*)key inRow:(NSDictionary*)row {
  NSString* value = [row[key] isKindOfClass:NSString.class] ? row[key] : @"";
  return value ?: @"";
}

@end
