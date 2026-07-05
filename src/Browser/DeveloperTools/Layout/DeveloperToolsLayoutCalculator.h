#ifndef BABEL_CHROME_BROWSER_DEVELOPER_TOOLS_LAYOUT_CALCULATOR_H_
#define BABEL_CHROME_BROWSER_DEVELOPER_TOOLS_LAYOUT_CALCULATOR_H_

#import <Cocoa/Cocoa.h>

/**
 * Describes the frame split between the inspected page and its DevTools panel.
 */
@interface BabelDeveloperToolsPageLayout : NSObject

@property(nonatomic, readonly) NSRect browserFrame;
@property(nonatomic, readonly) NSRect panelFrame;

/**
 * Initializes a page layout result.
 *
 * @param browserFrame The frame reserved for the inspected page.
 * @param panelFrame The frame reserved for the DevTools panel.
 *
 * @return The initialized layout result.
 */
- (instancetype)initWithBrowserFrame:(NSRect)browserFrame
                          panelFrame:(NSRect)panelFrame;

@end

/**
 * Describes the internal frame layout of the DevTools panel.
 */
@interface BabelDeveloperToolsPanelLayout : NSObject

@property(nonatomic, readonly) NSRect toolbarFrame;
@property(nonatomic, readonly) NSRect resizeHandleFrame;
@property(nonatomic, readonly) NSRect hostFrame;

/**
 * Initializes a panel layout result.
 *
 * @param toolbarFrame The frame reserved for the DevTools toolbar.
 * @param resizeHandleFrame The frame reserved for the resize handle.
 * @param hostFrame The frame reserved for the embedded DevTools browser.
 *
 * @return The initialized layout result.
 */
- (instancetype)initWithToolbarFrame:(NSRect)toolbarFrame
                   resizeHandleFrame:(NSRect)resizeHandleFrame
                           hostFrame:(NSRect)hostFrame;

@end

/**
 * Calculates frames for the embedded Developer Tools surface.
 */
@interface BabelDeveloperToolsLayoutCalculator : NSObject

/**
 * Calculates the inspected browser and DevTools panel frames.
 *
 * @param bounds The available page container bounds.
 * @param dockMode The current DevTools docking mode.
 * @param sizeRatio The persisted DevTools size ratio.
 *
 * @return The calculated page layout.
 */
- (BabelDeveloperToolsPageLayout*)pageLayoutForBounds:(NSRect)bounds
                                             dockMode:(NSString*)dockMode
                                            sizeRatio:(CGFloat)sizeRatio;

/**
 * Calculates the DevTools panel's child frames.
 *
 * @param bounds The available DevTools panel bounds.
 * @param dockMode The current DevTools docking mode.
 * @param toolbarHeight The preferred toolbar height.
 * @param resizeHandleThickness The resize handle thickness.
 *
 * @return The calculated panel layout.
 */
- (BabelDeveloperToolsPanelLayout*)panelLayoutForBounds:(NSRect)bounds
                                               dockMode:(NSString*)dockMode
                                          toolbarHeight:(CGFloat)toolbarHeight
                                  resizeHandleThickness:(CGFloat)resizeHandleThickness;

@end

#endif
