/*
 * Copyright (C) 2020 J.C. Fields (jcfields@jcfields.dev).
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

#import "AppDelegate.h"

NSString *const kTerminalAlerterBundleID = @"dev.jcfields.sorter";

@implementation NSBundle (FakeBundleIdentifier)

- (NSString *)__bundleIdentifier {
    if (self == [NSBundle mainBundle]) {
        return kTerminalAlerterBundleID;
    } else {
        return [self __bundleIdentifier];
    }
}

@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    // creates fake bundle identifier so notifications work
    [AppDelegate installFakeBundleIdentifierHook];
    
    NSArray *args = [[NSProcessInfo processInfo] arguments];
    
    int status = EXIT_FAILURE;
    
    if ([args count] == 2) {
        if ([args indexOfObject:@"-h"] != NSNotFound || [args indexOfObject:@"--help"] != NSNotFound) {
            [AppDelegate printHelp];
            status = EXIT_SUCCESS;
        } else {
            status = [self processOptions:[args objectAtIndex:1]];
        }
    } else {
        [AppDelegate printHelp];
        status = EXIT_SUCCESS;
    }
    
    exit(status);
}

- (int)processOptions:(NSString *)configFile {
    Configuration *config = [[Configuration alloc] init];
    RuleProcessor *processor = [[RuleProcessor alloc] init];
    
    @try {
        [config readFile:configFile];
        [processor processRules:config];
    } @catch (NSException *exception) {
        [AppDelegate printError:[exception reason]];
        return EXIT_FAILURE;
    }
    
    return EXIT_SUCCESS;
}

+ (void)printHelp {
    puts("Usage: sorter [config file]\n");
    puts("Applies sort rules to files in a directory based on the rules specified in the");
    puts("provided configuration file. See documentation for format specification.");
}

+ (void)printError:(NSString *)errorMsg {
    fprintf(stderr, "%s\n", [errorMsg UTF8String]);
}

+ (void)installFakeBundleIdentifierHook {
    Class class = objc_getClass("NSBundle");
    
    if (class) {
        method_exchangeImplementations(class_getInstanceMethod(class, @selector(bundleIdentifier)),
                                       class_getInstanceMethod(class, @selector(__bundleIdentifier)));
    }
}

@end
