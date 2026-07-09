#ifndef BABEL_CHROME_BROWSER_MODULE_UI_ACTION_COORDINATOR_H_
#define BABEL_CHROME_BROWSER_MODULE_UI_ACTION_COORDINATOR_H_

#import <Foundation/Foundation.h>

@class BabelModuleActionService;
@class BabelModuleUpdateService;

/**
 * Coordinates native UI actions for PHP module management.
 */
@interface BabelModuleUIActionCoordinator : NSObject

/**
 * Creates a module UI action coordinator.
 *
 * @param moduleActionService The module action service.
 * @param moduleUpdateService The module update service.
 * @return The initialized coordinator.
 */
- (instancetype)initWithModuleActionService:(BabelModuleActionService*)moduleActionService
                        moduleUpdateService:(BabelModuleUpdateService*)moduleUpdateService;

/**
 * Opens the native zip selection panel and installs the selected modules.
 *
 * @return YES when at least one module was installed.
 */
- (BOOL)installPHPModuleZipFromPanel;

/**
 * Updates a PHP module enabled state.
 *
 * @param moduleIdentifier The module identifier.
 * @param enabled YES to enable the module.
 * @return YES when the module state was updated.
 */
- (BOOL)setPHPModuleWithIdentifier:(NSString*)moduleIdentifier enabled:(BOOL)enabled;

/**
 * Confirms and removes a PHP module.
 *
 * @param moduleIdentifier The module identifier.
 * @return YES when the module was removed.
 */
- (BOOL)removePHPModuleWithIdentifier:(NSString*)moduleIdentifier;

/**
 * Confirms and runs a module setup command.
 *
 * @param moduleIdentifier The module identifier.
 * @return YES when the setup command was executed.
 */
- (BOOL)setupModuleWithIdentifier:(NSString*)moduleIdentifier;

/**
 * Refreshes one module readiness status.
 *
 * @param moduleIdentifier The module identifier.
 * @return YES when the readiness request completed.
 */
- (BOOL)refreshReadinessForModuleWithIdentifier:(NSString*)moduleIdentifier;

/**
 * Confirms and restarts a module runtime when supported.
 *
 * @param moduleIdentifier The module identifier.
 * @return YES when the runtime restart request completed.
 */
- (BOOL)restartRuntimeForModuleWithIdentifier:(NSString*)moduleIdentifier;

/**
 * Confirms and stops a module runtime when supported.
 *
 * @param moduleIdentifier The module identifier.
 * @return YES when the runtime stop request completed.
 */
- (BOOL)stopRuntimeForModuleWithIdentifier:(NSString*)moduleIdentifier;

/**
 * Prompts for the module update URL.
 */
- (void)configureModuleUpdateURLFromPrompt;

/**
 * Opens the native folder selection panel for the local update source.
 */
- (void)configureModuleUpdateLocalDirectoryFromPanel;

/**
 * Installs a single PHP module update.
 *
 * @param moduleIdentifier The module identifier.
 * @return YES when at least one module was installed.
 */
- (BOOL)installPHPModuleUpdateWithIdentifier:(NSString*)moduleIdentifier;

/**
 * Installs selected PHP module updates.
 *
 * @param moduleIdentifiers The selected module identifiers.
 * @return YES when at least one module was installed.
 */
- (BOOL)installPHPModuleUpdatesWithIdentifiers:(NSArray<NSString*>*)moduleIdentifiers;

/**
 * Shows a standard module action alert.
 *
 * @param error The error to display.
 */
- (void)showModuleActionAlertWithError:(NSError*)error;

@end

#endif
