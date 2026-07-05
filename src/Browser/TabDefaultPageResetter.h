#ifndef BABEL_CHROME_BROWSER_TAB_DEFAULT_PAGE_RESETTER_H_
#define BABEL_CHROME_BROWSER_TAB_DEFAULT_PAGE_RESETTER_H_

#import <Foundation/Foundation.h>

@class BabelBrowserTab;

@interface BabelTabDefaultPageResetter : NSObject

- (instancetype)initWithDefaultURLString:(NSString*)defaultURLString
                       compactTitleBlock:(NSString* (^)(NSString* title))compactTitleBlock;

- (void)resetTabToDefaultPage:(BabelBrowserTab*)tab;

@end

#endif  // BABEL_CHROME_BROWSER_TAB_DEFAULT_PAGE_RESETTER_H_
