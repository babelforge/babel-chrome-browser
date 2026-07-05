#import "Browser/Tabs/Closing/ClosedTabRestorationPlanner.h"

#import "Browser/UI/Models/BrowserModels.h"

@implementation BabelClosedTabRestorationPlan

@synthesize groupIdentifier;
@synthesize groupName;
@synthesize requestedURLString;
@synthesize navigationURLString;
@synthesize title;

@end

@implementation BabelClosedTabRestorationPlanner {
  NSString* defaultGroupName_;
  BabelStableNavigationURLResolverBlock stableNavigationURLResolver_;
}

- (instancetype)initWithDefaultGroupName:(NSString*)defaultGroupName
             stableNavigationURLResolver:(BabelStableNavigationURLResolverBlock)stableNavigationURLResolver {
  self = [super init];
  if (self) {
    defaultGroupName_ = [defaultGroupName copy] ?: @"";
    stableNavigationURLResolver_ = [stableNavigationURLResolver copy];
  }
  return self;
}

- (BabelClosedTabRestorationPlan*)restorationPlanForClosedTab:(BabelClosedTab*)closedTab {
  if (!closedTab || 0 == closedTab.urlString.length) {
    return nil;
  }

  NSString* requestedURLString = closedTab.requestedURLString ?: closedTab.urlString;
  NSString* navigationURLString = stableNavigationURLResolver_
      ? stableNavigationURLResolver_(requestedURLString)
      : nil;

  BabelClosedTabRestorationPlan* plan = [[BabelClosedTabRestorationPlan alloc] init];
  plan.groupIdentifier = closedTab.groupIdentifier.length > 0
      ? closedTab.groupIdentifier
      : NSUUID.UUID.UUIDString;
  plan.groupName = closedTab.groupName.length > 0 ? closedTab.groupName : defaultGroupName_;
  plan.requestedURLString = requestedURLString;
  plan.navigationURLString = navigationURLString ?: closedTab.urlString;
  plan.title = closedTab.title ?: closedTab.urlString;
  return plan;
}

@end
