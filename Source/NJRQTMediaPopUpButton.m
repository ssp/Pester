//
//  NJRQTMediaPopUpButton.m
//  Pester
//
//  Created by Nicholas Riley on Sat Oct 26 2002.
//  Copyright (c) 2002 Nicholas Riley. All rights reserved.
//

#import "NJRQTMediaPopUpButton.h"
#import "SoundFileManager.h"
#import "NSMovie-NJRExtensions.h"
#import "NSImage-NJRExtensions.h"

// XXX workaround for SoundFileManager log message in 10.2.3 and earlier
#include <stdio.h>
#include <unistd.h>
#include <fcntl.h>
// XXX end workaround

static const int NJRQTMediaPopUpButtonMaxRecentItems = 10;

NSString * const NJRQTMediaPopUpButtonMovieChangedNotification = @"NJRQTMediaPopUpButtonMovieChangedNotification";

@interface NJRQTMediaPopUpButton (Private)
- (void)_setPath:(NSString *)path;
- (NSMenuItem *)_itemForAlias:(BDAlias *)alias;
- (BOOL)_validateWithPreview:(BOOL)doPreview;
@end

@implementation NJRQTMediaPopUpButton

// XXX handle refreshing sound list on resume
// XXX don't add icons on Puma, they look like ass
// XXX launch preview on a separate thread (if movies take too long to load, they inhibit the interface responsiveness)

// Recent media layout:
// Most recent media are at TOP of menu (smaller item numbers, starting at [self indexOfItem: otherItem] + 1)
// Most recent media are at END of array (larger indices)

#pragma mark recently selected media tracking

- (NSString *)_defaultKey;
{
    NSAssert([self tag] != 0, @"Can�t track recently selected media for popup with tag 0: please set a tag");
    return [NSString stringWithFormat: @"NJRQTMediaPopUpButtonMaxRecentItems tag %d", [self tag]];
}

- (void)_writeRecentMedia;
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject: recentMediaAliasData forKey: [self _defaultKey]];
    [defaults synchronize];
}

- (NSMenuItem *)_addRecentMediaAtPath:(NSString *)path withAlias:(BDAlias *)alias;
{
    NSString *title = [[NSFileManager defaultManager] displayNameAtPath: path];
    NSMenu *menu = [self menu];
    NSMenuItem *item;
    if (title == nil || path == nil) return nil;
    item = [menu insertItemWithTitle: title action: @selector(_aliasSelected:) keyEquivalent: @"" atIndex: [menu indexOfItem: otherItem] + 1];
    [item setTarget: self];
    [item setRepresentedObject: alias];
    [item setImage: [[[NSWorkspace sharedWorkspace] iconForFile: path] bestFitImageForSize: NSMakeSize(16, 16)]];
    [recentMediaAliasData addObject: [alias aliasData]];
    if ([recentMediaAliasData count] > NJRQTMediaPopUpButtonMaxRecentItems) {
        [menu removeItemAtIndex: [menu numberOfItems] - 1];
        [recentMediaAliasData removeObjectAtIndex: 0];
    }
    return item;
}

- (void)_addRecentMediaFromAliasesData:(NSArray *)aliasesData;
{
    NSEnumerator *e = [aliasesData objectEnumerator];
    NSData *aliasData;
    BDAlias *alias;
    while ( (aliasData = [e nextObject]) != nil) {
        if ( (alias = [[BDAlias alloc] initWithData: aliasData]) != nil) {
            [self _addRecentMediaAtPath: [alias fullPath] withAlias: alias];
            [alias release];
        }
    }
}

- (void)_validateRecentMedia;
{
    NSEnumerator *e = [recentMediaAliasData reverseObjectEnumerator];
    NSData *aliasData;
    NSMenuItem *item;
    BDAlias *itemAlias;
    int otherIndex = [self indexOfItem: otherItem];
    int aliasDataCount = [recentMediaAliasData count];
    int lastItemIndex = [self numberOfItems] - 1;
    int recentItemCount = lastItemIndex - otherIndex;
    int recentItemIndex = otherIndex;
    NSAssert2(recentItemCount == aliasDataCount, @"Counted %d recent menu items, %d of alias data", recentItemCount, aliasDataCount);
    while ( (aliasData = [e nextObject]) != nil) { // go BACKWARD through array while going DOWN menu
        recentItemIndex++;
        item = [self itemAtIndex: recentItemIndex];
        itemAlias = [item representedObject];
        if ([itemAlias aliasDataIsEqual: aliasData])
            NSLog(@"item %d %@: %@", recentItemIndex, [item title], [itemAlias fullPath]);
        else
            NSLog(@"ITEM %d %@: %@ != aliasData %@", recentItemIndex, [item title], [itemAlias fullPath], [[BDAlias aliasWithData: aliasData] fullPath]);
    }
}

#pragma mark initialize-release

- (void)_setUp;
{
    NSMenu *menu;
    NSMenuItem *item;
    SoundFileManager *sfm = [SoundFileManager sharedSoundFileManager];
    int soundCount = [sfm count];

    [self removeAllItems];
    menu = [self menu];
    item = [menu addItemWithTitle: @"Alert sound" action: @selector(_beepSelected:) keyEquivalent: @""];
    [item setTarget: self];
    [menu addItem: [NSMenuItem separatorItem]];
    if (soundCount == 0) {
        item = [menu addItemWithTitle: @"Can�t locate alert sounds" action: nil keyEquivalent: @""];
        [item setEnabled: NO];
    } else {
        SoundFile *sf;
        int i;
        [sfm sortByName];
        for (i = 0 ; i < soundCount ; i++) {
            sf = [sfm soundFileAtIndex: i];
            item = [menu addItemWithTitle: [sf name] action: @selector(_soundFileSelected:) keyEquivalent: @""];
            [item setTarget: self];
            [item setRepresentedObject: sf];
            [item setImage: [[[NSWorkspace sharedWorkspace] iconForFile: [sf path]] bestFitImageForSize: NSMakeSize(16, 16)]];
        }
    }
    [menu addItem: [NSMenuItem separatorItem]];
    item = [menu addItemWithTitle: @"Other�" action: @selector(select:) keyEquivalent: @""];
    [item setTarget: self];
    otherItem = [item retain];

    [self _validateWithPreview: NO];

    recentMediaAliasData = [[NSMutableArray alloc] initWithCapacity: NJRQTMediaPopUpButtonMaxRecentItems + 1];
    [self _addRecentMediaFromAliasesData: [[NSUserDefaults standardUserDefaults] arrayForKey: [self _defaultKey]]];
    // [self _validateRecentMedia];

    [self registerForDraggedTypes:
        [NSArray arrayWithObjects: NSFilenamesPboardType, NSURLPboardType, nil]];
}

- (id)initWithFrame:(NSRect)frame;
{
    if ( (self = [super initWithFrame: frame]) != nil) {
        [self _setUp];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)coder;
{
    if ( (self = [super initWithCoder: coder]) != nil) {
        [self _setUp];
    }
    return self;
}

- (void)dealloc;
{
    [recentMediaAliasData release]; recentMediaAliasData = nil;
    [otherItem release];
    [selectedAlias release]; [previousAlias release];
    [super dealloc];
}

#pragma mark accessing

- (BDAlias *)selectedAlias;
{
    return selectedAlias;
}

- (void)_setAlias:(BDAlias *)alias;
{
    BDAlias *oldAlias = [selectedAlias retain];
    [previousAlias release];
    previousAlias = oldAlias;
    if (selectedAlias != alias) {
        [selectedAlias release];
        selectedAlias = [alias retain];
    }
}

- (void)setAlias:(BDAlias *)alias;
{
    [self _setAlias: alias];
    if ([self _validateWithPreview: NO]) {
        [self selectItem: [self _itemForAlias: selectedAlias]];
    }
}

- (void)_setPath:(NSString *)path;
{
    [self _setAlias: [BDAlias aliasWithPath: path]];
}

- (NSMenuItem *)_itemForAlias:(BDAlias *)alias;
{
    NSString *path;
    SoundFile *sf;
    if (alias == nil) {
        return [self itemAtIndex: 0];
    }

    // [self _validateRecentMedia];
    path = [alias fullPath];
    {   // XXX suppress log message from Apple's code:
        // 2002-12-14 14:09:58.740 Pester[26529] Could not find sound type for directory /Users/nicholas/Desktop
        int errfd = dup(STDERR_FILENO), nullfd = open("/dev/null", O_WRONLY, 0);
        // need to have something open in STDERR_FILENO because if it isn't,
        // NSLog will log to /dev/console
        dup2(nullfd, STDERR_FILENO);
        close(nullfd);
        sf = [[SoundFileManager sharedSoundFileManager] soundFileFromPath: path];
        dup2(errfd, STDERR_FILENO);
        close(errfd);
    }
    // NSLog(@"_itemForAlias: %@", path);

    // selected a system sound?
    if (sf != nil) {
        // NSLog(@"_itemForAlias: selected system sound");
        return [self itemAtIndex: [self indexOfItemWithRepresentedObject: sf]];
    } else {
        NSEnumerator *e = [recentMediaAliasData reverseObjectEnumerator];
        NSData *aliasData;
        NSMenuItem *item;
        int recentIndex = 1;

        while ( (aliasData = [e nextObject]) != nil) {
            // selected a recently selected, non-system sound?
            if ([alias aliasDataIsEqual: aliasData]) {
                int otherIndex = [self indexOfItem: otherItem];
                int menuIndex = recentIndex + otherIndex;
                if (menuIndex == otherIndex + 1) return [self itemAtIndex: menuIndex]; // already at top
                // remove item, add (at top) later
                // NSLog(@"_itemForAlias removing item: idx %d + otherItemIdx %d + 1 = %d [%@]", recentIndex, otherIndex, menuIndex, [self itemAtIndex: menuIndex]);
                [self removeItemAtIndex: menuIndex];
                [recentMediaAliasData removeObjectAtIndex: [recentMediaAliasData count] - recentIndex];
                break;
            }
            recentIndex++;
        }

        // create the item
        item = [self _addRecentMediaAtPath: path withAlias: alias];
        [self _writeRecentMedia];
        return item;
    }
}

- (BOOL)canRepeat;
{
    return movieCanRepeat;
}

#pragma mark selected media validation

- (void)_invalidateSelection;
{
    [self _setAlias: previousAlias];
    [self selectItem: [self _itemForAlias: [self selectedAlias]]];
    [[NSNotificationCenter defaultCenter] postNotificationName: NJRQTMediaPopUpButtonMovieChangedNotification object: self];
}

- (BOOL)_validateWithPreview:(BOOL)doPreview;
{
    [preview stop: self];
    if (selectedAlias == nil) {
        [preview setMovie: nil];
        movieCanRepeat = YES;
        if (doPreview) NSBeep();
    } else {
        NSMovie *movie = [[NSMovie alloc] initWithURL: [NSURL fileURLWithPath: [selectedAlias fullPath]] byReference: YES];
        movieCanRepeat = ![movie isStatic];
        if ([movie hasAudio])
            [preview setMovie: movie];
        else {
            [preview setMovie: nil];
            if (movie == nil) {
                NSBeginAlertSheet(@"Format not recognized", nil, nil, nil, [self window], nil, nil, nil, nil, @"The item you selected isn�t a sound or movie recognized by QuickTime.  Please select a different item.");
                [self _invalidateSelection];
                return NO;
            }
            if (![movie hasAudio] && ![movie hasVideo]) {
                NSBeginAlertSheet(@"No video or audio", nil, nil, nil, [self window], nil, nil, nil, nil, @"�%@� contains neither audio nor video content playable by QuickTime.  Please select a different item.", [[NSFileManager defaultManager] displayNameAtPath: [selectedAlias fullPath]]);
                [self _invalidateSelection];
                [movie release];
                return NO;
            }
        }
        [movie release];
        if (doPreview) [preview start: self];
    }
    [[NSNotificationCenter defaultCenter] postNotificationName: NJRQTMediaPopUpButtonMovieChangedNotification object: self];
    return YES;
}

#pragma mark actions

- (IBAction)stopSoundPreview:(id)sender;
{
    [preview stop: self];
}

- (void)_beepSelected:(NSMenuItem *)sender;
{
    [self _setAlias: nil];
    [self _validateWithPreview: YES];
}

- (void)_soundFileSelected:(NSMenuItem *)sender;
{
    [self _setPath: [(SoundFile *)[sender representedObject] path]];
    if (![self _validateWithPreview: YES]) {
        [[self menu] removeItem: sender];
    }
}

- (void)_aliasSelected:(NSMenuItem *)sender;
{
    BDAlias *alias = [sender representedObject];
    int index = [self indexOfItem: sender], otherIndex = [self indexOfItem: otherItem];
    [self _setAlias: alias];
    if (![self _validateWithPreview: YES]) {
        [[self menu] removeItem: sender];
    } else if (index > otherIndex + 1) { // move "other" item to top of list
        int recentIndex = [recentMediaAliasData count] - index + otherIndex;
        NSMenuItem *item = [[self itemAtIndex: index] retain];
        NSData *data = [[recentMediaAliasData objectAtIndex: recentIndex] retain];
        // [self _validateRecentMedia];
        [self removeItemAtIndex: index];
        [[self menu] insertItem: item atIndex: otherIndex + 1];
        [self selectItem: item];
        [item release];
        NSAssert(recentIndex >= 0, @"Recent media index invalid");
        // NSLog(@"_aliasSelected removing item %d - %d + %d = %d of recentMediaAliasData", [recentMediaAliasData count], index, otherIndex, recentIndex);
        [recentMediaAliasData removeObjectAtIndex: recentIndex];
        [recentMediaAliasData addObject: data];
        [self _validateRecentMedia];
        [data release];
    } // else NSLog(@"_aliasSelected ...already at top");
}

- (IBAction)select:(id)sender;
{
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    NSString *path = [selectedAlias fullPath];
    [openPanel setAllowsMultipleSelection: NO];
    [openPanel setCanChooseDirectories: NO];
    [openPanel setCanChooseFiles: YES];
    [openPanel beginSheetForDirectory: [path stringByDeletingLastPathComponent]
                                 file: [path lastPathComponent]
                                types: nil // XXX fix for QuickTime!
                       modalForWindow: [self window]
                        modalDelegate: self
                       didEndSelector: @selector(openPanelDidEnd:returnCode:contextInfo:)
                          contextInfo: nil];
}

- (void)openPanelDidEnd:(NSOpenPanel *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;
{
    [sheet close];

    if (returnCode == NSOKButton) {
        NSArray *files = [sheet filenames];
        NSAssert1([files count] == 1, @"%d items returned, only one expected", [files count]);
        [self _setPath: [files objectAtIndex: 0]];
        if ([self _validateWithPreview: YES]) {
            [self selectItem: [self _itemForAlias: selectedAlias]];
        }
    } else {
        // "Other..." item is still selected, revert to previously selected item
        // XXX issue with cancelling, top item in recent menu is sometimes duplicated!?
        [self selectItem: [self _itemForAlias: selectedAlias]];
    }
    // [self _validateRecentMedia];
}

- (void)setEnabled:(BOOL)flag;
{
    [super setEnabled: flag];
    if (flag) ; // XXX [self startSoundPreview: self]; // need to prohibit at startup
    else [self stopSoundPreview: self];
}

#pragma mark drag feedback

- (void)drawRect:(NSRect)rect;
{
    if (dragAccepted) {
        NSWindow *window = [self window];
        NSRect boundsRect = [self bounds];
        BOOL isFirstResponder = ([window firstResponder] == self);
        // focus ring and drag feedback interfere with one another
        if (isFirstResponder) [window makeFirstResponder: window];
        [super drawRect: rect];
        [[NSColor selectedControlColor] set];
        NSFrameRectWithWidthUsingOperation(NSInsetRect(boundsRect, 2, 2), 3, NSCompositeSourceIn);
        if (isFirstResponder) [window makeFirstResponder: self];
    } else {
        [super drawRect: rect];
    }
}

@end

@implementation NJRQTMediaPopUpButton (NSDraggingDestination)

- (BOOL)acceptsDragFrom:(id <NSDraggingInfo>)sender;
{
    NSURL *url = [NSURL URLFromPasteboard: [sender draggingPasteboard]];
    NSFileManager *fm = [NSFileManager defaultManager];
    BOOL isDir;

    if (url == nil || ![url isFileURL]) return NO;

    if (![fm fileExistsAtPath: [url path] isDirectory: &isDir]) return NO;

    if (isDir) return NO;
    
    return YES;
}

- (NSString *)_descriptionForDraggingInfo:(id <NSDraggingInfo>)sender;
{
    NSDragOperation mask = [sender draggingSourceOperationMask];
    NSMutableString *s = [NSMutableString stringWithFormat: @"Drag seq %d source: %@",
        [sender draggingSequenceNumber], [sender draggingSource]];
    NSPasteboard *draggingPasteboard = [sender draggingPasteboard];
    NSArray *types = [draggingPasteboard types];
    NSEnumerator *e = [types objectEnumerator];
    NSString *type;
    [s appendString: @"\nDrag operations:"];
    if (mask & NSDragOperationCopy) [s appendString: @" copy"];
    if (mask & NSDragOperationLink) [s appendString: @" link"];
    if (mask & NSDragOperationGeneric) [s appendString: @" generic"];
    if (mask & NSDragOperationPrivate) [s appendString: @" private"];
    if (mask & NSDragOperationMove) [s appendString: @" move"];
    if (mask & NSDragOperationDelete) [s appendString: @" delete"];
    if (mask & NSDragOperationEvery) [s appendString: @" every"];
    if (mask & NSDragOperationNone) [s appendString: @" none"];
    [s appendFormat: @"\nImage: %@ at %@", [sender draggedImage],
        NSStringFromPoint([sender draggedImageLocation])];
    [s appendFormat: @"\nDestination: %@ at %@", [sender draggingDestinationWindow],
        NSStringFromPoint([sender draggingLocation])];
    [s appendFormat: @"\nPasteboard: %@ types:", draggingPasteboard];
    while ( (type = [e nextObject]) != nil) {
        if ([type hasPrefix: @"CorePasteboardFlavorType 0x"]) {
            const char *osTypeHex = [[type substringFromIndex: [type rangeOfString: @"0x" options: NSBackwardsSearch].location] lossyCString];
            OSType osType;
            sscanf(osTypeHex, "%lx", &osType);
            [s appendFormat: @" '%4s'", &osType];
        } else {
            [s appendFormat: @" \"%@\"", type];
        }
    }
    return s;
}

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender;
{
    if ([self acceptsDragFrom: sender] && [sender draggingSourceOperationMask] &
        (NSDragOperationCopy | NSDragOperationLink)) {
        dragAccepted = YES;
        [self setNeedsDisplay: YES];
        // NSLog(@"draggingEntered accept:\n%@", [self _descriptionForDraggingInfo: sender]);
        return NSDragOperationLink;
    }
    return NSDragOperationNone;
}

- (void)draggingExited:(id <NSDraggingInfo>)sender;
{
    dragAccepted = NO;
    [self setNeedsDisplay: YES];
}

- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender;
{
    dragAccepted = NO;
    [self setNeedsDisplay: YES];
    return [self acceptsDragFrom: sender];
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender;
{
    if ([sender draggingSource] != self) {
        NSURL *url = [NSURL URLFromPasteboard: [sender draggingPasteboard]];
        if (url == nil) return NO;
        [self _setPath: [url path]];
        if ([self _validateWithPreview: YES]) {
            [self selectItem: [self _itemForAlias: selectedAlias]];
        }
    }
    return YES;
}

@end