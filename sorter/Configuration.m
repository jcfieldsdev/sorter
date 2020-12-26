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

#import "Configuration.h"

@implementation Configuration

- (instancetype)init {
    self = [super init];
    
    if (self != nil) {
        _path = [NSString string];
        
        _data = [NSDictionary dictionary];
        _files = [NSArray array];
        _rules = [NSArray array];
        
        _allowExec = NO;
    }

    return self;
}

- (void)readFile:(NSString *)path {
    self.path = [path stringByExpandingTildeInPath];
    
    self.data = [self readConfig];
    self.files = [self readDirectory];
    self.rules = [self readRules];
}

- (NSDictionary *)readConfig {
    if (![[NSFileManager defaultManager] fileExistsAtPath:self.path]) {
        NSString *errorMsg = [NSString
            stringWithFormat:@"Could not find configuration file: %@",
            self.path];
        @throw [NSException
            exceptionWithName:@"FileDoesNotExistException"
            reason:errorMsg
            userInfo:nil];
    }
    
    NSError *error = nil;
    NSData *fileContents = [NSData
        dataWithContentsOfFile:self.path
        options:NSDataReadingUncached
        error:&error];
    id data = [NSJSONSerialization
        JSONObjectWithData:fileContents
        options:0
        error:&error];
    
    if (error != nil) {
        NSString *errorMsg = [NSString
            stringWithFormat:@"Could not read configuration file: %@",
            [error localizedDescription]];
        @throw [NSException
            exceptionWithName:@"FileReadException"
            reason:errorMsg
            userInfo:nil];
    }
    
    if (![data isKindOfClass:[NSDictionary class]]) {
        @throw [NSException
            exceptionWithName:@"InvalidFormatException"
            reason:@"Invalid configuration file. See documentation for format specification."
            userInfo:nil];
    }
    
    return data;
}

- (NSString *)getWorkingDirectory {
    id workingDirectory = [self.data objectForKey:@"directory"];
    
    if (workingDirectory == nil || ![workingDirectory isKindOfClass:[NSString class]]) {
        @throw [NSException
            exceptionWithName:@"MissingDirectoryKeyException"
            reason:@"No directory key in configuration file."
            userInfo:nil];
    }
    
    workingDirectory = [workingDirectory stringByExpandingTildeInPath];
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:workingDirectory]) {
        NSString *errorMsg = [NSString
            stringWithFormat:@"Could not read directory: %@",
            workingDirectory];
        @throw [NSException
            exceptionWithName:@"DirectoryReadError"
            reason:errorMsg
            userInfo:nil];
    }
    
    return workingDirectory;
}

- (NSArray *)readDirectory {
    id options = [self.data objectForKey:@"options"];
    BOOL skipDirectories = YES;
    NSUInteger enumeratorOptions = 0;
    
    // applies options
    if (options != nil && [options isKindOfClass:[NSDictionary class]]) {
        NSDictionary *options = [self.data objectForKey:@"options"];
        skipDirectories = ![[options objectForKey:@"directories"] boolValue];
        
        if (![[options objectForKey:@"subdirectories"] boolValue]) {
            enumeratorOptions |= NSDirectoryEnumerationSkipsSubdirectoryDescendants;
        }
        
        if (![[options objectForKey:@"hidden"] boolValue]) {
            enumeratorOptions |= NSDirectoryEnumerationSkipsHiddenFiles;
        }
        
        self.allowExec = [[options objectForKey:@"allowExec"] boolValue];
    }
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSDirectoryEnumerator *directoryEnumerator = [fileManager
        enumeratorAtURL:[[NSURL alloc] initWithString:self.getWorkingDirectory]
        includingPropertiesForKeys:[NSArray arrayWithObject:NSURLIsDirectoryKey]
        options:enumeratorOptions
        errorHandler:^BOOL(NSURL *URL, NSError *error) {
            return YES; // continues on error
        }
    ];
    
    NSMutableArray *files = [NSMutableArray array];
    
    for (NSURL *URL in directoryEnumerator) {
        BOOL isDirectory = NO;
        [fileManager fileExistsAtPath:[URL path] isDirectory:&isDirectory];
        
        if (isDirectory && skipDirectories) {
            continue;
        }
        
        [files addObject:[[File alloc] initWithURL:URL]];
    }
    
    return [NSArray arrayWithArray:files];
}

- (NSArray *)readRules {
    id rules = [self.data objectForKey:@"rules"];
    
    if (rules == nil || ![rules isKindOfClass:[NSArray class]]) {
        @throw [NSException
            exceptionWithName:@"MissingRulesKeyException"
            reason:@"No rules key in configuration file."
            userInfo:nil];
    }
    
    return rules;
}

@end
