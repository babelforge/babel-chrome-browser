#ifndef BABEL_CHROME_BROWSER_INTERNAL_PAGE_TAB_CLASSIFIER_H_
#define BABEL_CHROME_BROWSER_INTERNAL_PAGE_TAB_CLASSIFIER_H_

#import <Foundation/Foundation.h>

@class BabelBrowserTab;

/**
 * Classifies tabs that display native BabelChrome internal pages.
 */
@interface BabelInternalPageTabClassifier : NSObject

/**
 * Initializes the classifier.
 *
 * @param internalPageURLStrings The requested URL strings considered internal.
 *
 * @return The initialized classifier.
 */
- (instancetype)initWithInternalPageURLStrings:(NSArray<NSString*>*)internalPageURLStrings;

/**
 * Returns whether a tab displays an internal page.
 *
 * @param tab The tab to inspect.
 *
 * @return YES when the tab displays an internal page.
 */
- (BOOL)isInternalPageTab:(BabelBrowserTab*)tab;

@end

#endif
