#ifndef BABEL_CHROME_BROWSER_TAB_METADATA_UPDATER_H_
#define BABEL_CHROME_BROWSER_TAB_METADATA_UPDATER_H_

#import <Cocoa/Cocoa.h>

@class BabelBrowserTab;
@class BabelFaviconStore;

typedef NSString* _Nonnull (^BabelCompactTitleBlock)(NSString* _Nonnull title);

/**
 * Applies browser metadata callbacks to tab models and tab-strip views.
 */
@interface BabelBrowserTabMetadataUpdater : NSObject

/**
 * Updates a tab title from a CEF title callback.
 *
 * @param tab The tab to update.
 * @param title The CEF title value.
 * @param compactTitleBlock The formatter used for the tab-strip title.
 * @return YES when a tab was updated, otherwise NO.
 */
- (BOOL)updateTab:(BabelBrowserTab* _Nullable)tab
        withTitle:(NSString* _Nullable)title
compactTitleBlock:(BabelCompactTitleBlock _Nullable)compactTitleBlock;

/**
 * Updates a tab favicon from a CEF favicon callback.
 *
 * @param tab The tab to update.
 * @param faviconImage The favicon image.
 * @param faviconStore The store used to cache the favicon by URL.
 * @return YES when a tab was updated, otherwise NO.
 */
- (BOOL)updateTab:(BabelBrowserTab* _Nullable)tab
 withFaviconImage:(NSImage* _Nullable)faviconImage
     faviconStore:(BabelFaviconStore* _Nullable)faviconStore;

@end

#endif
