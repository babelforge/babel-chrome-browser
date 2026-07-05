#import "Browser/InternalPages/Navigation/InternalNavigationActionParser.h"

NSString* const BabelInternalNavigationActionShow = @"show";
NSString* const BabelInternalNavigationActionSearch = @"search";
NSString* const BabelInternalNavigationActionAddUnpacked = @"addUnpacked";
NSString* const BabelInternalNavigationActionRemove = @"remove";
NSString* const BabelInternalNavigationActionDisableProfile = @"disableProfile";
NSString* const BabelInternalNavigationActionEnableProfile = @"enableProfile";
NSString* const BabelInternalNavigationActionRemoveProfile = @"removeProfile";
NSString* const BabelInternalNavigationActionRestart = @"restart";
NSString* const BabelInternalNavigationActionInstallZip = @"installZip";
NSString* const BabelInternalNavigationActionConfigureUpdateURL = @"configureUpdateURL";
NSString* const BabelInternalNavigationActionConfigureUpdateLocal = @"configureUpdateLocal";
NSString* const BabelInternalNavigationActionCheckUpdates = @"checkUpdates";
NSString* const BabelInternalNavigationActionInstallUpdate = @"installUpdate";
NSString* const BabelInternalNavigationActionInstallSelectedUpdates = @"installSelectedUpdates";
NSString* const BabelInternalNavigationActionEnable = @"enable";
NSString* const BabelInternalNavigationActionDisable = @"disable";
NSString* const BabelInternalNavigationActionModuleDetails = @"module";
NSString* const BabelInternalNavigationActionOpen = @"open";
NSString* const BabelInternalNavigationActionReopen = @"reopen";

@implementation BabelInternalNavigationAction

@synthesize name;
@synthesize value;
@synthesize secondaryValue;
@synthesize values;

@end

@implementation BabelInternalNavigationActionParser

- (BabelInternalNavigationAction*)extensionsActionFromComponents:(NSURLComponents*)components {
  for (NSURLQueryItem* item in components.queryItems) {
    if ([item.name isEqualToString:BabelInternalNavigationActionSearch] && item.value.length > 0) {
      return [self actionWithName:BabelInternalNavigationActionSearch value:item.value];
    }

    if ([item.name isEqualToString:BabelInternalNavigationActionAddUnpacked] && item.value.length > 0) {
      return [self actionWithName:BabelInternalNavigationActionAddUnpacked value:item.value];
    }

    if ([item.name isEqualToString:BabelInternalNavigationActionRemove] && item.value.length > 0) {
      return [self actionWithName:BabelInternalNavigationActionRemove value:item.value];
    }

    if ([item.name isEqualToString:BabelInternalNavigationActionDisableProfile] && item.value.length > 0) {
      return [self actionWithName:BabelInternalNavigationActionDisableProfile value:item.value];
    }

    if ([item.name isEqualToString:BabelInternalNavigationActionEnableProfile] && item.value.length > 0) {
      return [self actionWithName:BabelInternalNavigationActionEnableProfile value:item.value];
    }

    if ([item.name isEqualToString:BabelInternalNavigationActionRemoveProfile] && item.value.length > 0) {
      return [self actionWithName:BabelInternalNavigationActionRemoveProfile value:item.value];
    }

    if ([item.name isEqualToString:BabelInternalNavigationActionRestart] && item.value.length > 0) {
      return [self actionWithName:BabelInternalNavigationActionRestart value:item.value];
    }
  }

  return [self actionWithName:BabelInternalNavigationActionShow value:nil];
}

- (BabelInternalNavigationAction*)modulesActionFromComponents:(NSURLComponents*)components {
  NSMutableArray<NSString*>* updateIdentifiers = [NSMutableArray array];
  BOOL didRequestSelectedUpdateInstall = NO;
  for (NSURLQueryItem* item in components.queryItems) {
    if ([item.name isEqualToString:BabelInternalNavigationActionInstallSelectedUpdates] && item.value.length > 0) {
      didRequestSelectedUpdateInstall = YES;
      continue;
    }

    if ([item.name isEqualToString:@"installUpdates"] && item.value.length > 0) {
      didRequestSelectedUpdateInstall = YES;
      [updateIdentifiers addObject:item.value];
    }
  }

  if (didRequestSelectedUpdateInstall) {
    BabelInternalNavigationAction* action =
        [self actionWithName:BabelInternalNavigationActionInstallSelectedUpdates value:nil];
    action.values = updateIdentifiers;
    return action;
  }

  for (NSURLQueryItem* item in components.queryItems) {
    if ([item.name isEqualToString:BabelInternalNavigationActionInstallZip] && item.value.length > 0) {
      return [self actionWithName:BabelInternalNavigationActionInstallZip value:item.value];
    }

    if ([item.name isEqualToString:BabelInternalNavigationActionConfigureUpdateURL] && item.value.length > 0) {
      return [self actionWithName:BabelInternalNavigationActionConfigureUpdateURL value:item.value];
    }

    if ([item.name isEqualToString:BabelInternalNavigationActionConfigureUpdateLocal] && item.value.length > 0) {
      return [self actionWithName:BabelInternalNavigationActionConfigureUpdateLocal value:item.value];
    }

    if ([item.name isEqualToString:BabelInternalNavigationActionCheckUpdates] && item.value.length > 0) {
      return [self actionWithName:BabelInternalNavigationActionCheckUpdates value:item.value];
    }

    if ([item.name isEqualToString:BabelInternalNavigationActionInstallUpdate] && item.value.length > 0) {
      return [self actionWithName:BabelInternalNavigationActionInstallUpdate value:item.value];
    }

    if ([item.name isEqualToString:BabelInternalNavigationActionEnable] && item.value.length > 0) {
      return [self actionWithName:BabelInternalNavigationActionEnable value:item.value];
    }

    if ([item.name isEqualToString:BabelInternalNavigationActionDisable] && item.value.length > 0) {
      return [self actionWithName:BabelInternalNavigationActionDisable value:item.value];
    }

    if ([item.name isEqualToString:BabelInternalNavigationActionRemove] && item.value.length > 0) {
      return [self actionWithName:BabelInternalNavigationActionRemove value:item.value];
    }

    if ([item.name isEqualToString:BabelInternalNavigationActionModuleDetails] && item.value.length > 0) {
      return [self actionWithName:BabelInternalNavigationActionModuleDetails value:item.value];
    }

    if ([item.name isEqualToString:BabelInternalNavigationActionOpen] && item.value.length > 0) {
      BabelInternalNavigationAction* action =
          [self actionWithName:BabelInternalNavigationActionOpen value:item.value];
      action.secondaryValue = [self routeValueFromComponents:components];
      return action;
    }
  }

  return [self actionWithName:BabelInternalNavigationActionShow value:nil];
}

- (BabelInternalNavigationAction*)historyActionFromComponents:(NSURLComponents*)components {
  for (NSURLQueryItem* item in components.queryItems) {
    if ([item.name isEqualToString:BabelInternalNavigationActionReopen] && item.value.length > 0) {
      return [self actionWithName:BabelInternalNavigationActionReopen value:item.value];
    }
  }

  return [self actionWithName:BabelInternalNavigationActionShow value:nil];
}

- (NSString*)routeValueFromComponents:(NSURLComponents*)components {
  for (NSURLQueryItem* item in components.queryItems) {
    if ([item.name isEqualToString:@"route"] && item.value.length > 0) {
      return item.value;
    }
  }

  return @"index";
}

- (BabelInternalNavigationAction*)actionWithName:(NSString*)name value:(NSString*)value {
  BabelInternalNavigationAction* action = [[BabelInternalNavigationAction alloc] init];
  action.name = name ?: BabelInternalNavigationActionShow;
  action.value = value ?: @"";
  action.secondaryValue = @"";
  action.values = @[];
  return action;
}

@end
