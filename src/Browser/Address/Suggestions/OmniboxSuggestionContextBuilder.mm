#import "Browser/Address/Suggestions/OmniboxSuggestionContextBuilder.h"

#import "Browser/UI/Models/BrowserModels.h"
#import "Browser/State/Favicons/FaviconStore.h"
#import "Browser/Address/Suggestions/OmniboxLocalSuggestionBuilder.h"

@implementation BabelOmniboxSuggestionContextBuilder

- (NSArray<NSDictionary*>*)openTabRowsForGroups:(NSArray<BabelBrowserGroup*>*)groups
                               defaultGroupName:(NSString*)defaultGroupName
                           internalTabPredicate:(BabelOmniboxInternalTabPredicate)internalTabPredicate {
  NSMutableArray<NSDictionary*>* openTabRows = [NSMutableArray array];
  for (BabelBrowserGroup* group in groups) {
    for (BabelBrowserTab* tab in group.tabs) {
      if (internalTabPredicate && internalTabPredicate(tab)) {
        continue;
      }

      [openTabRows addObject:@{
        BabelOmniboxLocalRowTitleKey : tab.title ?: @"",
        BabelOmniboxLocalRowURLStringKey : tab.urlString ?: @"",
        BabelOmniboxLocalRowRequestedURLStringKey : tab.requestedURLString ?: @"",
        BabelOmniboxLocalRowGroupNameKey : group.name ?: defaultGroupName,
        BabelOmniboxLocalRowTabIdentifierKey : tab.identifier ?: @"",
      }];
    }
  }

  return openTabRows;
}

- (NSArray<NSDictionary*>*)closedTabRowsForClosedTabs:(NSArray<BabelClosedTab*>*)closedTabs
                                     defaultGroupName:(NSString*)defaultGroupName {
  NSMutableArray<NSDictionary*>* closedTabRows = [NSMutableArray array];
  for (NSInteger index = (NSInteger)closedTabs.count - 1; index >= 0; index--) {
    BabelClosedTab* closedTab = closedTabs[(NSUInteger)index];
    [closedTabRows addObject:@{
      BabelOmniboxLocalRowTitleKey : closedTab.title ?: @"",
      BabelOmniboxLocalRowURLStringKey : closedTab.urlString ?: @"",
      BabelOmniboxLocalRowRequestedURLStringKey : closedTab.requestedURLString ?: @"",
      BabelOmniboxLocalRowGroupNameKey : closedTab.groupName ?: defaultGroupName,
      BabelOmniboxLocalRowTabIdentifierKey : @"",
    }];
  }

  return closedTabRows;
}

- (NSImage*)faviconImageForSuggestionTitle:(NSString*)title
                                 urlString:(NSString*)urlString
                              faviconStore:(BabelFaviconStore*)faviconStore {
  NSImage* faviconImage = [faviconStore faviconImageForURLString:urlString];
  if (faviconImage) {
    return faviconImage;
  }

  NSString* normalizedTitle = [self normalizedFaviconLookupString:title];
  if (normalizedTitle.length == 0) {
    return nil;
  }

  return [faviconStore faviconImageMatchingNormalizedTitle:normalizedTitle];
}

- (NSString*)normalizedFaviconLookupString:(NSString*)string {
  NSString* lowercaseString = string.lowercaseString ?: @"";
  NSCharacterSet* charactersToKeep =
      [NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyz0123456789 "];
  NSMutableString* normalizedString = [NSMutableString string];
  BOOL previousWasSpace = YES;
  for (NSUInteger index = 0; index < lowercaseString.length; index++) {
    unichar character = [lowercaseString characterAtIndex:index];
    if (![charactersToKeep characterIsMember:character]) {
      continue;
    }

    if ([[NSCharacterSet whitespaceCharacterSet] characterIsMember:character]) {
      if (!previousWasSpace) {
        [normalizedString appendString:@" "];
      }
      previousWasSpace = YES;
      continue;
    }

    [normalizedString appendFormat:@"%C", character];
    previousWasSpace = NO;
  }

  return [normalizedString stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
}

@end
