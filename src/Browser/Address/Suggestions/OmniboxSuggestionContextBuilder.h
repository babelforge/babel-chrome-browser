#import <Cocoa/Cocoa.h>

@class BabelBrowserGroup;
@class BabelBrowserTab;
@class BabelClosedTab;
@class BabelFaviconStore;

typedef BOOL (^BabelOmniboxInternalTabPredicate)(BabelBrowserTab* tab);

@interface BabelOmniboxSuggestionContextBuilder : NSObject

- (NSArray<NSDictionary*>*)openTabRowsForGroups:(NSArray<BabelBrowserGroup*>*)groups
                               defaultGroupName:(NSString*)defaultGroupName
                           internalTabPredicate:(BabelOmniboxInternalTabPredicate)internalTabPredicate;

- (NSArray<NSDictionary*>*)closedTabRowsForClosedTabs:(NSArray<BabelClosedTab*>*)closedTabs
                                     defaultGroupName:(NSString*)defaultGroupName;

- (NSImage*)faviconImageForSuggestionTitle:(NSString*)title
                                 urlString:(NSString*)urlString
                              faviconStore:(BabelFaviconStore*)faviconStore;

@end
