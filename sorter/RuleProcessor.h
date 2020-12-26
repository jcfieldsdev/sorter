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
#import "Configuration.h"
#import "Match.h"
#import "Notifier.h"

NS_ASSUME_NONNULL_BEGIN

@interface RuleProcessor : NSObject

@property(retain) Match *match;

- (instancetype)init;
- (BOOL)processRules:(Configuration *)config;
- (BOOL)checkCondition:(NSString *)condition file:(File *)file;
- (BOOL)checkNumericCondition:(NSString *)method subject:(NSNumber *)subject value:(NSNumber *)value;
- (BOOL)checkStringCondition:(NSString *)method subject:(NSString *)subject value:(NSString *)value;
- (BOOL)checkDateCondition:(NSString *)method subject:(NSNumber *)subject value:(NSDate *)value;
- (BOOL)checkArrayCondition:(NSString *)method subject:(NSString *)subject value:(NSArray *)value;
- (BOOL)performAction:(NSString *)action file:(File *)file config:(Configuration *)config;
- (BOOL)renameToString:(NSString *)fileName file:(File *)file error:(NSError **)errorPtr;
- (BOOL)prependString:(NSString *)string file:(File *)file error:(NSError **)errorPtr;
- (BOOL)appendString:(NSString *)string file:(File *)file error:(NSError **)errorPtr;
- (BOOL)moveToPath:(NSString *)location file:(File *)file error:(NSError **)errorPtr;
- (BOOL)copyToPath:(NSString *)location file:(File *)file error:(NSError **)errorPtr;
- (BOOL)changeExtension:(NSString *)extension file:(File *)file error:(NSError **)errorPtr;
- (NSString *)formatDateString:(NSString *)dateString date:(NSDate *)date file:(File *)file error:(NSError **)errorPtr;
+ (NSArray *)tokenizeString:(NSString *)string limit:(NSUInteger)limit;

@end

NS_ASSUME_NONNULL_END
