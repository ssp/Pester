//
//  PSPowerManager.h
//  Pester
//
//  Created by Nicholas Riley on Mon Dec 23 2002.
//  Copyright (c) 2002 Nicholas Riley. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <IOKit/IOKitLib.h>

@interface PSPowerManager : NSObject {
    id delegate;
    io_connect_t root_port;
    io_object_t notifier;
}

- (id)initWithDelegate:(id)aDelegate;

+ (BOOL)autoWakeSupported;
+ (NSDate *)wakeTime;
+ (void)setWakeTime:(NSDate *)time;
+ (void)clearWakeTime;

@end

@interface NSObject (PSPowerManagerDelegate)

- (void)powerManagerWillSleep:(PSPowerManager *)powerManager;
- (BOOL)powerManagerShouldSleep:(PSPowerManager *)powerManager;
- (void)powerManagerDidWake:(PSPowerManager *)powerManager;

@end