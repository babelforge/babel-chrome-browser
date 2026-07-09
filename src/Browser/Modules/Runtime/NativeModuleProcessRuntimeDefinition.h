#ifndef BABEL_CHROME_BROWSER_MODULES_RUNTIME_NATIVE_MODULE_PROCESS_RUNTIME_DEFINITION_H_
#define BABEL_CHROME_BROWSER_MODULES_RUNTIME_NATIVE_MODULE_PROCESS_RUNTIME_DEFINITION_H_

#import <Foundation/Foundation.h>

@class BabelNativeModuleRuntimeCommand;

/**
 * Describes a module-owned non-web process runtime.
 */
@interface BabelNativeModuleProcessRuntimeDefinition : NSObject

@property(nonatomic, readonly, copy) NSString* mode;
@property(nonatomic, readonly, strong) BabelNativeModuleRuntimeCommand* command;
@property(nonatomic, readonly, copy) NSDictionary<NSString*, BabelNativeModuleRuntimeCommand*>* commands;
@property(nonatomic, readonly, copy) NSString* cwd;
@property(nonatomic, readonly, copy) NSDictionary<NSString*, NSString*>* env;
@property(nonatomic, readonly, copy) NSString* stopSignal;
@property(nonatomic, readonly) NSInteger stopTimeoutMs;

/**
 * Creates a process-runtime definition from decoded manifest runtime data.
 *
 * @param runtime The decoded runtime declaration.
 * @return The process-runtime definition, or nil when required fields are invalid.
 */
+ (instancetype)definitionWithRuntimeDictionary:(NSDictionary*)runtime;

/**
 * Creates a process-runtime definition.
 *
 * @param mode The process-runtime mode.
 * @param command The default process command.
 * @param commands The route-specific commands.
 * @param cwd The working directory relative to the module root, or absolute.
 * @param env The environment variables added to the process.
 * @param stopSignal The graceful stop signal name.
 * @param stopTimeoutMs The graceful stop timeout in milliseconds.
 * @return The process-runtime definition.
 */
- (instancetype)initWithMode:(NSString*)mode
                     command:(BabelNativeModuleRuntimeCommand*)command
                    commands:(NSDictionary<NSString*, BabelNativeModuleRuntimeCommand*>*)commands
                         cwd:(NSString*)cwd
                         env:(NSDictionary<NSString*, NSString*>*)env
                  stopSignal:(NSString*)stopSignal
               stopTimeoutMs:(NSInteger)stopTimeoutMs;

/**
 * Returns the command declared for a route, or the default command.
 *
 * @param route The requested module route.
 * @return The matching command.
 */
- (BabelNativeModuleRuntimeCommand*)commandForRoute:(NSString*)route;

/**
 * Exports this definition as a serializable dictionary.
 *
 * @return The process-runtime dictionary.
 */
- (NSDictionary*)dictionaryRepresentation;

@end

#endif
