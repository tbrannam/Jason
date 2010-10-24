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

#import "TextViewVC.h"

@interface TextViewVC ()
- (void)refreshView;
@end

@implementation TextViewVC

static NSColor *kHighlightErrorColour;

@synthesize textView;

+ (void)initialize {
	CGFloat highlightComponents[] = { 1.0, 0.9, 0.9, 1.0 };
	kHighlightErrorColour = [NSColor colorWithColorSpace:[NSColorSpace genericRGBColorSpace]
											  components:highlightComponents
												   count:4];	
}

- (id)init {
	return [super initWithNibName:@"TextView" bundle:nil];
}

- (void)loadView {
	[super loadView];

	// Configure the text view
	[textView setFont:[NSFont fontWithName:@"Monaco" size:[NSFont systemFontSize] - 2]];
	[self refreshView];
}

- (void)setRepresentedObject:(id)representedObject {
	[super setRepresentedObject:representedObject];
	[self refreshView];
}

- (void)refreshView {
	[textView setString:[self representedObject]];
	[textView setSelectedRange:NSMakeRange(0, 0)];	
}

#pragma mark -
#pragma mark Text View Delegate

- (void)textDidChange:(NSNotification *)notification {
	// We remove the highlight at the line that contains the parse error
	// as soon as the user starts typing
	[[textView textStorage] removeAttribute:NSBackgroundColorAttributeName
									  range:NSMakeRange(0, [[textView string] length])];
}

#pragma mark -
#pragma mark Error

- (void)highlightErrorAtRange:(NSRange)range {
	[[textView textStorage] addAttribute:NSBackgroundColorAttributeName
								   value:kHighlightErrorColour
								   range:range];
	[textView scrollRangeToVisible:range];
	[textView setSelectedRange:NSMakeRange(range.location + range.length, 0)];	
}

@end
