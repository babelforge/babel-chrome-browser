#ifndef BABEL_CHROME_BROWSER_PROJECT_LAUNCHER_JSON_IMPORTER_H_
#define BABEL_CHROME_BROWSER_PROJECT_LAUNCHER_JSON_IMPORTER_H_

#import <Foundation/Foundation.h>

typedef void (^BabelProjectLauncherImportLogHandler)(NSString* line);

/**
 * Imports a Project Launcher JSON configuration through a native file picker.
 */
@interface BabelProjectLauncherJSONImporter : NSObject

/**
 * Creates a Project Launcher JSON importer.
 *
 * @param logHandler The optional log handler used to report import decisions.
 * @return The initialized Project Launcher JSON importer.
 */
- (instancetype)initWithLogHandler:(BabelProjectLauncherImportLogHandler)logHandler;

/**
 * Opens a native panel and returns a Project Launcher import URL when a valid JSON file is selected.
 *
 * @return The module import URL, or nil when the import was cancelled or invalid.
 */
- (NSURL*)projectLauncherImportURLFromPanel;

@end

#endif
