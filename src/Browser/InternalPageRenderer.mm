#import "Browser/InternalPageRenderer.h"

#import <Cocoa/Cocoa.h>

#import "Browser/BrowserTheme.h"

@implementation BabelInternalPageRenderer

- (NSString*)internalPageHTMLWithTitle:(NSString*)title body:(NSString*)body {
  NSString* bodyClass = [self internalPagesUseDarkTheme] ? @"dark" : @"light";
  return [NSString stringWithFormat:
      @"<!doctype html><html><head><meta charset='utf-8'>"
       "<title>%@</title>"
       "<style>"
       "body{font:14px -apple-system,BlinkMacSystemFont,'Helvetica Neue',sans-serif;margin:0;color:#1f2933;background:#f7f8fa;}"
       "main{max-width:920px;margin:0 auto;padding:34px 42px;}"
       "h1{font-size:30px;margin:0 0 24px;}h2{font-size:16px;margin:28px 0 12px;color:#44515f;}"
       "ul{list-style:none;margin:0;padding:0;border:1px solid #d8dde3;border-radius:8px;background:white;overflow:hidden;}"
       "li{display:grid;grid-template-columns:minmax(160px,1fr) minmax(260px,2fr) minmax(180px,auto);gap:18px;padding:12px 14px;border-top:1px solid #eef1f4;align-items:center;}"
       "li:first-child{border-top:0;}span{font-weight:600;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;}"
       "small{color:#526171;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;}em{color:#7a8794;font-style:normal;text-align:right;}"
       "dl{display:grid;grid-template-columns:180px 1fr;gap:12px 18px;background:white;border:1px solid #d8dde3;border-radius:8px;padding:18px;}"
       "dt{font-weight:700;}dd{margin:0;color:#526171;}"
       ".options{display:grid;grid-template-columns:repeat(2,minmax(180px,1fr));gap:10px;}"
       ".option{display:block;text-decoration:none;color:#243447;border:1px solid #d8dde3;border-radius:8px;padding:12px;background:#f9fafb;cursor:pointer;}"
       ".option strong{display:block;margin-bottom:5px;color:#172533;}.option span{display:block;color:#526171;line-height:1.35;}"
       ".option.selected{border-color:#1473e6;background:#edf5ff;box-shadow:inset 0 0 0 1px #1473e6;}"
       ".stripedList li:nth-child(odd){background:#fff;}.stripedList li:nth-child(even){background:#f3f8ff;}"
       ".primaryButton,.smallButton,button{display:inline-flex;align-items:center;justify-content:center;border:1px solid #c7d0db;border-radius:7px;background:#fff;color:#172533;text-decoration:none;font-weight:700;min-height:32px;padding:0 12px;cursor:pointer;}"
       ".primaryButton{background:#1473e6;border-color:#1473e6;color:#fff;}.smallButton{min-height:26px;font-size:12px;}"
       ".primarySmallButton{border-color:#1473e6;background:#1473e6;color:#fff;}"
       ".buttonRow{display:flex;align-items:center;gap:8px;flex-wrap:wrap;}"
       ".gearMenu{position:relative;}.gearMenu summary{display:inline-flex;align-items:center;justify-content:center;width:54px;min-height:38px;border:1px solid #c7d0db;border-radius:7px;background:#fff;color:#172533;cursor:pointer;list-style:none;}"
       ".gearMenu summary::-webkit-details-marker{display:none;}.gearMenuPanel{position:absolute;z-index:10;right:0;top:46px;display:grid;gap:8px;min-width:190px;padding:10px;background:#fff;border:1px solid #d8dde3;border-radius:8px;box-shadow:0 10px 28px rgba(20,32,45,.18);}"
       ".updatesForm{display:grid;gap:10px;}.updatesToolbar{display:flex;align-items:center;justify-content:space-between;gap:12px;background:#fff;border:1px solid #d8dde3;border-radius:8px;padding:10px 12px;}"
       ".updatesToolbar label,.updateCheckbox{display:inline-flex;align-items:center;gap:7px;font-weight:700;color:#243447;cursor:pointer;}.updateList input{cursor:pointer;}"
       ".moduleList .moduleItem{grid-template-columns:minmax(0,1fr) 230px;gap:18px;align-items:center;}"
       ".moduleText{min-width:0;display:grid;grid-template-columns:minmax(0,1fr) auto;gap:5px 14px;align-items:center;}"
       ".moduleText span,.moduleText small{min-width:0;}.moduleText span,.moduleText small{display:block;}.moduleText em{text-align:left;}"
       ".moduleText .note{grid-column:1 / -1;margin:0;}"
       ".moduleButtons{display:grid;grid-template-columns:repeat(2,minmax(92px,1fr));gap:8px;align-content:center;}"
       ".moduleButtonCell{min-height:26px;}.moduleButtonCell .smallButton{width:100%%;box-sizing:border-box;}"
       ".bottomButtonRow{display:flex;justify-content:flex-start;margin-top:14px;}"
       "li>.note{grid-column:1 / 3;margin:0;}"
       "li>.actions{grid-column:3;grid-row:1 / span 2;}"
       ".actions{display:flex;align-items:center;justify-content:flex-end;gap:8px;min-width:0;flex-wrap:wrap;}"
       ".routeList{grid-column:1 / 3;display:flex;align-items:center;gap:7px;flex-wrap:wrap;min-width:0;}"
       ".routeList code{font:12px ui-monospace,SFMono-Regular,Menlo,monospace;background:#f1f5f9;border:1px solid #d8dde3;border-radius:6px;padding:3px 6px;color:#273849;}"
       ".routeList span{color:#7a8794;font-weight:700;}"
       ".dangerButton{border-color:#f0b9b9;color:#8a1f1f;background:#fff8f8;}.iconTextButton{gap:6px;}"
       ".buttonIcon{width:14px;height:14px;fill:currentColor;flex:0 0 auto;}.gearIcon{width:24px;height:24px;}"
       ".searchForm{display:grid;grid-template-columns:minmax(220px,1fr) auto;gap:10px;max-width:620px;}"
       "input{font:inherit;border:1px solid #c7d0db;border-radius:7px;padding:8px 10px;background:#fff;}"
       ".note,.empty{color:#526171;line-height:1.45;}.empty{background:#fff;border:1px solid #d8dde3;border-radius:8px;padding:14px;}"
       "body.dark{color:#e7edf5;background:#15171a;}"
       "body.dark h2{color:#c8d3df;}"
       "body.dark ul,body.dark dl,body.dark .empty{background:#1e2227;border-color:#343b44;}"
       "body.dark li{border-top-color:#2d333b;}"
       "body.dark small,body.dark dd,body.dark .note,body.dark .empty{color:#aeb8c4;}"
       "body.dark em,body.dark .routeList span{color:#8f9ba8;}"
       "body.dark .option{color:#dbe5f0;border-color:#343b44;background:#20252b;}"
       "body.dark .option strong{color:#f4f7fb;}body.dark .option span{color:#aeb8c4;}"
       "body.dark .option.selected{border-color:#5ea1ff;background:#193149;box-shadow:inset 0 0 0 1px #5ea1ff;}"
       "body.dark .stripedList li:nth-child(odd){background:#1e2227;}body.dark .stripedList li:nth-child(even){background:#202a35;}"
       "body.dark .primaryButton,body.dark .smallButton,body.dark button{border-color:#46515d;background:#242a31;color:#f4f7fb;}"
       "body.dark .primaryButton,body.dark .primarySmallButton{background:#2f7de1;border-color:#2f7de1;color:#fff;}"
       "body.dark .gearMenu summary,body.dark .gearMenuPanel,body.dark .updatesToolbar{border-color:#343b44;background:#1e2227;color:#f4f7fb;}"
       "body.dark .gearMenuPanel{box-shadow:0 10px 28px rgba(0,0,0,.32);}body.dark .updatesToolbar label,body.dark .updateCheckbox{color:#dbe5f0;}"
       "body.dark .dangerButton{border-color:#7f3a43;color:#ffb6bf;background:#321d22;}"
       "body.dark input{background:#1e2227;border-color:#46515d;color:#f4f7fb;}"
       "body.dark .routeList code{background:#20252b;border-color:#343b44;color:#dbe5f0;}"
       "</style></head><body class='%@'><main>%@</main>"
       "<script>"
       "document.addEventListener('click',(event)=>{"
       "document.querySelectorAll('.gearMenu[open]').forEach((menu)=>{"
       "if(!menu.contains(event.target)){menu.removeAttribute('open');}"
       "});"
       "});"
       "document.addEventListener('keydown',(event)=>{"
       "if(event.key==='Escape'){document.querySelectorAll('.gearMenu[open]').forEach((menu)=>menu.removeAttribute('open'));}"
       "});"
       "document.addEventListener('contextmenu',(event)=>{"
       "const control=event.target.closest('a.smallButton,a.primaryButton,a.option,button,summary');"
       "if(control&&control.dataset.canOpenMenu!=='true'){event.preventDefault();}"
       "},true);"
       "</script></body></html>",
      [self htmlEscapedString:title],
      bodyClass,
      body ?: @""];
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

- (BOOL)internalPagesUseDarkTheme {
  NSString* mode = [BabelTheme.sharedTheme appearanceMode];
  if ([mode isEqualToString:BabelThemeAppearanceDark]) {
    return YES;
  }

  if ([mode isEqualToString:BabelThemeAppearanceLight]) {
    return NO;
  }

  NSAppearanceName name = [NSApp.effectiveAppearance bestMatchFromAppearancesWithNames:@[
    NSAppearanceNameAqua,
    NSAppearanceNameDarkAqua
  ]];
  return [name isEqualToString:NSAppearanceNameDarkAqua];
}

@end
