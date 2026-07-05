#import "Browser/DragDrop/Session/LocalDropCoordinator.h"

static const NSTimeInterval kBabelPendingLocalDropTimeout = 10.0;

@implementation BabelLocalDropCoordinator {
  NSMutableDictionary<NSNumber*, NSDate*>* pendingLocalDropBrowserIdentifiers_;
}

/**
 * Initializes the local drop coordinator.
 *
 * @return The initialized coordinator.
 */
- (instancetype)init {
  self = [super init];
  if (self) {
    pendingLocalDropBrowserIdentifiers_ = [NSMutableDictionary dictionary];
  }
  return self;
}

- (void)markPendingLocalDropForBrowserIdentifier:(NSNumber*)browserIdentifier {
  if (!browserIdentifier) {
    return;
  }

  pendingLocalDropBrowserIdentifiers_[browserIdentifier] = NSDate.date;
}

- (BOOL)hasPendingLocalDropForBrowserIdentifier:(NSNumber*)browserIdentifier {
  if (!browserIdentifier) {
    return NO;
  }

  NSDate* createdAt = pendingLocalDropBrowserIdentifiers_[browserIdentifier];
  if (!createdAt) {
    return NO;
  }

  if ([NSDate.date timeIntervalSinceDate:createdAt] > kBabelPendingLocalDropTimeout) {
    [pendingLocalDropBrowserIdentifiers_ removeObjectForKey:browserIdentifier];
    return NO;
  }

  return YES;
}

- (void)clearPendingLocalDropForBrowserIdentifier:(NSNumber*)browserIdentifier {
  if (browserIdentifier) {
    [pendingLocalDropBrowserIdentifiers_ removeObjectForKey:browserIdentifier];
  }
}

@end
