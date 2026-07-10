#import "Browser/InternalPages/Modules/ModuleSettingsPageRenderer.h"

#import "Browser/InternalPages/Rendering/SettingsOptionRenderer.h"

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
                                   markdownTheme:(NSString*)markdownTheme
                          requiredSettingsStatus:(NSDictionary*)requiredSettingsStatus {
  NSString* requiredSettingsHTML = [self requiredSettingsHTMLForModuleIdentifier:moduleIdentifier
                                                                          status:requiredSettingsStatus];
  if ([moduleIdentifier isEqualToString:@"babelforge.markdown-viewer"]) {
    return [NSString stringWithFormat:
        @"<h1>Markdown Viewer Settings</h1>"
         "%@"
         "<section>"
         "<p class='note'>These settings belong to the Markdown Viewer module, not to BabelChrome itself.</p>"
         "<dl>"
         "<dt>Markdown theme</dt><dd>%@</dd>"
         "</dl>"
         "</section>"
         "<p><a class='smallButton' data-can-open-menu='true' href='babelchrome://modules'>Back to modules</a></p>",
        requiredSettingsHTML,
        [optionRenderer_ markdownThemeHTMLWithSelectedTheme:markdownTheme
                                          settingsURLString:@"babelchrome://settings/babelforge.markdown-viewer"]];
  }

  return [NSString stringWithFormat:
      @"<h1>%@ Settings</h1>"
       "%@"
       "<section>"
       "<p class='empty'>This module does not expose native BabelChrome settings yet.</p>"
       "</section>"
       "<p><a class='smallButton' data-can-open-menu='true' href='babelchrome://modules'>Back to modules</a></p>",
      [self htmlEscapedString:moduleName],
      requiredSettingsHTML];
}

- (NSString*)requiredSettingsHTMLForModuleIdentifier:(NSString*)moduleIdentifier
                                             status:(NSDictionary*)status {
  NSArray* settings = [status[@"settings"] isKindOfClass:NSArray.class] ? status[@"settings"] : @[];
  if (settings.count == 0) {
    return @"";
  }

  BOOL ready = [status[@"ready"] boolValue];
  NSMutableString* html = [NSMutableString stringWithFormat:
      @"<section>"
       "<h2>Runtime requirements</h2>"
       "<p class='%@'>%@</p>",
      ready ? @"note" : @"empty",
      ready ? @"All required runtime settings are valid."
            : @"This module needs runtime settings before it can start."];

  for (NSDictionary* setting in settings) {
    if (![setting isKindOfClass:NSDictionary.class]) {
      continue;
    }

    NSString* key = [setting[@"key"] isKindOfClass:NSString.class] ? setting[@"key"] : @"";
    NSString* label = [setting[@"label"] isKindOfClass:NSString.class] ? setting[@"label"] : key;
    NSString* value = [setting[@"value"] isKindOfClass:NSString.class] ? setting[@"value"] : @"";
    NSString* state = [setting[@"state"] isKindOfClass:NSString.class] ? setting[@"state"] : @"invalid";
    NSString* version = [setting[@"version"] isKindOfClass:NSString.class] ? setting[@"version"] : @"";
    NSArray* messages = [setting[@"messages"] isKindOfClass:NSArray.class] ? setting[@"messages"] : @[];

    [html appendFormat:
        @"<div class='moduleRow'>"
         "<div class='moduleText'>"
         "<h3>%@</h3>"
         "<dl><dt>Status</dt><dd>%@%@</dd></dl>"
         "%@"
         "<form method='get' action='babelchrome://settings/%@'>"
         "<input type='hidden' name='runtimeSettingKey' value='%@'>"
         "<label>Path <input name='runtimeSettingValue' value='%@'></label>"
         "<button type='submit'>Save</button>"
         "</form>"
         "</div>"
         "</div>",
        [self htmlEscapedString:label],
        [self htmlEscapedString:state],
        version.length > 0 ? [NSString stringWithFormat:@" (%@)", [self htmlEscapedString:version]] : @"",
        [self messagesHTML:messages],
        [self pathEscapedString:moduleIdentifier],
        [self htmlEscapedString:key],
        [self htmlEscapedString:value]];
  }

  [html appendString:@"</section>"];
  return html;
}

- (NSString*)messagesHTML:(NSArray*)messages {
  if (messages.count == 0) {
    return @"";
  }

  NSMutableString* html = [NSMutableString stringWithString:@"<ul>"];
  for (id message in messages) {
    if ([message isKindOfClass:NSString.class] && [message length] > 0) {
      [html appendFormat:@"<li>%@</li>", [self htmlEscapedString:message]];
    }
  }
  [html appendString:@"</ul>"];
  return html;
}

- (NSString*)pathEscapedString:(NSString*)value {
  return [value stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.URLPathAllowedCharacterSet] ?: @"";
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
