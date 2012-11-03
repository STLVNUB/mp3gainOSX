//
//  Mp3GainMacAppDelegate.m
//  Mp3GainMac
//
//  Created by Paul Kratt on 7/4/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "Mp3GainMacAppDelegate.h"
#import "m3gInputItem.h"
#import "Mp3GainAdapter.h"

@implementation Mp3GainMacAppDelegate

@synthesize window = _window;
@synthesize lblCurrentFile;
@synthesize pbCurrentFile;
@synthesize pbTotalProgress;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    // Insert code here to initialize your application
    inputList = [[m3gInputList alloc] init];
    [tblFileList setDataSource:inputList];
}

- (IBAction)btnAddFiles:(id)sender {
    NSOpenPanel *fbox = [NSOpenPanel openPanel];
    [fbox setAllowsMultipleSelection:YES];
	[fbox beginSheetForDirectory:nil file:nil modalForWindow:_window modalDelegate:self 
                  didEndSelector:@selector(openPanelDidEnd: returnCode: contextInfo:) contextInfo:nil];
}

- (void)openPanelDidEnd:(NSOpenPanel *)panel returnCode:(int)returnCode contextInfo:(void  *)contextInfo{
	if(returnCode == NSOKButton){
        uint fileCount = (uint)[[panel filenames] count];
        for (uint f=0; f<fileCount; f++) {
            NSString* selfile = [[panel filenames] objectAtIndex:f];
            if ([[selfile lowercaseString] hasSuffix:@".mp3"]) {
                m3gInputItem* itemToAdd = [[m3gInputItem alloc] init];
                itemToAdd.filePath = selfile;
                [inputList addObject:itemToAdd];
            }
        }
        [tblFileList reloadData];
	}
}

- (void)addDirectory:(NSString*)folderPath subFoldersRemaining:(int)depth{
    NSFileManager* fileManager = [NSFileManager defaultManager];
    NSArray* files = [fileManager contentsOfDirectoryAtPath:folderPath error:nil];
    if(files != nil){
        if(![folderPath hasSuffix:@"/"]) folderPath = [folderPath stringByAppendingString:@"/"];
        int fileCount = (uint)[files count];
        for(int j=0; j<fileCount; j++){
            NSString* filePath = [folderPath stringByAppendingString:[files objectAtIndex:j]];
            BOOL isDirFlag = false;
            if([fileManager fileExistsAtPath:filePath isDirectory:&isDirFlag]==TRUE)
            {
                if(isDirFlag==FALSE && [[filePath lowercaseString] hasSuffix:@".mp3"]) {
                    m3gInputItem* itemToAdd = [[m3gInputItem alloc] init];
                    itemToAdd.filePath = filePath;
                    [inputList addObject:itemToAdd];
                }
                else if(isDirFlag==TRUE && depth > 0){
                    [self addDirectory:filePath subFoldersRemaining:(depth-1)];
                }
            }
        }
    }
}

- (void)directoryPanelDidEnd:(NSOpenPanel *)panel returnCode:(int)returnCode contextInfo:(void  *)contextInfo{
	if(returnCode == NSOKButton){
        uint folderCount = (uint)[[panel filenames] count];
        int depthAmount = (int)[ddlSubfolders indexOfSelectedItem];
        for (uint f=0; f<folderCount; f++) {
            NSString* folder = [[panel filenames] objectAtIndex:f];
            [self addDirectory:folder subFoldersRemaining:depthAmount];
        }
        [tblFileList reloadData];
	}
}

- (IBAction)btnAddFolder:(id)sender {
    NSOpenPanel *fbox = [NSOpenPanel openPanel];
    [fbox setAllowsMultipleSelection:YES];
    [fbox setCanChooseDirectories:TRUE];
    [fbox setCanChooseFiles:FALSE];
    [ddlSubfolders removeAllItems];
    [ddlSubfolders addItemWithTitle:NSLocalizedStringFromTable(@"None", @"ui_text", @"None")];
    [ddlSubfolders addItemWithTitle:NSLocalizedStringFromTable(@"1_Below", @"ui_text", @"1_Below")];
    [ddlSubfolders addItemWithTitle:NSLocalizedStringFromTable(@"2_Below", @"ui_text", @"2_Below")];
    [ddlSubfolders addItemWithTitle:NSLocalizedStringFromTable(@"3_Below", @"ui_text", @"3_Below")];
    [ddlSubfolders addItemWithTitle:NSLocalizedStringFromTable(@"4_Below", @"ui_text", @"4_Below")];
    [ddlSubfolders addItemWithTitle:NSLocalizedStringFromTable(@"5_Below", @"ui_text", @"5_Below")];
    [fbox setAccessoryView:vwSubfolderPicker];
	[fbox beginSheetForDirectory:nil file:nil modalForWindow:_window modalDelegate:self 
                  didEndSelector:@selector(directoryPanelDidEnd: returnCode: contextInfo:) contextInfo:nil];
}

- (IBAction)btnClearFile:(id)sender {
    NSIndexSet* selRows = [tblFileList selectedRowIndexes];
    
    NSUInteger curidx = [selRows lastIndex];
    while (curidx != NSNotFound)
    {
        [inputList removeAtIndex:(int)curidx];
        curidx = [selRows indexLessThanIndex: curidx];
    }
    [tblFileList reloadData];
}

- (IBAction)btnClearAll:(id)sender {
    [inputList clear];
    [tblFileList reloadData];
}

- (IBAction)btnAnalyze:(id)sender {
    [NSApp beginSheet:pnlProgressView modalForWindow:_window modalDelegate:nil didEndSelector:nil contextInfo:nil]; //Make a sheet
    [pbCurrentFile setUsesThreadedAnimation:YES]; //Make sure it animates.
    [pbCurrentFile startAnimation:self];
    [pbTotalProgress setUsesThreadedAnimation:YES];
    [pbTotalProgress startAnimation:self];
    [pbTotalProgress setMinValue:0.0];
    [pbTotalProgress setMaxValue:[inputList count]];
    [pbTotalProgress setDoubleValue:0.0];
    [btnCancel setEnabled:TRUE];
    cancelCurrentOperation = false;
    
    [self performSelectorInBackground:@selector(doAnalysis) withObject:nil];
}

-(void)doAnalysis{
    for(int i=0; i<[inputList count]; i++){
        dispatch_async(dispatch_get_main_queue(), ^{
            [pbCurrentFile setMinValue:0.0]; //Reset bar
            [pbCurrentFile setDoubleValue:0.0];
            [lblCurrentFile setStringValue:[[inputList objectAtIndex:i] getFilename]];
        });
        [Mp3GainAdapter AnalyzeFile:[inputList objectAtIndex:i] withVol:[txtTargetVolume doubleValue] withProgress:pbCurrentFile];
        dispatch_async(dispatch_get_main_queue(), ^{
            [pbTotalProgress setDoubleValue:(i+1)];
        });
        if(cancelCurrentOperation) break;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        [pbCurrentFile stopAnimation:self];
        [NSApp endSheet:pnlProgressView]; //Tell the sheet we're done.
        [pnlProgressView orderOut:self]; //Lets hide the sheet.    
        [tblFileList reloadData];
    });
}

- (IBAction)btnApplyGain:(id)sender {
    [NSApp beginSheet:pnlProgressView modalForWindow:_window modalDelegate:nil didEndSelector:nil contextInfo:nil]; //Make a sheet
    [pbCurrentFile setUsesThreadedAnimation:YES]; //Make sure it animates.
    [pbCurrentFile startAnimation:self];
    [pbTotalProgress setUsesThreadedAnimation:YES];
    [pbTotalProgress startAnimation:self];
    [pbTotalProgress setMinValue:0.0];
    [pbTotalProgress setMaxValue:[inputList count]];
    [pbTotalProgress setDoubleValue:0.0];
    [btnCancel setEnabled:TRUE];
    cancelCurrentOperation = false;
    
    [self performSelectorInBackground:@selector(doModify) withObject:nil];
}

-(void)doModify{
    for(int i=0; i<[inputList count]; i++){
        dispatch_async(dispatch_get_main_queue(), ^{
            [pbCurrentFile setMinValue:0.0]; //Reset bar
            [pbCurrentFile setDoubleValue:0.0];
            [lblCurrentFile setStringValue:[[inputList objectAtIndex:i] getFilename]];
        });
        [Mp3GainAdapter ModifyFile:[inputList objectAtIndex:i] withVol:[txtTargetVolume doubleValue] withProgress:pbCurrentFile];
        dispatch_async(dispatch_get_main_queue(), ^{
            [pbTotalProgress setDoubleValue:(i+1)];
        });
        if(cancelCurrentOperation) break;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        [pbCurrentFile stopAnimation:self];
        [NSApp endSheet:pnlProgressView]; //Tell the sheet we're done.
        [pnlProgressView orderOut:self]; //Lets hide the sheet.    
        [tblFileList reloadData];
    });
}

- (IBAction)btnCancel:(id)sender {
    cancelCurrentOperation = true;
    [lblCurrentFile setStringValue:NSLocalizedStringFromTable(@"Canceling_soon", @"ui_text", @"Canceling soon")];
    [btnCancel setEnabled:FALSE];
}

- (BOOL) applicationShouldTerminateAfterLastWindowClosed: (NSApplication *) theApplication{
    return TRUE;
}
@end
