#import "Browser/Modules/Lifecycle/ProjectLifecycleResponseParser.h"

@implementation BabelProjectLifecycleResponseParser

- (NSArray<NSString*>*)restoredProjectIdentifiersFromLifecycleResponse:(NSDictionary*)response {
  NSMutableArray<NSString*>* identifiers = [NSMutableArray array];
  NSArray* results = [response[@"results"] isKindOfClass:NSArray.class] ? response[@"results"] : @[];
  for (NSDictionary* result in results) {
    if (![result isKindOfClass:NSDictionary.class]) {
      continue;
    }

    NSDictionary* payload = [result[@"payload"] isKindOfClass:NSDictionary.class] ? result[@"payload"] : nil;
    NSArray* restored = [payload[@"restored"] isKindOfClass:NSArray.class] ? payload[@"restored"] : @[];
    for (NSString* identifier in restored) {
      if ([identifier isKindOfClass:NSString.class] && identifier.length > 0 &&
          ![identifiers containsObject:identifier]) {
        [identifiers addObject:identifier];
      }
    }
  }

  return identifiers;
}

@end

