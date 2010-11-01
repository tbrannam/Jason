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

#import "OutlineView.h"
#import "OutlineViewDelegate.h"

@implementation OutlineView

@synthesize lastFocusedColumn;

- (void)setDelegate:(id <OutlineViewDelegate>)theDelegate {
	delegate = theDelegate;
	[super setDelegate:delegate];
}

- (id <OutlineViewDelegate>)delegate {
	return delegate;
}

- (void)keyDown:(NSEvent *)event {
	BOOL delegateHandledKeyDown = NO;
	
	if ([delegate conformsToProtocol:@protocol(OutlineViewDelegate)]) {
		delegateHandledKeyDown = [delegate handleKeyDown:event];
	}

	if (! delegateHandledKeyDown) [super keyDown:event];
}

- (BOOL)shouldFocusCell:(NSCell *)cell atColumn:(NSInteger)column row:(NSInteger)row {
	// We trace the last cell that has been focused. This is important for for our handling
	// of Tab and Backtab
	BOOL result = [super shouldFocusCell:cell atColumn:column row:row];
	if (result) lastFocusedColumn = column;
	return result;
}

@end
