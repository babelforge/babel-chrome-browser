#import "Browser/Tabs/Creation/TabPlacementPolicy.h"

#import "Browser/State/Settings/BrowserSettingsStore.h"

@implementation BabelTabPlacementPolicy

- (BOOL)shouldAppendTabWithParentIdentifier:(NSString*)parentTabIdentifier
                             tabIdentifiers:(NSArray<NSString*>*)tabIdentifiers
                                   strategy:(NSString*)strategy
                     respectingUserStrategy:(BOOL)respectingUserStrategy {
  return parentTabIdentifier.length == 0 ||
         ![tabIdentifiers containsObject:parentTabIdentifier] ||
         (respectingUserStrategy && [strategy isEqualToString:BabelTabOpeningStrategyAppend]);
}

- (NSUInteger)insertionIndexForNewChildOfParentIdentifier:(NSString*)parentTabIdentifier
                                           tabIdentifiers:(NSArray<NSString*>*)tabIdentifiers
                         parentIdentifiersByTabIdentifier:(NSDictionary<NSString*, NSString*>*)parentIdentifiersByTabIdentifier
                                                 strategy:(NSString*)strategy {
  NSUInteger parentIndex = [tabIdentifiers indexOfObject:parentTabIdentifier ?: @""];
  if (parentIndex == NSNotFound) {
    return tabIdentifiers.count;
  }

  if ([strategy isEqualToString:BabelTabOpeningStrategyAfterSelected]) {
    return parentIndex + 1;
  }

  NSUInteger insertionIndex = parentIndex + 1;
  for (NSUInteger index = parentIndex + 1; index < tabIdentifiers.count; index++) {
    NSString* candidateIdentifier = tabIdentifiers[index];
    if (![self tabIdentifier:candidateIdentifier
      descendsFromTabIdentifier:parentTabIdentifier
parentIdentifiersByTabIdentifier:parentIdentifiersByTabIdentifier]) {
      break;
    }
    insertionIndex = index + 1;
  }
  return insertionIndex;
}

- (BOOL)tabIdentifier:(NSString*)tabIdentifier
descendsFromTabIdentifier:(NSString*)parentTabIdentifier
parentIdentifiersByTabIdentifier:(NSDictionary<NSString*, NSString*>*)parentIdentifiersByTabIdentifier {
  NSString* currentParentIdentifier = parentIdentifiersByTabIdentifier[tabIdentifier ?: @""];
  NSMutableSet<NSString*>* seenIdentifiers = [NSMutableSet set];
  while (currentParentIdentifier.length > 0) {
    if ([currentParentIdentifier isEqualToString:parentTabIdentifier]) {
      return YES;
    }

    if ([seenIdentifiers containsObject:currentParentIdentifier]) {
      return NO;
    }
    [seenIdentifiers addObject:currentParentIdentifier];

    currentParentIdentifier = parentIdentifiersByTabIdentifier[currentParentIdentifier] ?: @"";
  }
  return NO;
}

@end
