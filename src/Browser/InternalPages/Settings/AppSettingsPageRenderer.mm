#import "Browser/InternalPages/Settings/AppSettingsPageRenderer.h"

#import "Browser/InternalPages/Rendering/SettingsOptionRenderer.h"

@implementation BabelAppSettingsPageRenderer {
  BabelSettingsOptionRenderer* optionRenderer_;
}

- (instancetype)initWithOptionRenderer:(BabelSettingsOptionRenderer*)optionRenderer {
  self = [super init];
  if (self) {
    optionRenderer_ = optionRenderer;
  }
  return self;
}

- (NSString*)settingsPageBodyWithDefaultURLString:(NSString*)defaultURLString
                                  appearanceTheme:(NSString*)appearanceTheme
                          longQuitShortcutEnabled:(BOOL)longQuitShortcutEnabled
                               tabOpeningStrategy:(NSString*)tabOpeningStrategy
                           addressSuggestionsMode:(NSString*)addressSuggestionsMode {
  return [NSString stringWithFormat:
      @"<h1>Settings</h1>"
       "<section><a class='primaryButton' data-can-open-menu='true' href='babelchrome://extensions'>Extensions</a>"
       " <a class='primaryButton' data-can-open-menu='true' href='babelchrome://modules'>PHP Modules</a></section>"
       "<section>"
       "<h2>General</h2>"
       "<dl>"
       "<dt>Default page</dt><dd>%@</dd>"
       "<dt>Application theme</dt><dd>%@</dd>"
       "<dt>Quit shortcut</dt><dd>%@</dd>"
       "<dt>Tab opening strategy</dt><dd>%@</dd>"
       "<dt>Address suggestions</dt><dd>%@</dd>"
       "<dt>Groups file</dt><dd>Stored in the BabelChrome application support folder.</dd>"
       "<dt>Developer Tools docking</dt><dd>The last selected dock mode is saved automatically.</dd>"
       "</dl>"
       "</section>",
      [self htmlEscapedString:defaultURLString],
      [optionRenderer_ appearanceThemeHTMLWithSelectedTheme:appearanceTheme],
      [optionRenderer_ longQuitShortcutHTMLWithEnabledState:longQuitShortcutEnabled],
      [optionRenderer_ tabOpeningStrategyHTMLWithSelectedStrategy:tabOpeningStrategy],
      [optionRenderer_ addressSuggestionsHTMLWithSelectedMode:addressSuggestionsMode]];
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
