#ifndef BABEL_CHROME_BROWSER_MODULES_RUNTIME_NATIVE_MODULE_PROCESS_WEB_DEFINITION_H_
#define BABEL_CHROME_BROWSER_MODULES_RUNTIME_NATIVE_MODULE_PROCESS_WEB_DEFINITION_H_

#import <Foundation/Foundation.h>

/**
 * Describes a module-owned local HTTP process runtime.
 */
@interface BabelNativeModuleProcessWebDefinition : NSObject

@property(nonatomic, readonly, copy) NSString* command;
@property(nonatomic, readonly, copy) NSArray<NSString*>* args;
@property(nonatomic, readonly, copy) NSString* cwd;
@property(nonatomic, readonly, copy) NSDictionary<NSString*, NSString*>* env;
@property(nonatomic, readonly, copy) NSString* readyUrl;
@property(nonatomic, readonly) NSInteger timeoutMs;
@property(nonatomic, readonly, copy) NSString* stopSignal;
@property(nonatomic, readonly) NSInteger stopTimeoutMs;

/**
 * Creates a process-web definition from decoded manifest runtime data.
 *
 * @param runtime The decoded runtime declaration.
 * @return The process-web definition, or nil when required fields are invalid.
 */
+ (instancetype)definitionWithRuntimeDictionary:(NSDictionary*)runtime;

/**
 * Creates a process-web definition.
 *
 * @param command The executable command path or name.
 * @param args The command arguments.
 * @param cwd The working directory relative to the module root, or absolute.
 * @param env The environment variables added to the process.
 * @param readyUrl The readiness URL template.
 * @param timeoutMs The readiness timeout in milliseconds.
 * @param stopSignal The graceful stop signal name.
 * @param stopTimeoutMs The graceful stop timeout in milliseconds.
 * @return The process-web definition.
 */
- (instancetype)initWithCommand:(NSString*)command
                           args:(NSArray<NSString*>*)args
                            cwd:(NSString*)cwd
                            env:(NSDictionary<NSString*, NSString*>*)env
                       readyUrl:(NSString*)readyUrl
                      timeoutMs:(NSInteger)timeoutMs
                     stopSignal:(NSString*)stopSignal
                  stopTimeoutMs:(NSInteger)stopTimeoutMs;

/**
 * Returns the executable command and arguments as one command line array.
 *
 * @return The command line array.
 */
- (NSArray<NSString*>*)commandLine;

/**
 * Exports this definition as a serializable dictionary.
 *
 * @return The process-web dictionary.
 */
- (NSDictionary*)dictionaryRepresentation;

@end

#endif
