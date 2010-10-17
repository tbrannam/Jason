/*
 Copyright (c) 2010, Olivier Labs. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
 
 * Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.
 
 * Redistributions in binary form must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided with the distribution.
 
 * Neither the name of the author nor the names of its contributors may be
 used to endorse or promote products derived from this software without
 specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS 'AS IS' AND
 ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER AND CONTRIBUTORS BE LIABLE
 FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
 CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
 OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "AppDelegate.h"
#import "OpenURLWC.h"
#import "PreferencesWC.h"
#import "SBJsonParser.h"
#import "Document.h"

@implementation AppDelegate

- (IBAction)openFromURL:(id)sender {
	if (! openURLWC) openURLWC = [OpenURLWC new];
	[openURLWC showWindow:self];
}

- (IBAction)showPreferencesPanel:(id)sender {
	if (! preferencesWC) preferencesWC = [PreferencesWC new];
	[preferencesWC showWindow:self];
}

- (IBAction)paste:(id)sender {
	NSError *error = nil;
	NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
	NSArray *classes = [NSArray arrayWithObject:[NSString class]];
	NSDictionary *options = [NSDictionary dictionary];
	
	if (! [pasteboard canReadObjectForClasses:classes options:options]) return;
	
	NSArray *objectsToPaste = [pasteboard readObjectsForClasses:classes options:options];
	NSString *pasteboardString = [objectsToPaste objectAtIndex:0];
	NSString *contentsToPaste;
	
	if ([[pasteboardString substringToIndex:7] isEqualToString:@"http://"]) {
		NSURL *url = [NSURL URLWithString:pasteboardString];
		contentsToPaste = [NSString stringWithContentsOfURL:url encoding:NSUTF8StringEncoding error:&error];
		if (error) {
			[NSApp presentError:error];
			return;
		}
	}
	else contentsToPaste = pasteboardString;
	
	SBJsonParser *parser = [SBJsonParser new];
	id parsedContents = [parser objectWithString:contentsToPaste error:&error];
	if (error) {
		[NSApp presentError:error];
		return;
	}
	
	if (parsedContents) {
		Document *newDoc = [[NSDocumentController sharedDocumentController] openUntitledDocumentAndDisplay:NO error:&error];
		if (error) {
			[NSApp presentError:error];
			return;
		}
		
		newDoc.contents = parsedContents;
	}
}

- (BOOL)validateUserInterfaceItem:(id <NSValidatedUserInterfaceItem>)item {
    if ([item action] == @selector(paste:)) {
        NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
        NSArray *classArray = [NSArray arrayWithObject:[NSString class]];
        NSDictionary *options = [NSDictionary dictionary];
        return [pasteboard canReadObjectForClasses:classArray options:options];
    }
	
	return YES;
}

@end
