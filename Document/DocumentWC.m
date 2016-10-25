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

#import "DocumentWC.h"
#import "Document.h"
#import "NodeObject.h"
#import "JSON.h"
#import "OutlineViewVC.h"
#import "TextViewVC.h"

@interface DocumentWC ()
- (void)showParseError:(NSError *)error;
- (void)loadOutlineView;
- (void)loadTextViewWithString:(NSString *)string;
- (void)setCurrentVC:(NSViewController *)viewController;
@end

@implementation DocumentWC

#pragma mark Lifecycle

- (id)init {
	self = [super initWithWindowNibName:@"Document"];
	return self;
}

- (IBAction)showWindow:(id)sender {
	[super showWindow:sender];
	Document *doc = [self document];
	if (doc.parseError && ! parseErrorHasBeenShown) {
		[self showParseError:doc.parseError];
		parseErrorHasBeenShown = YES;
	}
}

- (void)windowDidLoad {
	[super windowDidLoad];
	
	Document *doc = [self document];
	
	// Configure the window
	[[self window] setBackgroundColor:[NSColor whiteColor]];

	if (doc.parseError) [self loadTextViewWithString:doc.invalidContents];
	else [self loadOutlineView];	
}

- (void)loadOutlineView {
	if (! outlineViewVC) outlineViewVC = [OutlineViewVC new];
	[outlineViewVC setRepresentedObject:[self document]];
	[self setCurrentVC:outlineViewVC];
	// We need to send resizeView: so that the scroll view containing the outline view
	// is possibly shrunk according to its contents
	[outlineViewVC resizeView:nil];
}

- (void)loadTextViewWithString:(NSString *)string {
	if (! textViewVC) textViewVC = [[TextViewVC alloc] init];
	[textViewVC setRepresentedObject:string];
	[self setCurrentVC:textViewVC];
}

- (void)setCurrentVC:(NSViewController *)viewController {
	NSView *superview = [[self window] contentView];
	NSView *subview = [viewController view];
	
	if (currentVC) [superview replaceSubview:[currentVC view] with:subview];
	else [superview addSubview:subview];
	
	// Resize the subview
	const CGFloat margin = 0.0;
	const CGFloat doubleMargin = margin + margin;

	NSRect subviewFrame = NSMakeRect(margin, // x
									 margin, // y
									 [superview bounds].size.width - doubleMargin, // width
									 [superview bounds].size.height - doubleMargin); // height
	
	[subview setFrame:subviewFrame];
	
	currentVC = viewController;
	[[self window] makeFirstResponder:subview];
}

#pragma mark -
#pragma mark Actions

- (IBAction)toggleViewTableText:(id)sender {
	Document *doc = [self document];
	
	// Switching from text to table
	if (textViewVC && currentVC == textViewVC) {
		NSError *error = nil;
		SBJsonParser *parser = [SBJsonParser new];
		id parsedContents = [parser objectWithString:[[textViewVC textView] string] error:&error];
		if (error) {
			[self showParseError:error];
			return;
		}
		
		doc.contents = parsedContents;
		[self loadOutlineView];
	}
	// Switching from table to text
	else [self loadTextViewWithString:[doc stringRepresentation]];
}

#pragma mark -
#pragma mark Pasteboard

- (IBAction)copy:(id)sender {
	Document *doc = [self document];
	NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
	[pasteboard clearContents];
	[pasteboard writeObjects:[NSArray arrayWithObject:[doc stringRepresentation]]];
}

#pragma mark -
#pragma mark User Interface Validation

- (BOOL)validateUserInterfaceItem:(id <NSValidatedUserInterfaceItem>)item {
    if ([item action] == @selector(toggleViewTableText:)) {
		NSMenuItem *menuItem = (NSMenuItem *)item;
		
		[menuItem setTitle:(outlineViewVC && currentVC == outlineViewVC) ?
		 NSLocalizedString(@"View as Text", @"") :
		 NSLocalizedString(@"View as Table", @"")];
    }
	
	return YES;
}

#pragma mark -
#pragma mark Error

- (void)showParseError:(NSError *)error {
	[self presentError:error
		modalForWindow:[self window]
			  delegate:self
	didPresentSelector:@selector(didPresentErrorWithRecovery:contextInfo:)
		   contextInfo:NULL];
	
	NSUInteger errorPosition = [[[error userInfo] objectForKey:@"JasonErrorPosition"] unsignedIntegerValue];
	NSUInteger lastLineBreakPosition = [[[error userInfo] objectForKey:@"JasonLineBreakPosition"] unsignedIntegerValue];
	if (lastLineBreakPosition > 0) ++lastLineBreakPosition;
	NSRange errorLineRange = NSMakeRange(lastLineBreakPosition, errorPosition - lastLineBreakPosition);
	[textViewVC highlightErrorAtRange:errorLineRange];
}

- (void)didPresentErrorWithRecovery:(BOOL)didRecover contextInfo:(void  *)contextInfo {
}

@end
