//
//  PSSpeechAlert.h
//  Pester
//
//  Created by Nicholas Riley on Sat Oct 26 2002.
//  Copyright (c) 2002 __MyCompanyName__. All rights reserved.
//

#import "PSAlert.h"

@class SUSpeaker;

@interface PSSpeechAlert : PSAlert {
    SUSpeaker *speaker;
    NSString *voice;
    PSAlarm *alarm;
}

+ (PSSpeechAlert *)alertWithVoice:(NSString *)aVoice;

- (id)initWithVoice:(NSString *)aVoice;

- (NSString *)voice;

@end
