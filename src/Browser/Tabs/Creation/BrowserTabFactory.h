#ifndef BABEL_CHROME_BROWSER_TAB_FACTORY_H_
#define BABEL_CHROME_BROWSER_TAB_FACTORY_H_

#import <Cocoa/Cocoa.h>

@class BabelBrowserTab;
@class BabelFaviconStore;
@class BabelPageContainerView;

/**
 * Creates native browser tab models and their AppKit views.
 */
@interface BabelBrowserTabFactory : NSObject

/**
 * Initializes the tab factory.
 *
 * @param faviconStore The favicon store used to populate new tab icons.
 * @param actionTarget The target that receives tab and Developer Tools actions.
 * @param compactTitleBlock The block used to compact tab titles.
 * @param localDropAcceptanceBlock The block used to decide whether a page accepts local drops.
 * @param localDropHandlerBlock The block invoked when a page receives a local drop.
 *
 * @return The initialized factory.
 */
- (instancetype)initWithFaviconStore:(BabelFaviconStore*)faviconStore
                         actionTarget:(id)actionTarget
                    compactTitleBlock:(NSString* (^)(NSString* title))compactTitleBlock
             localDropAcceptanceBlock:(BOOL (^)(BabelPageContainerView* container))localDropAcceptanceBlock
                 localDropHandlerBlock:(void (^)(BabelPageContainerView* container))localDropHandlerBlock;

/**
 * Creates a native tab model and its AppKit views.
 *
 * @param urlString The navigation URL string.
 * @param identifier The optional stable tab identifier.
 * @param title The optional tab title.
 * @param hostBounds The initial host view bounds.
 *
 * @return The created browser tab.
 */
- (BabelBrowserTab*)makeTabForURL:(NSString*)urlString
                       identifier:(NSString*)identifier
                            title:(NSString*)title
                       hostBounds:(NSRect)hostBounds;

@end

#endif
