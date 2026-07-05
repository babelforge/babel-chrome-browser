#ifndef BABEL_CHROME_BROWSER_INTERNAL_MODULE_NAVIGATION_HANDLER_H_
#define BABEL_CHROME_BROWSER_INTERNAL_MODULE_NAVIGATION_HANDLER_H_

#import <Foundation/Foundation.h>

@class BabelInternalNavigationAction;
@class BabelModuleUIActionCoordinator;

extern NSString* const BabelInternalModuleNavigationDestinationModules;
extern NSString* const BabelInternalModuleNavigationDestinationUpdates;
extern NSString* const BabelInternalModuleNavigationDestinationDetails;
extern NSString* const BabelInternalModuleNavigationDestinationOpenModule;

/**
 * Describes the controller navigation that should follow an internal module action.
 */
@interface BabelInternalModuleNavigationResult : NSObject

@property(nonatomic, assign) BOOL fileTypeCapabilitiesDidChange;
@property(nonatomic, copy) NSString* destination;
@property(nonatomic, copy) NSString* moduleIdentifier;
@property(nonatomic, copy) NSString* route;

/**
 * Creates a module navigation result.
 *
 * @param destination The destination key.
 * @param capabilitiesDidChange YES when browser capabilities must be refreshed.
 * @param moduleIdentifier The optional module identifier.
 * @param route The optional module route.
 * @return The initialized result.
 */
+ (instancetype)resultWithDestination:(NSString*)destination
            capabilitiesDidChange:(BOOL)capabilitiesDidChange
                  moduleIdentifier:(NSString*)moduleIdentifier
                              route:(NSString*)route;

@end

/**
 * Handles internal PHP module actions and returns navigation intent to the controller.
 */
@interface BabelInternalModuleNavigationHandler : NSObject

/**
 * Creates an internal module navigation handler.
 *
 * @param moduleUIActionCoordinator The coordinator used for module UI mutations.
 * @return The initialized handler.
 */
- (instancetype)initWithModuleUIActionCoordinator:
    (BabelModuleUIActionCoordinator*)moduleUIActionCoordinator;

/**
 * Handles one parsed module action.
 *
 * @param action The parsed action.
 * @return The navigation result for the controller.
 */
- (BabelInternalModuleNavigationResult*)handleModuleAction:(BabelInternalNavigationAction*)action;

@end

#endif
