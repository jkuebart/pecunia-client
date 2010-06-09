//
//  PreferenceController.h
//  MacBanking
//
//  Created by Frank Emminghaus on 02.02.08.
//  Copyright 2008 Frank Emminghaus. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface PreferenceController : NSWindowController {
	IBOutlet NSArrayController	*fieldController;
	IBOutlet NSTableView		*fieldTable;
	IBOutlet NSWindow			*encryptionSheet;
	IBOutlet NSButton			*encryptButton;
	IBOutlet NSSecureTextField	*passw1Field;
	IBOutlet NSSecureTextField	*passw2Field;
	NSWindow					*mainWindow;
	
	// encryption sheet
	NSString	*password;
	BOOL		aes256;
	BOOL		savePassword;
	BOOL		encrypt;
	BOOL		colorsChanged;
}

//-(IBAction)ok: (id) sender;
//-(IBAction)cancel: (id) sender;
-(IBAction)changeFileLocation: (id)sender;

-(IBAction)test: (id) sender;
-(IBAction)encryptData: (id)sender;
-(IBAction)cancelSheet:(id)sender;
-(IBAction)endSheet: (id)sender;
-(IBAction)colorButtonsChanged: (id)sender;

-(NSColor*)notAssignedColor;
-(void)setNotAssignedColor: (NSColor*)color;
-(NSColor*)newStatementColor;
-(void)setNewStatementColor: (NSColor*)color;

-(void)setMainWindow: (NSWindow*)main;

+(NSColor*)notAssignedRowColor;
+(NSColor*)newStatementRowColor;


@end
