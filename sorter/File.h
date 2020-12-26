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

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface File : NSObject

@property(retain) NSURL *URL;
@property(retain) NSURL *originalURL;
@property(retain) NSMutableDictionary *attributes;
@property(retain) NSDictionary *metaData;

- (instancetype)initWithURL:(NSURL *)URL;
- (void)updateURL:(NSURL *)URL;
- (void)loadFileManagerMetaData;
- (void)loadSpotlightMetaData;
- (NSNumber *)getNumericKey:(NSString *)key;
- (NSString *)getStringKey:(NSString *)key;
- (NSDate *)getDateKey:(NSString *)key;
- (NSArray *)getArrayKey:(NSString *)key;
- (BOOL)moveToDirectory:(NSString *)path error:(NSError **)errorPtr;
- (BOOL)moveToTrash:(NSError **)errorPtr;
- (BOOL)copyToPath:(NSString *)path error:(NSError **)errorPtr;
- (BOOL)createAliasAtPath:(NSString *)path error:(NSError **)errorPtr;
- (BOOL)addTag:(NSString *)tagName error:(NSError **)errorPtr;
- (BOOL)removeTag:(NSString *)tagName error:(NSError **)errorPtr;
- (BOOL)updateTags:(NSArray *)tags error:(NSError **)errorPtr;
- (void)runCommand:(NSArray *)subject;
+ (NSString *)generateUniqueFileName:(NSString *)path;

@end

NS_ASSUME_NONNULL_END
