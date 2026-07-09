#ifndef BABEL_CHROME_BROWSER_MODULES_RUNTIME_NATIVE_MODULE_RUNTIME_COMMAND_H_
#define BABEL_CHROME_BROWSER_MODULES_RUNTIME_NATIVE_MODULE_RUNTIME_COMMAND_H_

#import <Foundation/Foundation.h>

/**
 * Describes one module-owned process command declared in a manifest.
 */
@interface BabelNativeModuleRuntimeCommand : NSObject

@property(nonatomic, readonly, copy) NSString* command;
@property(nonatomic, readonly, copy) NSArray<NSString*>* args;
@property(nonatomic, readonly) NSInteger timeoutMs;

/**
 * Creates a command declaration from decoded manifest data.
 *
 * @param data The decoded command declaration.
 * @param defaultTimeoutMs The timeout used when no valid timeout is declared.
 * @return The command declaration, or nil when the manifest data is invalid.
 */
+ (instancetype)commandWithDictionary:(NSDictionary*)data
                     defaultTimeoutMs:(NSInteger)defaultTimeoutMs;

/**
 * Creates a command declaration.
 *
 * @param command The executable command path or name.
 * @param args The command arguments.
 * @param timeoutMs The command timeout in milliseconds.
 * @return The command declaration.
 */
- (instancetype)initWithCommand:(NSString*)command
                           args:(NSArray<NSString*>*)args
                      timeoutMs:(NSInteger)timeoutMs;

/**
 * Returns the executable command and arguments as one command line array.
 *
 * @return The command line array.
 */
- (NSArray<NSString*>*)commandLine;

/**
 * Exports this command as a serializable dictionary.
 *
 * @return The command dictionary.
 */
- (NSDictionary*)dictionaryRepresentation;

@end

#endif
