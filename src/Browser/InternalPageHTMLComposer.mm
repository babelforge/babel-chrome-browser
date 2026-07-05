#import "Browser/InternalPageHTMLComposer.h"

#import "Browser/AppSettingsPageRenderer.h"
#import "Browser/ExtensionsPageDataSource.h"
#import "Browser/ExtensionsPageRenderer.h"
#import "Browser/HistoryPageDataSource.h"
#import "Browser/HistoryPageRenderer.h"
#import "Browser/InternalPageRenderer.h"
#import "Browser/ModuleSettingsPageRenderer.h"

@implementation BabelInternalPageHTMLComposer {
  BabelInternalPageRenderer* internalPageRenderer_;
  BabelHistoryPageRenderer* historyPageRenderer_;
  BabelHistoryPageDataSource* historyPageDataSource_;
  BabelAppSettingsPageRenderer* appSettingsPageRenderer_;
  BabelModuleSettingsPageRenderer* moduleSettingsPageRenderer_;
  BabelExtensionsPageRenderer* extensionsPageRenderer_;
  BabelExtensionsPageDataSource* extensionsPageDataSource_;
}

- (instancetype)initWithInternalPageRenderer:(BabelInternalPageRenderer*)internalPageRenderer
                         historyPageRenderer:(BabelHistoryPageRenderer*)historyPageRenderer
                       historyPageDataSource:(BabelHistoryPageDataSource*)historyPageDataSource
                     appSettingsPageRenderer:(BabelAppSettingsPageRenderer*)appSettingsPageRenderer
                  moduleSettingsPageRenderer:(BabelModuleSettingsPageRenderer*)moduleSettingsPageRenderer
                      extensionsPageRenderer:(BabelExtensionsPageRenderer*)extensionsPageRenderer
                    extensionsPageDataSource:(BabelExtensionsPageDataSource*)extensionsPageDataSource {
  self = [super init];
  if (self) {
    internalPageRenderer_ = internalPageRenderer;
    historyPageRenderer_ = historyPageRenderer;
    historyPageDataSource_ = historyPageDataSource;
    appSettingsPageRenderer_ = appSettingsPageRenderer;
    moduleSettingsPageRenderer_ = moduleSettingsPageRenderer;
    extensionsPageRenderer_ = extensionsPageRenderer;
    extensionsPageDataSource_ = extensionsPageDataSource;
  }
  return self;
}

- (NSString*)historyPageHTMLWithGroups:(NSArray*)groups {
  NSString* body =
      [historyPageRenderer_ historyPageBodyWithOpenTabRows:[historyPageDataSource_ openTabRowsForGroups:groups]
                                      recentlyClosedTabRows:[historyPageDataSource_ recentlyClosedTabRows]];
  return [internalPageRenderer_ internalPageHTMLWithTitle:@"History" body:body];
}

- (NSString*)settingsPageHTMLWithDefaultURLString:(NSString*)defaultURLString
                                  appearanceTheme:(NSString*)appearanceTheme
                         longQuitShortcutEnabled:(BOOL)longQuitShortcutEnabled
                              tabOpeningStrategy:(NSString*)tabOpeningStrategy
                          addressSuggestionsMode:(NSString*)addressSuggestionsMode {
  NSString* body = [appSettingsPageRenderer_ settingsPageBodyWithDefaultURLString:defaultURLString
                                                                  appearanceTheme:appearanceTheme
                                                          longQuitShortcutEnabled:longQuitShortcutEnabled
                                                               tabOpeningStrategy:tabOpeningStrategy
                                                           addressSuggestionsMode:addressSuggestionsMode];
  return [internalPageRenderer_ internalPageHTMLWithTitle:@"Settings" body:body];
}

- (NSString*)moduleSettingsPageHTMLForIdentifier:(NSString*)moduleIdentifier
                                      moduleName:(NSString*)moduleName
                                   markdownTheme:(NSString*)markdownTheme {
  NSString* pageTitle = [moduleIdentifier isEqualToString:@"babelforge.markdown-viewer"]
      ? @"Markdown Viewer Settings"
      : [NSString stringWithFormat:@"%@ Settings", moduleName];
  NSString* body = [moduleSettingsPageRenderer_ moduleSettingsPageBodyForIdentifier:moduleIdentifier
                                                                         moduleName:moduleName
                                                                      markdownTheme:markdownTheme];
  return [internalPageRenderer_ internalPageHTMLWithTitle:pageTitle body:body];
}

- (NSString*)extensionsPageHTML {
  NSString* body =
      [extensionsPageRenderer_
          extensionsPageBodyWithProfileExtensionRows:[extensionsPageDataSource_ profileExtensionRows]
                               unpackedExtensionRows:[extensionsPageDataSource_ unpackedExtensionRows]];
  return [internalPageRenderer_ internalPageHTMLWithTitle:@"Extensions" body:body];
}

@end
