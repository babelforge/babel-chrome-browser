#ifndef BABEL_CHROME_BROWSER_HISTORY_PAGE_DATA_SOURCE_H_
#define BABEL_CHROME_BROWSER_HISTORY_PAGE_DATA_SOURCE_H_

#import <Foundation/Foundation.h>

@class BabelBrowserGroup;
@class BabelInternalPageTabClassifier;
@class BabelRecentlyClosedTabStore;

/**
 * Builds the data rows consumed by the History internal page renderer.
 */
@interface BabelHistoryPageDataSource : NSObject

/**
 * Creates a History page data source.
 *
 * @param internalPageTabClassifier The classifier used to exclude internal tabs from the open tab list.
 * @param recentlyClosedTabStore The recently closed tab store.
 * @param defaultGroupName The fallback group name.
 *
 * @return The initialized History page data source.
 */
- (instancetype)initWithInternalPageTabClassifier:(BabelInternalPageTabClassifier*)internalPageTabClassifier
                          recentlyClosedTabStore:(BabelRecentlyClosedTabStore*)recentlyClosedTabStore
                                defaultGroupName:(NSString*)defaultGroupName;

/**
 * Builds open tab rows for the provided groups.
 *
 * @param groups The browser groups to inspect.
 *
 * @return The open tab row dictionaries.
 */
- (NSArray<NSDictionary*>*)openTabRowsForGroups:(NSArray<BabelBrowserGroup*>*)groups;

/**
 * Builds recently closed tab rows.
 *
 * @return The recently closed tab row dictionaries.
 */
- (NSArray<NSDictionary*>*)recentlyClosedTabRows;

@end

#endif
