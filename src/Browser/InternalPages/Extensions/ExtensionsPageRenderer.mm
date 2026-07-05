#import "Browser/InternalPages/Extensions/ExtensionsPageRenderer.h"

NSString* const BabelExtensionProfileNameKey = @"name";
NSString* const BabelExtensionProfileIdentifierKey = @"identifier";
NSString* const BabelExtensionProfileVersionKey = @"version";
NSString* const BabelExtensionProfilePathKey = @"path";
NSString* const BabelExtensionProfileStatusKey = @"status";
NSString* const BabelExtensionProfileToggleActionKey = @"toggleAction";
NSString* const BabelExtensionProfileToggleLabelKey = @"toggleLabel";
NSString* const BabelExtensionProfileRequiresRestartKey = @"requiresRestart";
NSString* const BabelUnpackedExtensionNameKey = @"name";
NSString* const BabelUnpackedExtensionPathKey = @"path";
NSString* const BabelUnpackedExtensionStatusKey = @"status";

@implementation BabelExtensionsPageRenderer {
  NSString* trashIconHTML_;
}

- (instancetype)initWithTrashIconHTML:(NSString*)trashIconHTML {
  self = [super init];
  if (self) {
    trashIconHTML_ = [trashIconHTML copy] ?: @"";
  }
  return self;
}

- (NSString*)extensionsPageBodyWithProfileExtensionRows:(NSArray<NSDictionary*>*)profileExtensionRows
                                 unpackedExtensionRows:(NSArray<NSDictionary*>*)unpackedExtensionRows {
  NSString* profileListHTML = [self profileListHTMLWithRows:profileExtensionRows];
  NSString* unpackedListHTML = [self unpackedListHTMLWithRows:unpackedExtensionRows];
  return [NSString stringWithFormat:
      @"<h1>Extensions</h1>"
       "<section>"
       "<h2>Chrome Web Store</h2>"
       "<form method='get' action='babelchrome://extensions' class='searchForm'>"
       "<input type='search' name='search' placeholder='Search extensions' autofocus>"
       "<button type='submit'>Search</button>"
       "</form>"
       "</section>"
       "<section>"
       "<h2>Chrome Profile Extensions</h2>"
       "<p class='note'>Extensions installed by Chromium in the BabelChrome profile are listed here. Disable and Enable changes are applied on the next BabelChrome restart.</p>"
       "%@"
       "</section>"
       "<section>"
       "<h2>Unpacked Extensions</h2>"
       "<p class='note'>BabelChrome loads configured unpacked extension folders at startup. Changes require restarting BabelChrome.</p>"
       "<p><a class='primaryButton' href='babelchrome://extensions?addUnpacked=1'>Add unpacked extension folder</a></p>"
       "%@"
       "</section>"
       "<div class='bottomButtonRow'><a class='smallButton' data-can-open-menu='true' href='babelchrome://settings'>Back to Settings</a></div>",
      profileListHTML,
      unpackedListHTML];
}

- (NSString*)profileListHTMLWithRows:(NSArray<NSDictionary*>*)rows {
  if (0 == rows.count) {
    return @"<p class='empty'>No Chrome profile extension was found.</p>";
  }

  NSMutableString* listHTML = [NSMutableString stringWithString:@"<ul>"];
  for (NSDictionary* row in rows ?: @[]) {
    NSString* identifier = [self stringValueForKey:BabelExtensionProfileIdentifierKey inRow:row];
    NSString* restartHTML = [self boolValueForKey:BabelExtensionProfileRequiresRestartKey inRow:row]
        ? @"<a class='smallButton primarySmallButton' href='babelchrome://extensions?restart=1'>Restart</a>"
        : @"";
    [listHTML appendFormat:
        @"<li><span>%@</span><small>%@ - ID: %@ - Version: %@ - %@</small>"
         "<div class='actions'>%@<a class='smallButton' href='babelchrome://extensions?%@=%@'>%@</a>"
         "<a class='smallButton dangerButton iconTextButton' href='babelchrome://extensions?removeProfile=%@' title='Remove'>%@<span>Remove</span></a></div></li>",
        [self htmlEscapedString:[self stringValueForKey:BabelExtensionProfileNameKey inRow:row]],
        [self htmlEscapedString:[self stringValueForKey:BabelExtensionProfileStatusKey inRow:row]],
        [self htmlEscapedString:identifier],
        [self htmlEscapedString:[self stringValueForKey:BabelExtensionProfileVersionKey inRow:row]],
        [self htmlEscapedString:[self stringValueForKey:BabelExtensionProfilePathKey inRow:row]],
        restartHTML,
        [self queryEscapedString:[self stringValueForKey:BabelExtensionProfileToggleActionKey inRow:row]],
        [self queryEscapedString:identifier],
        [self htmlEscapedString:[self stringValueForKey:BabelExtensionProfileToggleLabelKey inRow:row]],
        [self queryEscapedString:identifier],
        trashIconHTML_];
  }
  [listHTML appendString:@"</ul>"];
  return listHTML;
}

- (NSString*)unpackedListHTMLWithRows:(NSArray<NSDictionary*>*)rows {
  if (0 == rows.count) {
    return @"<p class='empty'>No unpacked extension is configured.</p>";
  }

  NSMutableString* listHTML = [NSMutableString stringWithString:@"<ul>"];
  for (NSDictionary* row in rows ?: @[]) {
    NSString* path = [self stringValueForKey:BabelUnpackedExtensionPathKey inRow:row];
    [listHTML appendFormat:
        @"<li><span>%@</span><small>%@</small><div class='actions'>"
         "<a class='smallButton dangerButton iconTextButton' href='babelchrome://extensions?remove=%@' title='Remove'>%@<span>Remove</span></a>"
         "</div></li>",
        [self htmlEscapedString:[self stringValueForKey:BabelUnpackedExtensionNameKey inRow:row]],
        [self htmlEscapedString:[self stringValueForKey:BabelUnpackedExtensionStatusKey inRow:row]],
        [self queryEscapedString:path],
        trashIconHTML_];
  }
  [listHTML appendString:@"</ul>"];
  return listHTML;
}

- (NSString*)stringValueForKey:(NSString*)key inRow:(NSDictionary*)row {
  NSString* value = [row[key] isKindOfClass:NSString.class] ? row[key] : @"";
  return value ?: @"";
}

- (BOOL)boolValueForKey:(NSString*)key inRow:(NSDictionary*)row {
  NSNumber* value = [row[key] isKindOfClass:NSNumber.class] ? row[key] : @NO;
  return value.boolValue;
}

- (NSString*)queryEscapedString:(NSString*)value {
  NSCharacterSet* allowedCharacters = NSCharacterSet.URLQueryAllowedCharacterSet;
  return [value stringByAddingPercentEncodingWithAllowedCharacters:allowedCharacters] ?: @"";
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
