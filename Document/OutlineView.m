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
#import "DocumentWC.h"

@implementation OutlineView

- (void)keyDown:(NSEvent *)event {
	unichar character = [[event characters] characterAtIndex:0];
	
	if (character == NSTabCharacter) {
		// If no column is focused, let's try to focus the first
		// editable column, if any
		if ([self focusedColumn] == -1) {
			// Edit the key column if it is editable
			NSTableColumn *keyCol = [[self tableColumns] objectAtIndex:0];
			NSTableColumn *valueCol = [[self tableColumns] objectAtIndex:2];
			NSInteger row = [self selectedRow];
			id item = [self itemAtRow:row];
			
			if ([[self delegate] outlineView:self shouldEditTableColumn:keyCol item:item]) {
				[self editColumn:0 row:row withEvent:nil select:YES];				
				return;
			}
			// Edit the value column if it is editable
			else if ([[self delegate] outlineView:self shouldEditTableColumn:valueCol item:item]) {
				[self editColumn:2 row:row withEvent:nil select:YES];
				return;
			}
		}
	}
	else if (character == NSCarriageReturnCharacter) {
		[(OutlineViewVC *)[self delegate] addRow:self];
		return;
	}
	
	// It's not a key event we want to capture, so let the
	// superclass deal with it
	[super keyDown:event];
}

@end
