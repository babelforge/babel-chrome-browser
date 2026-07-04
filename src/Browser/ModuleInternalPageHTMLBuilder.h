#ifndef BABEL_CHROME_BROWSER_MODULE_INTERNAL_PAGE_HTML_BUILDER_H_
#define BABEL_CHROME_BROWSER_MODULE_INTERNAL_PAGE_HTML_BUILDER_H_

#import <Foundation/Foundation.h>

@class BabelInternalPageRenderer;
@class BabelModuleActionService;
@class BabelModulePageRenderer;
@class BabelModuleUpdateService;

/**
 * Builds HTML documents for BabelChrome module internal pages.
 */
@interface BabelModuleInternalPageHTMLBuilder : NSObject

/**
 * Initializes the builder.
 *
 * @param moduleActionService The module action/query service.
 * @param modulePageRenderer The module body renderer.
 * @param moduleUpdateService The module update service.
 * @param internalPageRenderer The shared internal page shell renderer.
 * @return An initialized module internal page HTML builder.
 */
- (instancetype)initWithModuleActionService:(BabelModuleActionService*)moduleActionService
                         modulePageRenderer:(BabelModulePageRenderer*)modulePageRenderer
                        moduleUpdateService:(BabelModuleUpdateService*)moduleUpdateService
                       internalPageRenderer:(BabelInternalPageRenderer*)internalPageRenderer;

/**
 * Builds the Modules page HTML document.
 *
 * @return The complete HTML document.
 */
- (NSString*)modulesPageHTML;

/**
 * Builds the module details page HTML document.
 *
 * @param moduleIdentifier The module identifier.
 * @return The complete HTML document.
 */
- (NSString*)moduleDetailsPageHTMLForIdentifier:(NSString*)moduleIdentifier;

/**
 * Builds the module updates page HTML document.
 *
 * @return The complete HTML document.
 */
- (NSString*)moduleUpdatesPageHTML;

@end

#endif
