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

#import "File.h"

@implementation File

- (instancetype)initWithURL:(NSURL *)URL {
    self = [super init];
    
    if (self != nil) {
        _originalURL = URL;
        _attributes = [NSMutableDictionary dictionary];
        
        [self updateURL:URL];
        
        [self loadFileManagerMetaData];
        [self loadSpotlightMetaData];
    }
    
    return self;
}

- (void)updateURL:(NSURL *)URL {
    _URL = URL;
    
    self.attributes[@"path"] = [URL path];
    self.attributes[@"location"] = [[URL path] stringByDeletingLastPathComponent];
    self.attributes[@"fileName"] = [[URL lastPathComponent] stringByDeletingPathExtension];
    self.attributes[@"fullFileName"] = [URL lastPathComponent];
    self.attributes[@"extension"] = [[URL path] pathExtension];
}

- (void)loadFileManagerMetaData {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSDictionary *attributes = [fileManager attributesOfItemAtPath:[self.URL path] error:nil];
    
    NSDate *dateCreated = [attributes fileCreationDate];
    NSDate *dateModified = [attributes fileModificationDate];
    
    NSArray *tags = [NSArray array];
    [self.URL getResourceValue:&tags forKey:NSURLTagNamesKey error:nil];
    
    self.attributes[@"fileSize"] = @([attributes fileSize]);
    self.attributes[@"dateCreated"] = dateCreated;
    self.attributes[@"dateModified"] = dateModified;
    self.attributes[@"sinceCreated"] = [NSNumber numberWithDouble:[dateCreated timeIntervalSinceNow]];
    self.attributes[@"sinceModified"] = [NSNumber numberWithDouble:[dateModified timeIntervalSinceNow]];
    self.attributes[@"tag"] = tags;
}

- (void)loadSpotlightMetaData {
    CFURLRef cfURL = CFBridgingRetain(self.URL);
    MDItemRef cfFile = MDItemCreateWithURL(kCFAllocatorDefault, cfURL);
    
    _metaData = (NSDictionary *)CFBridgingRelease(MDItemCopyAttributeList(cfFile,
        kMDItemAudioTrackNumber, kMDItemAuthors, kMDItemComposer,
        kMDItemAlbum, kMDItemContentType, kMDItemDurationSeconds,
        kMDItemFinderComment, kMDItemFSNodeCount, kMDItemKind,
        kMDItemLastUsedDate, kMDItemMusicalGenre, kMDItemNumberOfPages,
        kMDItemPageHeight, kMDItemPageWidth, kMDItemPixelHeight,
        kMDItemPixelWidth, kMDItemRecordingYear, kMDItemTitle,
        kMDItemWhereFroms
    ));
    
    CFRelease(cfURL);
    CFRelease(cfFile);
    
    NSDate *dateOpened = [self getDateKey:@"kMDItemLastUsedDate"];
    
    // general
    self.attributes[@"kind"] = [self getStringKey:@"kMDItemKind"];
    self.attributes[@"contentType"] = [self getStringKey:@"kMDItemContentType"];
    self.attributes[@"dateOpened"] = dateOpened;
    self.attributes[@"sinceOpened"] = [NSNumber numberWithDouble:[dateOpened timeIntervalSinceNow]];
    self.attributes[@"comment"] = [self getStringKey:@"kMDItemFinderComment"];
    self.attributes[@"author"] = [self getArrayKey:@"kMDItemAuthors"];
    self.attributes[@"sourceURL"] = [self getArrayKey:@"kMDItemWhereFroms"];
    
    // directories
    self.attributes[@"children"] = [self getNumericKey:@"kMDItemFSNodeCount"];
    
    // documents
    self.attributes[@"pages"] = [self getNumericKey:@"kMDItemNumberOfPages"];
    self.attributes[@"pageWidth"] = [self getNumericKey:@"kMDItemPageWidth"];
    self.attributes[@"pageHeight"] = [self getNumericKey:@"kMDItemPageHeight"];
    
    // images
    self.attributes[@"imageWidth"] = [self getNumericKey:@"kMDItemPixelWidth"];
    self.attributes[@"imageHeight"] = [self getNumericKey:@"kMDItemPixelHeight"];
    
    // audio
    self.attributes[@"title"] = [self getStringKey:@"kMDItemTitle"];
    self.attributes[@"composer"] = [self getStringKey:@"kMDItemComposer"];
    self.attributes[@"album"] = [self getStringKey:@"kMDItemAlbum"];
    self.attributes[@"genre"] = [self getStringKey:@"kMDItemMusicalGenre"];
    self.attributes[@"track"] = [self getNumericKey:@"kMDItemAudioTrackNumber"];
    self.attributes[@"duration"] = [self getNumericKey:@"kMDItemDurationSeconds"];
    self.attributes[@"year"] = [self getNumericKey:@"kMDItemRecordingYear"];
}

- (NSNumber *)getNumericKey:(NSString *)key {
    NSNumber *value = [self.metaData objectForKey:key];
    
    if (value == nil) {
        return @0;
    }
    
    return value;
}

- (NSString *)getStringKey:(NSString *)key {
    NSString *value = [self.metaData objectForKey:key];
    
    if (value == nil) {
        return [NSString string];
    }
    
    return value;
}

- (NSDate *)getDateKey:(NSString *)key {
    NSDate *value = [self.metaData objectForKey:key];
    
    if (value == nil) {
        return [NSDate date];
    }
    
    return value;
}

- (NSArray *)getArrayKey:(NSString *)key {
    NSArray *value = [self.metaData objectForKey:key];
    
    if (value == nil) {
        return [NSArray array];
    }
    
    return value;
}

- (BOOL)moveToDirectory:(NSString *)path error:(NSError **)errorPtr {
    NSString *oldPath = [self.URL path];
    NSString *newPath = [File generateUniqueFileName:[path stringByExpandingTildeInPath]];
    
    [[NSFileManager defaultManager] moveItemAtPath:oldPath toPath:newPath error:errorPtr];
    
    if (*errorPtr != nil) {
        return NO;
    }
    
    [self updateURL:[NSURL fileURLWithPath:newPath]];
    return YES;
}

- (BOOL)moveToTrash:(NSError **)errorPtr {
    NSURL *newURL = nil;
    [[NSFileManager defaultManager] trashItemAtURL:self.URL resultingItemURL:&newURL error:errorPtr];
    
    if (*errorPtr != nil) {
        return NO;
    }
    
    [self updateURL:newURL];
    return YES;
}

- (BOOL)copyToPath:(NSString *)path error:(NSError **)errorPtr {
    NSString *newPath = [File generateUniqueFileName:[path stringByExpandingTildeInPath]];
    NSURL *newURL = [NSURL fileURLWithPath:newPath];
    [[NSFileManager defaultManager] copyItemAtURL:self.URL toURL:newURL error:errorPtr];
    
    if (*errorPtr != nil) {
        return NO;
    }
    
    [self updateURL:newURL];
    return YES;
}

- (BOOL)createAliasAtPath:(NSString *)path error:(NSError **)errorPtr {
    if ([path length] == 0) {
        return NO;
    }
    
    NSString *newPath = [File generateUniqueFileName:[path stringByExpandingTildeInPath]];
    NSURL *newURL = [NSURL fileURLWithPath:newPath];
    NSData *bookmarkData = [self.URL
        bookmarkDataWithOptions:NSURLBookmarkCreationSuitableForBookmarkFile
        includingResourceValuesForKeys:nil
        relativeToURL:nil
        error:errorPtr];
    
    if (*errorPtr != nil) {
        return NO;
    }
    
    return [NSURL
        writeBookmarkData:bookmarkData
        toURL:newURL
        options:NSURLBookmarkCreationSuitableForBookmarkFile
        error:errorPtr];
}

- (BOOL)addTag:(NSString *)tagName error:(NSError **)errorPtr {
    if ([tagName length] == 0) {
        return NO;
    }
    
    NSMutableSet *tags = [NSMutableSet setWithArray:[self.attributes objectForKey:@"tag"]];
    [tags addObject:tagName];
    
    return [self updateTags:[tags allObjects] error:errorPtr];
}

- (BOOL)removeTag:(NSString *)tagName error:(NSError **)errorPtr {
    if ([tagName length] == 0) {
        return NO;
    }
    
    NSMutableSet *tags = [NSMutableSet setWithArray:[self.attributes objectForKey:@"tag"]];
    [tags removeObject:tagName];
    
    return [self updateTags:[tags allObjects] error:errorPtr];
}

- (BOOL)updateTags:(NSArray *)tags error:(NSError **)errorPtr {
    [self.URL setResourceValue:tags forKey:NSURLTagNamesKey error:errorPtr];
    
    if (*errorPtr != nil) {
        return NO;
    }
    
    self.attributes[@"tag"] = tags;
    return YES;
}

- (void)runCommand:(NSArray *)subject {
    NSPipe *pipe = [NSPipe pipe];
    NSFileHandle *file = [pipe fileHandleForReading];
    
    NSString *command = [subject objectAtIndex:0];
    NSMutableArray *arguments = [NSMutableArray array];
    
    if ([subject count] > 1) {
        NSRange range = NSMakeRange(1, [subject count] - 1);
        arguments = [NSMutableArray arrayWithArray:[subject subarrayWithRange:range]];
    }
    
    [arguments addObject:[self.URL path]];
    
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = command;
    task.arguments = arguments;
    task.standardOutput = pipe;
    
    [task launch];
    [task waitUntilExit];
    
    NSData *data = [file readDataToEndOfFile];
    [file closeFile];
    
    if ([data length] > 0) {
        NSString *output = [[NSString alloc]
            initWithBytes:[data bytes]
            length:[data length]
            encoding:NSUTF8StringEncoding];
        
        printf("Output of command \"%s\":\n%s",
            [command UTF8String],
            [output UTF8String]);
    }
}

+ (NSString *)generateUniqueFileName:(NSString *)path {
    // returns if name is unique
    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
        return path;
    }
    
    NSString *containingFolder = [path stringByDeletingLastPathComponent];
    NSString *fullFileName = [path lastPathComponent];
    NSString *fileName = [fullFileName stringByDeletingPathExtension];
    NSString *extension = [fullFileName pathExtension];
    
    NSUInteger number = 1; // starting value
    
    NSError *error = nil;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"-(\\d+)$" options:0 error:&error];
    NSTextCheckingResult *result = [regex firstMatchInString:fileName options:0 range:NSMakeRange(0, [fileName length])];
    
    // file name already ends with a number, so increments it
    if (error == nil && result != nil) {
        NSString *match = [fileName substringWithRange:[result rangeAtIndex:1]];
        
        fileName = [fileName substringToIndex:[fileName length] - [match length] - 1];
        number = [match integerValue] + 1;
    }
    
    NSString *formattedFileName = [NSString stringWithFormat:@"%@-%lu", fileName, number];
    NSString *newFullFileName = [@[formattedFileName, extension] componentsJoinedByString:@"."];
    NSString *newPath = [containingFolder stringByAppendingPathComponent:newFullFileName];
    
    // repeats until unique file name found
    return [File generateUniqueFileName:newPath];
}

@end
