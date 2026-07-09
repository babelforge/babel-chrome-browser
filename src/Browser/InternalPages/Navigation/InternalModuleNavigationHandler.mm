#import "Browser/InternalPages/Navigation/InternalModuleNavigationHandler.h"

#import "Browser/InternalPages/Navigation/InternalNavigationActionParser.h"
#import "Browser/Modules/Navigation/ModuleUIActionCoordinator.h"

NSString* const BabelInternalModuleNavigationDestinationModules = @"modules";
NSString* const BabelInternalModuleNavigationDestinationUpdates = @"updates";
NSString* const BabelInternalModuleNavigationDestinationDetails = @"details";
NSString* const BabelInternalModuleNavigationDestinationOpenModule = @"open-module";

@implementation BabelInternalModuleNavigationResult

@synthesize fileTypeCapabilitiesDidChange;
@synthesize destination;
@synthesize moduleIdentifier;
@synthesize route;

+ (instancetype)resultWithDestination:(NSString*)destination
                capabilitiesDidChange:(BOOL)capabilitiesDidChange
                      moduleIdentifier:(NSString*)moduleIdentifier
                                  route:(NSString*)route {
  BabelInternalModuleNavigationResult* result = [[BabelInternalModuleNavigationResult alloc] init];
  result.destination = destination ?: BabelInternalModuleNavigationDestinationModules;
  result.fileTypeCapabilitiesDidChange = capabilitiesDidChange;
  result.moduleIdentifier = moduleIdentifier ?: @"";
  result.route = route ?: @"";
  return result;
}

@end

@implementation BabelInternalModuleNavigationHandler {
  BabelModuleUIActionCoordinator* moduleUIActionCoordinator_;
}

- (instancetype)initWithModuleUIActionCoordinator:
    (BabelModuleUIActionCoordinator*)moduleUIActionCoordinator {
  self = [super init];
  if (self) {
    moduleUIActionCoordinator_ = moduleUIActionCoordinator;
  }
  return self;
}

- (BabelInternalModuleNavigationResult*)handleModuleAction:(BabelInternalNavigationAction*)action {
  if ([action.name isEqualToString:BabelInternalNavigationActionInstallSelectedUpdates]) {
    BOOL changed = [moduleUIActionCoordinator_ installPHPModuleUpdatesWithIdentifiers:action.values];
    return [BabelInternalModuleNavigationResult
        resultWithDestination:BabelInternalModuleNavigationDestinationUpdates
        capabilitiesDidChange:changed
              moduleIdentifier:nil
                          route:nil];
  }

  if ([action.name isEqualToString:BabelInternalNavigationActionInstallZip]) {
    BOOL changed = [moduleUIActionCoordinator_ installPHPModuleZipFromPanel];
    return [BabelInternalModuleNavigationResult
        resultWithDestination:BabelInternalModuleNavigationDestinationModules
        capabilitiesDidChange:changed
              moduleIdentifier:nil
                          route:nil];
  }

  if ([action.name isEqualToString:BabelInternalNavigationActionConfigureUpdateURL]) {
    [moduleUIActionCoordinator_ configureModuleUpdateURLFromPrompt];
    return [self modulesResult];
  }

  if ([action.name isEqualToString:BabelInternalNavigationActionConfigureUpdateLocal]) {
    [moduleUIActionCoordinator_ configureModuleUpdateLocalDirectoryFromPanel];
    return [self modulesResult];
  }

  if ([action.name isEqualToString:BabelInternalNavigationActionCheckUpdates]) {
    return [self updatesResultWithCapabilitiesDidChange:NO];
  }

  if ([action.name isEqualToString:BabelInternalNavigationActionInstallUpdate]) {
    BOOL changed = [moduleUIActionCoordinator_ installPHPModuleUpdateWithIdentifier:action.value];
    return [self updatesResultWithCapabilitiesDidChange:changed];
  }

  if ([action.name isEqualToString:BabelInternalNavigationActionEnable]) {
    BOOL changed = [moduleUIActionCoordinator_ setPHPModuleWithIdentifier:action.value enabled:YES];
    return [self modulesResultWithCapabilitiesDidChange:changed];
  }

  if ([action.name isEqualToString:BabelInternalNavigationActionDisable]) {
    BOOL changed = [moduleUIActionCoordinator_ setPHPModuleWithIdentifier:action.value enabled:NO];
    return [self modulesResultWithCapabilitiesDidChange:changed];
  }

  if ([action.name isEqualToString:BabelInternalNavigationActionRemove]) {
    BOOL changed = [moduleUIActionCoordinator_ removePHPModuleWithIdentifier:action.value];
    return [self modulesResultWithCapabilitiesDidChange:changed];
  }

  if ([action.name isEqualToString:BabelInternalNavigationActionSetup]) {
    [moduleUIActionCoordinator_ setupModuleWithIdentifier:action.value];
    return [BabelInternalModuleNavigationResult
        resultWithDestination:BabelInternalModuleNavigationDestinationDetails
        capabilitiesDidChange:NO
              moduleIdentifier:action.value
                          route:nil];
  }

  if ([action.name isEqualToString:BabelInternalNavigationActionCheckReadiness]) {
    [moduleUIActionCoordinator_ refreshReadinessForModuleWithIdentifier:action.value];
    return [BabelInternalModuleNavigationResult
        resultWithDestination:BabelInternalModuleNavigationDestinationDetails
        capabilitiesDidChange:NO
              moduleIdentifier:action.value
                          route:nil];
  }

  if ([action.name isEqualToString:BabelInternalNavigationActionRestartRuntime]) {
    [moduleUIActionCoordinator_ restartRuntimeForModuleWithIdentifier:action.value];
    return [BabelInternalModuleNavigationResult
        resultWithDestination:BabelInternalModuleNavigationDestinationDetails
        capabilitiesDidChange:NO
              moduleIdentifier:action.value
                          route:nil];
  }

  if ([action.name isEqualToString:BabelInternalNavigationActionStopRuntime]) {
    [moduleUIActionCoordinator_ stopRuntimeForModuleWithIdentifier:action.value];
    return [BabelInternalModuleNavigationResult
        resultWithDestination:BabelInternalModuleNavigationDestinationDetails
        capabilitiesDidChange:NO
              moduleIdentifier:action.value
                          route:nil];
  }

  if ([action.name isEqualToString:BabelInternalNavigationActionModuleDetails]) {
    return [BabelInternalModuleNavigationResult
        resultWithDestination:BabelInternalModuleNavigationDestinationDetails
        capabilitiesDidChange:NO
              moduleIdentifier:action.value
                          route:nil];
  }

  if ([action.name isEqualToString:BabelInternalNavigationActionOpen]) {
    return [BabelInternalModuleNavigationResult
        resultWithDestination:BabelInternalModuleNavigationDestinationOpenModule
        capabilitiesDidChange:NO
              moduleIdentifier:action.value
                          route:action.secondaryValue];
  }

  return [self modulesResult];
}

- (BabelInternalModuleNavigationResult*)modulesResult {
  return [self modulesResultWithCapabilitiesDidChange:NO];
}

- (BabelInternalModuleNavigationResult*)modulesResultWithCapabilitiesDidChange:(BOOL)capabilitiesDidChange {
  return [BabelInternalModuleNavigationResult
      resultWithDestination:BabelInternalModuleNavigationDestinationModules
      capabilitiesDidChange:capabilitiesDidChange
            moduleIdentifier:nil
                        route:nil];
}

- (BabelInternalModuleNavigationResult*)updatesResultWithCapabilitiesDidChange:(BOOL)capabilitiesDidChange {
  return [BabelInternalModuleNavigationResult
      resultWithDestination:BabelInternalModuleNavigationDestinationUpdates
      capabilitiesDidChange:capabilitiesDidChange
            moduleIdentifier:nil
                        route:nil];
}

@end
