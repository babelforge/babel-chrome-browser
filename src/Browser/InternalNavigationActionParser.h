#ifndef BABEL_CHROME_BROWSER_INTERNAL_NAVIGATION_ACTION_PARSER_H_
#define BABEL_CHROME_BROWSER_INTERNAL_NAVIGATION_ACTION_PARSER_H_

#import <Foundation/Foundation.h>

extern NSString* const BabelInternalNavigationActionShow;
extern NSString* const BabelInternalNavigationActionSearch;
extern NSString* const BabelInternalNavigationActionAddUnpacked;
extern NSString* const BabelInternalNavigationActionRemove;
extern NSString* const BabelInternalNavigationActionDisableProfile;
extern NSString* const BabelInternalNavigationActionEnableProfile;
extern NSString* const BabelInternalNavigationActionRemoveProfile;
extern NSString* const BabelInternalNavigationActionRestart;
extern NSString* const BabelInternalNavigationActionInstallZip;
extern NSString* const BabelInternalNavigationActionConfigureUpdateURL;
extern NSString* const BabelInternalNavigationActionConfigureUpdateLocal;
extern NSString* const BabelInternalNavigationActionCheckUpdates;
extern NSString* const BabelInternalNavigationActionInstallUpdate;
extern NSString* const BabelInternalNavigationActionInstallSelectedUpdates;
extern NSString* const BabelInternalNavigationActionEnable;
extern NSString* const BabelInternalNavigationActionDisable;
extern NSString* const BabelInternalNavigationActionModuleDetails;
extern NSString* const BabelInternalNavigationActionOpen;
extern NSString* const BabelInternalNavigationActionReopen;

/**
 * Describes an action parsed from an internal BabelChrome URL.
 */
@interface BabelInternalNavigationAction : NSObject

/**
 * The parsed action name.
 */
@property(nonatomic, copy) NSString* name;

/**
 * The primary action value.
 */
@property(nonatomic, copy) NSString* value;

/**
 * The secondary action value.
 */
@property(nonatomic, copy) NSString* secondaryValue;

/**
 * The list of values carried by the action.
 */
@property(nonatomic, copy) NSArray<NSString*>* values;

@end

/**
 * Parses internal BabelChrome navigation query items into small action objects.
 */
@interface BabelInternalNavigationActionParser : NSObject

/**
 * Parses an Extensions page action.
 *
 * @param components The internal URL components.
 * @return The parsed action. Returns a show action when no action query is present.
 */
- (BabelInternalNavigationAction*)extensionsActionFromComponents:(NSURLComponents*)components;

/**
 * Parses a Modules page action.
 *
 * @param components The internal URL components.
 * @return The parsed action. Returns a show action when no action query is present.
 */
- (BabelInternalNavigationAction*)modulesActionFromComponents:(NSURLComponents*)components;

/**
 * Parses a History page action.
 *
 * @param components The internal URL components.
 * @return The parsed action. Returns a show action when no action query is present.
 */
- (BabelInternalNavigationAction*)historyActionFromComponents:(NSURLComponents*)components;

@end

#endif
