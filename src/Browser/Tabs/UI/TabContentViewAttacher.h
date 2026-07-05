#ifndef BABEL_CHROME_BROWSER_TAB_CONTENT_VIEW_ATTACHER_H_
#define BABEL_CHROME_BROWSER_TAB_CONTENT_VIEW_ATTACHER_H_

#import <Cocoa/Cocoa.h>

@class BabelBrowserTab;

/**
 * Attaches a browser tab content views to the page container.
 */
@interface BabelTabContentViewAttacher : NSObject

/**
 * Adds the tab browser and developer tools views to the given pages panel.
 *
 * @param tab The tab whose content views should be attached.
 * @param pagesPanel The pages panel receiving the tab content views.
 */
- (void)attachTab:(BabelBrowserTab*)tab toPagesPanel:(NSView*)pagesPanel;

@end

#endif
