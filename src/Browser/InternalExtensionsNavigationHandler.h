#ifndef BABEL_CHROME_BROWSER_INTERNAL_EXTENSIONS_NAVIGATION_HANDLER_H_
#define BABEL_CHROME_BROWSER_INTERNAL_EXTENSIONS_NAVIGATION_HANDLER_H_

#import <Foundation/Foundation.h>

@class BabelExtensionFolderController;
@class BabelExtensionProfileStore;
@class BabelInternalNavigationActionParser;

/**
 * Describes native follow-up work after an Extensions page action.
 */
@interface BabelInternalExtensionsNavigationResult : NSObject

/**
 * The Chrome Web Store search query to open.
 */
@property(nonatomic, copy) NSString* searchQuery;

/**
 * Whether the application must restart after the action.
 */
@property(nonatomic, assign) BOOL shouldRestartApplication;

@end

/**
 * Applies internal Extensions page navigation actions.
 */
@interface BabelInternalExtensionsNavigationHandler : NSObject

/**
 * Creates an internal Extensions navigation handler.
 *
 * @param actionParser The parser used to read URL query actions.
 * @param extensionFolderController The controller used for unpacked extension selection.
 * @param extensionProfileStore The store used for extension profile mutations.
 * @return The initialized handler.
 */
- (instancetype)initWithActionParser:(BabelInternalNavigationActionParser*)actionParser
           extensionFolderController:(BabelExtensionFolderController*)extensionFolderController
                extensionProfileStore:(BabelExtensionProfileStore*)extensionProfileStore;

/**
 * Applies the action represented by internal URL components.
 *
 * @param components The internal Extensions URL components.
 * @return The native follow-up result.
 */
- (BabelInternalExtensionsNavigationResult*)handleExtensionsComponents:(NSURLComponents*)components;

@end

#endif
