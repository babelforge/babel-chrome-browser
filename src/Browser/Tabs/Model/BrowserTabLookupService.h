#ifndef BABEL_CHROME_BROWSER_TAB_LOOKUP_SERVICE_H_
#define BABEL_CHROME_BROWSER_TAB_LOOKUP_SERVICE_H_

#import <Foundation/Foundation.h>

#include "include/cef_browser.h"

@class BabelBrowserGroup;
@class BabelBrowserTab;

/**
 * Looks up native tab models from group collections and CEF browsers.
 */
@interface BabelBrowserTabLookupService : NSObject

/**
 * Returns the tab that owns a CEF browser.
 *
 * @param browser The CEF browser.
 * @param groups The groups to search.
 * @return The matching tab, or nil.
 */
- (BabelBrowserTab*)tabForBrowser:(CefRefPtr<CefBrowser>)browser
                           groups:(NSArray<BabelBrowserGroup*>*)groups;

@end

#endif
