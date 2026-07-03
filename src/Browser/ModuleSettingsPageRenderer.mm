#import "Browser/ModuleSettingsPageRenderer.h"

#import "Browser/SettingsOptionRenderer.h"

@implementation BabelModuleSettingsPageRenderer {
  BabelSettingsOptionRenderer* optionRenderer_;
}

- (instancetype)initWithOptionRenderer:(BabelSettingsOptionRenderer*)optionRenderer {
  self = [super init];
  if (self) {
    optionRenderer_ = optionRenderer;
  }
  return self;
}

- (NSString*)moduleSettingsPageBodyForIdentifier:(NSString*)moduleIdentifier
                                      moduleName:(NSString*)moduleName
                                   markdownTheme:(NSString*)markdownTheme {
  if ([moduleIdentifier isEqualToString:@"babelforge.markdown-viewer"]) {
    return [NSString stringWithFormat:
        @"<h1>Markdown Viewer Settings</h1>"
         "<section>"
         "<p class='note'>These settings belong to the Markdown Viewer module, not to BabelChrome itself.</p>"
         "<dl>"
         "<dt>Markdown theme</dt><dd>%@</dd>"
         "</dl>"
         "</section>"
         "<p><a class='smallButton' data-can-open-menu='true' href='babelchrome://modules'>Back to modules</a></p>",
        [optionRenderer_ markdownThemeHTMLWithSelectedTheme:markdownTheme
                                          settingsURLString:@"babelchrome://settings/babelforge.markdown-viewer"]];
  }

  return [NSString stringWithFormat:
      @"<h1>%@ Settings</h1>"
       "<section>"
       "<p class='empty'>This module does not expose native BabelChrome settings yet.</p>"
       "</section>"
       "<p><a class='smallButton' data-can-open-menu='true' href='babelchrome://modules'>Back to modules</a></p>",
      [self htmlEscapedString:moduleName]];
}

- (NSString*)htmlEscapedString:(NSString*)value {
  NSMutableString* escapedString = [NSMutableString stringWithString:value ?: @""];
  [escapedString replaceOccurrencesOfString:@"&"
                                 withString:@"&amp;"
                                    options:0
                                      range:NSMakeRange(0, escapedString.length)];
  [escapedString replaceOccurrencesOfString:@"<"
                                 withString:@"&lt;"
                                    options:0
                                      range:NSMakeRange(0, escapedString.length)];
  [escapedString replaceOccurrencesOfString:@">"
                                 withString:@"&gt;"
                                    options:0
                                      range:NSMakeRange(0, escapedString.length)];
  [escapedString replaceOccurrencesOfString:@"\""
                                 withString:@"&quot;"
                                    options:0
                                      range:NSMakeRange(0, escapedString.length)];
  return escapedString;
}

@end
