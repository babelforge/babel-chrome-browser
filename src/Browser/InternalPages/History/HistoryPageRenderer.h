#ifndef BABEL_CHROME_BROWSER_HISTORY_PAGE_RENDERER_H_
#define BABEL_CHROME_BROWSER_HISTORY_PAGE_RENDERER_H_

#import <Foundation/Foundation.h>

extern NSString* const BabelHistoryRowTitleKey;
extern NSString* const BabelHistoryRowURLStringKey;
extern NSString* const BabelHistoryRowGroupNameKey;
extern NSString* const BabelHistoryRowReopenIndexKey;

/**
 * Renders the History internal page body.
 */
@interface BabelHistoryPageRenderer : NSObject

/**
 * Renders the History page body.
 *
 * @param openTabRows The open tab row dictionaries.
 * @param recentlyClosedTabRows The recently closed tab row dictionaries.
 * @return The rendered History page body HTML.
 */
- (NSString*)historyPageBodyWithOpenTabRows:(NSArray<NSDictionary*>*)openTabRows
                      recentlyClosedTabRows:(NSArray<NSDictionary*>*)recentlyClosedTabRows;

@end

#endif
