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

#import "Notifier.h"

NSString *const kNotificationCenterUIBundleID = @"com.apple.notificationcenterui";

// limits try to keep entire message visible in notification
NSUInteger const kShortName = 24;
NSUInteger const kLongName = 48;

@implementation Notifier

- (instancetype)init {
    self = [super init];
    
    if (self != nil) {
        NSUserNotificationCenter *center = [NSUserNotificationCenter defaultUserNotificationCenter];
        center.delegate = self;
        
        _center = center;
    }
    
    return self;
}

- (void)reportSuccessfulAction:(File *)file {
    NSString *oldLocation = [[[file originalURL] path] stringByDeletingLastPathComponent];
    NSString *newLocation = [[[file URL] path] stringByDeletingLastPathComponent];
    BOOL moved = ![oldLocation isEqualToString:newLocation];
    
    NSString *oldFileName = [[file originalURL] lastPathComponent];
    NSString *newFileName = [[file URL] lastPathComponent];
    BOOL renamed = ![oldFileName isEqualToString:newFileName];
    
    if (moved && renamed) {
        NSString *message = [NSString
            stringWithFormat:@"The file “%@” was renamed to “%@” and moved to “%@”.",
            [Notifier formatString:oldFileName length:kShortName],
            [Notifier formatString:newFileName length:kLongName],
            [Notifier formatString:[newLocation lastPathComponent] length:kLongName]];
        [self deliverNotification:message title:@"Moved and Renamed File"];
    } else {
        if (moved) {
            NSString *message = [NSString
                stringWithFormat:@"The file “%@” was moved from “%@” to “%@”.",
                [Notifier formatString:oldFileName length:kShortName],
                [Notifier formatString:[oldLocation lastPathComponent] length:kLongName],
                [Notifier formatString:[newLocation lastPathComponent] length:kLongName]];
            [self deliverNotification:message title:@"Moved File"];
        } else if (renamed) {
            NSString *message = [NSString
                stringWithFormat:@"The file “%@” was renamed to “%@”.",
                [Notifier formatString:oldFileName length:kLongName],
                [Notifier formatString:newFileName length:kLongName]];
            [self deliverNotification:message title:@"Renamed File"];
        }
    }
}

- (void)deliverNotification:(NSString *)message title:(NSString *)title {
    NSArray *runningProcesses = [[[NSWorkspace sharedWorkspace] runningApplications] valueForKey:@"bundleIdentifier"];
    
    // checks if notification center is running
    if ([runningProcesses indexOfObject:kNotificationCenterUIBundleID] == NSNotFound) {
        return;
    }
    
    NSUserNotification *userNotification = [[NSUserNotification alloc] init];
    userNotification.title = title;
    userNotification.informativeText = message;
    userNotification.hasActionButton = NO;
    
    [self.center deliverNotification:userNotification];
}

+ (NSString *)formatString:(NSString *)original length:(NSUInteger)length {
    if ([original length] > length + 2) {
        original = [[original substringToIndex:length] stringByAppendingString:@"…"];
    }
    
    return [original stringByReplacingOccurrencesOfString:@":" withString:@"/"];
}

#pragma mark - NSUserNotificationCenterDelegate

- (BOOL)userNotificationCenter:(NSUserNotificationCenter *)center shouldPresentNotification:(NSUserNotification *)notification {
    return YES;
}

@end
