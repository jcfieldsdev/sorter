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

#import "RuleProcessor.h"

NSUInteger const kConditionTokens = 3;
NSUInteger const kActionTokens = 2;

@implementation RuleProcessor

- (instancetype)init {
    self = [super init];
    
    if (self != nil) {
        _match = [[Match alloc] init];
    }
    
    return self;
}

- (BOOL)processRules:(Configuration *)config {
    Notifier *notifier = [[Notifier alloc] init];
    
    for (File *file in [config files]) {
        // resets regex match for each file
        self.match = [[Match alloc] init];
        
        for (id rule in [config rules]) {
            if (![rule isKindOfClass:[NSDictionary class]]) {
                continue;
            }
            
            id conditions = [rule objectForKey:@"conditions"];
            
            if (![conditions isKindOfClass:[NSArray class]]) {
                continue;
            }
            
            BOOL valid = YES;
            
            for (id condition in conditions) {
                if (!valid) {
                    break;
                }

                if (![condition isKindOfClass:[NSString class]]) {
                    continue;
                }
                
                // all conditions must be true
                valid &= [self checkCondition:condition file:file];
            }
            
            if (!valid) {
                continue;
            }
            
            id actions = [rule objectForKey:@"actions"];
            
            if (![actions isKindOfClass:[NSArray class]]) {
                continue;
            }

            BOOL status = NO;

            for (id action in actions) {
                if (![action isKindOfClass:[NSString class]]) {
                    continue;
                }
                
                status |= [self performAction:action file:file config:config];
            }
            
            if (status) { // at least one action completed successfully
                [notifier reportSuccessfulAction:file];
            }
        }
    }
    
    return YES;
}

- (BOOL)checkCondition:(NSString *)condition file:(File *)file {
    NSArray *tokens = [RuleProcessor tokenizeString:condition limit:kConditionTokens];
    
    if ([tokens count] < kConditionTokens - 1) {
        @throw [NSException
            exceptionWithName:@"MalformedConditionException"
            reason:@"Condition must have an attribute and an operator."
            userInfo:nil];
    }
    
    NSDictionary *attributes = [file attributes];
    
    NSString *key = [tokens firstObject];
    NSString *method = [tokens objectAtIndex:1];
    NSString *subject = [tokens count] > kConditionTokens - 1 ? [tokens objectAtIndex:2] : [NSString string];
    
    id value = [attributes objectForKey:key];
    
    if (value == nil) {
        NSString *errorMsg = [NSString
            stringWithFormat:@"Unknown attribute: %@",
            key];
        @throw [NSException
            exceptionWithName:@"UnknownAttributeException"
            reason:errorMsg
            userInfo:nil];
    }
    
    NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
    
    if ([value isKindOfClass:[NSNumber class]]) {
        return [self
            checkNumericCondition:method
            subject:[numberFormatter numberFromString:subject]
            value:value];
    } else if ([value isKindOfClass:[NSString class]]) {
        return [self
            checkStringCondition:method
            subject:subject
            value:value];
    } else if ([value isKindOfClass:[NSDate class]]) {
        return [self
            checkDateCondition:method
            subject:[numberFormatter numberFromString:subject]
            value:value];
    } else if ([value isKindOfClass:[NSArray class]]) {
        return [self
            checkArrayCondition:method
            subject:subject
            value:value];
    }
    
    return NO;
}

- (BOOL)checkNumericCondition:(NSString *)method subject:(NSNumber *)subject value:(NSNumber *)value {
    NSComparisonResult compare = [value compare:subject];
    
    if ([method isEqualToString:@"="] || [method isEqualToString:@"=="]
     || [method isEqualToString:@"is"] || [method isEqualToString:@"equalTo"]) {
        if (compare == NSOrderedSame) {
            return YES;
        }
    } else if ([method isEqualToString:@"!="] || [method isEqualToString:@"<>"]
            || [method isEqualToString:@"isNot"] || [method isEqualToString:@"notEqualTo"]) {
        if (compare != NSOrderedSame) {
            return YES;
        }
    } else if ([method isEqualToString:@"<"] || [method isEqualToString:@"lessThan"]) {
        if (compare == NSOrderedAscending) {
            return YES;
        }
    } else if ([method isEqualToString:@">"] || [method isEqualToString:@"greaterThan"]) {
        if (compare == NSOrderedDescending) {
            return YES;
        }
    } else if ([method isEqualToString:@"<="] || [method isEqualToString:@"lessThanOrEqualTo"]) {
        if (compare == NSOrderedSame || compare == NSOrderedAscending) {
            return YES;
        }
    } else if ([method isEqualToString:@">="] || [method isEqualToString:@"greaterThanOrEqualTo"]) {
        if (compare == NSOrderedSame || compare == NSOrderedDescending) {
            return YES;
        }
    } else {
        NSString *errorMsg = [NSString
            stringWithFormat:@"Unknown condition (for integer): %@",
            method];
        @throw [NSException
            exceptionWithName:@"UnknownMethodException"
            reason:errorMsg
            userInfo:nil];
    }
    
    return NO;
}

- (BOOL)checkStringCondition:(NSString *)method subject:(NSString *)subject value:(NSString *)value {
    // case insensitive
    value = [value lowercaseString];
    subject = [subject lowercaseString];
    
    if ([method isEqualToString:@"="] || [method isEqualToString:@"=="]
     || [method isEqualToString:@"is"] || [method isEqualToString:@"equalTo"]) {
        if ([value isEqualToString:subject]) {
            return YES;
        }
    } else if ([method isEqualToString:@"!="] || [method isEqualToString:@"<>"]
            || [method isEqualToString:@"isNot"] || [method isEqualToString:@"notEqualTo"]) {
        if (![value isEqualToString:subject]) {
            return YES;
        }
    } else if ([method isEqualToString:@"isEmpty"]) {
        if ([value length] == 0) {
            return YES;
        }
    } else if ([method isEqualToString:@"isNotEmpty"]) {
        if ([value length] > 0) {
            return YES;
        }
    } else if ([method isEqualToString:@"contains"] || [method isEqualToString:@"includes"]) {
        if ([value containsString:subject]) {
            return YES;
        }
    } else if ([method isEqualToString:@"doesNotContain"] || [method isEqualToString:@"doesNotInclude"]) {
        if (![value containsString:subject]) {
            return YES;
        }
    } else if ([method isEqualToString:@"=~"] || [method isEqualToString:@"matches"]) {
        [self.match matchPattern:subject condition:value];
        
        if ([self.match count] > 0) {
            return YES;
        }
    } else if ([method isEqualToString:@"!~"] || [method isEqualToString:@"doesNotMatch"]) {
        [self.match matchPattern:subject condition:value];
        
        if ([self.match count] == 0) {
            return YES;
        }
    } else if ([method isEqualToString:@"beginsWith"] || [method isEqualToString:@"startsWith"]) {
        if ([value hasPrefix:subject]) {
            return YES;
        }
    } else if ([method isEqualToString:@"endsWith"]) {
        if ([value hasSuffix:subject]) {
            return YES;
        }
    } else if ([method isEqualToString:@"doesNotBeginWith"] || [method isEqualToString:@"doesNotStartWith"]) {
        if (![value hasPrefix:subject]) {
            return YES;
        }
    } else if ([method isEqualToString:@"doesNotEndWith"]) {
        if (![value hasSuffix:subject]) {
            return YES;
        }
    } else {
        NSString *errorMsg = [NSString
            stringWithFormat:@"Unknown condition (for string): %@",
            method];
        @throw [NSException
            exceptionWithName:@"UnknownMethodException"
            reason:errorMsg
            userInfo:nil];
    }
    
    return NO;
}

- (BOOL)checkDateCondition:(NSString *)method subject:(NSNumber *)subject value:(NSDate *)value {
    // treats dates as Unix epoch for comparisons
    NSNumber *timestamp = [NSNumber numberWithDouble:[value timeIntervalSince1970]];
    return [self checkNumericCondition:method subject:subject value:timestamp];
}

- (BOOL)checkArrayCondition:(NSString *)method subject:(NSString *)subject value:(NSArray *)value {
    BOOL valid = NO;
    
    for (NSString *row in value) {
        // special case for tags, which have tag name and color number separated by newline
        NSString *firstLine = [[row componentsSeparatedByString:@"\n"] firstObject];
        
        // any condition can be true to pass
        valid |= [self checkStringCondition:method subject:subject value:firstLine];
    }
    
    return valid;
}

- (BOOL)performAction:(NSString *)action file:(File *)file config:(Configuration *)config {
    NSArray *tokens = [RuleProcessor tokenizeString:action limit:kActionTokens];
    
    if ([tokens count] < kActionTokens - 1) {
        @throw [NSException
            exceptionWithName:@"MalformedActionException"
            reason:@"Action must have a method and a subject."
            userInfo:nil];
    }
    
    NSDictionary *attributes = [file attributes];
    
    NSString *method = [tokens firstObject];
    NSString *subject = [tokens count] > kActionTokens - 1 ? [tokens objectAtIndex:1] : [NSString string];
    
    NSError *error = nil;
    
    if ([method hasPrefix:@"renameTo"]) {
        if ([method hasSuffix:@"CurrentDate"]) {
            NSString *formatted = [self formatDateString:subject date:[NSDate date] file:file error:&error];
            [self renameToString:formatted file:file error:&error];
        } else if ([method hasSuffix:@"DateCreated"]) {
            NSDate *date = [attributes objectForKey:@"dateCreated"];
            NSString *formatted = [self formatDateString:subject date:date file:file error:&error];
            
            [self renameToString:formatted file:file error:&error];
        } else if ([method hasSuffix:@"DateModified"]) {
            NSDate *date = [attributes objectForKey:@"dateModified"];
            NSString *formatted = [self formatDateString:subject date:date file:file error:&error];
            
            [self renameToString:formatted file:file error:&error];
        } else if ([method hasSuffix:@"DateOpened"]) {
            NSDate *date = [attributes objectForKey:@"dateOpened"];
            NSString *formatted = [self formatDateString:subject date:date file:file error:&error];
            
            [self renameToString:formatted file:file error:&error];
        } else if ([method hasSuffix:@"Matches"]) {
            NSString *formatted = [self.match replaceMatchesInString:subject];
            
            if ([formatted length] > 0) {
                [self renameToString:formatted file:file error:&error];
            }
        } else {
            [self renameToString:subject file:file error:&error];
        }
    } else if ([method hasPrefix:@"prepend"]) {
        if ([method hasSuffix:@"CurrentDate"]) {
            NSString *formatted = [self formatDateString:subject date:[NSDate date] file:file error:&error];
            [self prependString:formatted file:file error:&error];
        } else if ([method hasSuffix:@"DateCreated"]) {
            NSDate *date = [attributes objectForKey:@"dateCreated"];
            NSString *formatted = [self formatDateString:subject date:date file:file error:&error];
            
            [self prependString:formatted file:file error:&error];
        } else if ([method hasSuffix:@"DateModified"]) {
            NSDate *date = [attributes objectForKey:@"dateModified"];
            NSString *formatted = [self formatDateString:subject date:date file:file error:&error];
            
            [self prependString:formatted file:file error:&error];
        } else if ([method hasSuffix:@"DateOpened"]) {
            NSDate *date = [attributes objectForKey:@"dateOpened"];
            NSString *formatted = [self formatDateString:subject date:date file:file error:&error];
            
            [self prependString:formatted file:file error:&error];
        } else if ([method hasSuffix:@"Matches"]) {
            NSString *formatted = [self.match replaceMatchesInString:subject];
            
            if ([formatted length] > 0) {
                [self renameToString:formatted file:file error:&error];
            }
        } else {
            [self prependString:subject file:file error:&error];
        }
    } else if ([method hasPrefix:@"append"]) {
        if ([method hasSuffix:@"CurrentDate"]) {
            NSString *formatted = [self formatDateString:subject date:[NSDate date] file:file error:&error];
            [self appendString:formatted file:file error:&error];
        } else if ([method hasSuffix:@"DateCreated"]) {
            NSDate *date = [attributes objectForKey:@"dateCreated"];
            NSString *formatted = [self formatDateString:subject date:date file:file error:&error];
            
            [self appendString:formatted file:file error:&error];
        } else if ([method hasSuffix:@"DateModified"]) {
            NSDate *date = [attributes objectForKey:@"dateModified"];
            NSString *formatted = [self formatDateString:subject date:date file:file error:&error];
            
            [self appendString:formatted file:file error:&error];
        } else if ([method hasSuffix:@"DateOpened"]) {
            NSDate *date = [attributes objectForKey:@"dateOpened"];
            NSString *formatted = [self formatDateString:subject date:date file:file error:&error];
            
            [self appendString:formatted file:file error:&error];
        } else if ([method hasSuffix:@"Matches"]) {
            NSString *formatted = [self.match replaceMatchesInString:subject];
            
            if ([formatted length] > 0) {
                [self renameToString:formatted file:file error:&error];
            }
        } else {
            [self appendString:subject file:file error:&error];
        }
    } else if ([method hasPrefix:@"moveTo"]) {
        if ([method hasSuffix:@"Trash"]) {
            [file moveToTrash:&error];
        } else {
            [self moveToPath:subject file:file error:&error];
        }
    } else if ([method isEqualToString:@"copyTo"]) {
        [self copyToPath:subject file:file error:&error];
    } else if ([method isEqualToString:@"changeExtensionTo"]) {
        [self changeExtension:subject file:file error:&error];
    } else if ([method isEqualToString:@"makeAliasAt"]) {
        [file createAliasAtPath:subject error:&error];
    } else if ([method isEqualToString:@"addTag"]) {
        [file addTag:subject error:&error];
    } else if ([method isEqualToString:@"removeTag"]) {
        [file removeTag:subject error:&error];
    } else if ([method isEqualToString:@"runCommand"]) {
        if (![config allowExec]) {
            NSString *errorMsg = [NSString
                stringWithFormat:@"Must enable \"allowExec\" option for action: %@",
                method];
            @throw [NSException
                exceptionWithName:@"ProhibitedActionException"
                reason:errorMsg
                userInfo:nil];
        }
        
        [file runCommand:[subject componentsSeparatedByString:@" "]];
    }
    
    if (error != nil) {
        NSString *errorMsg = [NSString
            stringWithFormat:@"Could not perform action: %@\n%@",
            method,
            [error localizedDescription]];
        @throw [NSException
            exceptionWithName:@"ActionException"
            reason:errorMsg
            userInfo:nil];
    }
    
    return YES;
}

- (BOOL)renameToString:(NSString *)fileName file:(File *)file error:(NSError **)errorPtr {
    if ([fileName length] == 0) {
        return NO;
    }
    
    NSDictionary *attributes = [file attributes];
    NSString *extension = [attributes objectForKey:@"extension"];
    
    NSString *newFileName = nil;
    
    if ([extension length] > 0) {
        newFileName = [@[fileName, extension] componentsJoinedByString:@"."];
    } else { // no file extension
        newFileName = fileName;
    }
    
    NSString *location = [attributes objectForKey:@"location"];
    NSString *newPath = [location stringByAppendingPathComponent:newFileName];
    
    return [file moveToDirectory:newPath error:errorPtr];
}

- (BOOL)prependString:(NSString *)string file:(File *)file error:(NSError **)errorPtr {
    NSDictionary *attributes = [file attributes];
    NSString *fileName = [attributes objectForKey:@"fileName"];
    
    return [self renameToString:[string stringByAppendingString:fileName] file:file error:errorPtr];
}

- (BOOL)appendString:(NSString *)string file:(File *)file error:(NSError **)errorPtr {
    NSDictionary *attributes = [file attributes];
    NSString *fileName = [attributes objectForKey:@"fileName"];
    
    return [self renameToString:[fileName stringByAppendingString:string] file:file error:errorPtr];
}

- (BOOL)moveToPath:(NSString *)location file:(File *)file error:(NSError **)errorPtr {
    if ([location length] == 0) {
        return NO;
    }
    
    NSDictionary *attributes = [file attributes];
    NSString *fileName = [attributes objectForKey:@"fullFileName"];
    NSString *newPath = [location stringByAppendingPathComponent:fileName];
    
    return [file moveToDirectory:newPath error:errorPtr];
}

- (BOOL)copyToPath:(NSString *)location file:(File *)file error:(NSError **)errorPtr {
    if ([location length] == 0) {
        return NO;
    }
    
    NSDictionary *attributes = [file attributes];
    NSString *fileName = [attributes objectForKey:@"fullFileName"];
    NSString *newPath = [location stringByAppendingPathComponent:fileName];
    
    return [file copyToPath:newPath error:errorPtr];
}

- (BOOL)changeExtension:(NSString *)extension file:(File *)file error:(NSError **)errorPtr {
    if ([extension length] == 0) {
        return NO;
    }
    
    NSDictionary *attributes = [file attributes];
    NSString *oldFileName = [attributes objectForKey:@"fileName"];
    NSString *newFileName = nil;
    
    if ([extension length] > 0) {
        newFileName = [@[oldFileName, extension] componentsJoinedByString:@"."];
    } else { // no file extension
        newFileName = oldFileName;
    }
    
    NSString *location = [attributes objectForKey:@"location"];
    NSString *newPath = [location stringByAppendingPathComponent:newFileName];
    
    return [file moveToDirectory:newPath error:errorPtr];
}

- (NSString *)formatDateString:(NSString *)dateString date:(NSDate *)date file:(File *)file error:(NSError **)errorPtr {
    if ([dateString length] == 0) {
        return [NSString string];
    }
    
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.dateFormat = dateString;
    NSString *formatted = [dateFormatter stringFromDate:date];
    
    return formatted;
}

+ (NSArray *)tokenizeString:(NSString *)string limit:(NSUInteger)limit {
    NSRegularExpression *regex = [NSRegularExpression
        regularExpressionWithPattern:@"\\s+"
        options:NSRegularExpressionCaseInsensitive
        error:nil];
    NSArray *matches = [regex
        matchesInString:string
        options:0
        range:NSMakeRange(0, [string length])];
    
    NSMutableArray *tokens = [NSMutableArray array];
    NSUInteger last = 0;
    
    for (int i = 0; i < MIN([matches count], limit - 1); i++) {
        NSTextCheckingResult *result = [matches objectAtIndex:i];
        NSRange range = [result rangeAtIndex:0];
        NSString *slice = [string substringWithRange:NSMakeRange(last, range.location - last)];
        [tokens addObject:slice];
        last += range.length + [slice length];
    }
    
    [tokens addObject:[string substringWithRange:NSMakeRange(last, [string length] - last)]];
    return tokens;
}

@end
