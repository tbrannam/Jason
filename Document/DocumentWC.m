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

static NSColor *kHighlightErrorColour;
static NSNumberFormatter *numberFormatter;

@interface DocumentWC ()
- (void)showParseError:(NSError *)error;
- (void)resizeOutlineView;
@end

@implementation DocumentWC

@synthesize outlineScrollView;
@synthesize outlineView;
@synthesize keyColumn;
@synthesize typeColumn;
@synthesize valueColumn;
@synthesize textScrollView;
@synthesize textView;

#pragma mark Lifecycle

+ (void)initialize {
	CGFloat highlightComponents[] = { 1.0, 0.9, 0.9, 1.0 };
	kHighlightErrorColour = [NSColor colorWithColorSpace:[NSColorSpace genericRGBColorSpace]
											  components:highlightComponents
												   count:4];
	
	numberFormatter = [NSNumberFormatter new];
	[numberFormatter setMaximumFractionDigits:100];
}

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
	
	// Configure the text view
	[textView setFont:[NSFont fontWithName:@"Monaco" size:[NSFont systemFontSize] - 2]];
	[textView setDelegate:self];
	
	// Configure the outline view
	[outlineView sizeLastColumnToFit];
	
	// Configure the window
	[[self window] setBackgroundColor:[NSColor whiteColor]];

	CGFloat contentViewHeight = [[[self window] contentView] frame].size.height;
	bottomMargin = [outlineScrollView frame].origin.y;
	topMargin = contentViewHeight - [outlineScrollView frame].size.height - bottomMargin;
	outlineViewMaxHeight = contentViewHeight - topMargin - bottomMargin;
	
	if (doc.parseError) {
		[outlineScrollView setHidden:YES];
		[textScrollView setHidden:NO];
		[textView setString:doc.invalidContents];
	}
	else {
		[textScrollView setHidden:YES];
		[outlineScrollView setHidden:NO];
		[outlineView reloadData];
		[outlineView expandItem:[outlineView itemAtRow:0] expandChildren:YES];
		[self resizeOutlineView];
	}
}

#pragma mark -
#pragma mark Outline view delegate

- (NSCell *)outlineView:(NSOutlineView *)theOutlineView dataCellForTableColumn:(NSTableColumn *)tableColumn item:(id)item {
	NSTreeNode *currentNode = item;
	NSTreeNode *parentNode = [currentNode parentNode];
	NodeObject *currentObject = [currentNode representedObject];

	// Non-editable items are greyed out:
	// * non-editable keys: root, array items
	BOOL shouldGreyOut = (tableColumn == keyColumn &&
	(! parentNode || [(NodeObject *)[parentNode representedObject] type] != kNodeObjectTypeDictionary));

	// * non-editable values: collections, null
	shouldGreyOut |= (tableColumn == valueColumn &&
	([currentObject typeIsCollection] || currentObject.type == kNodeObjectTypeNull));
	
	if (shouldGreyOut) {
		NSTextFieldCell *cell = [NSTextFieldCell new];
		[cell setFont:[NSFont systemFontOfSize:[NSFont systemFontSizeForControlSize:NSSmallControlSize]]];
		[cell setTextColor:[NSColor grayColor]];
		return cell;
	}
	// Boolean values use a checkbox cell
	else if (tableColumn == valueColumn && currentObject.type == kNodeObjectTypeBool) {
		NSButtonCell *cell = [NSButtonCell new];
		[cell setTitle:@""];
		[cell setControlSize:NSSmallControlSize];
		[cell setButtonType:NSSwitchButton];
		return cell;
	}
	// Number values need a number formatter
	else if (tableColumn == valueColumn && currentObject.type == kNodeObjectTypeNumber) {
		NSTextFieldCell *cell = [NSTextFieldCell new];
		[cell setFormatter:numberFormatter];
		[cell setEditable:YES];
		[cell setFont:[NSFont systemFontOfSize:[NSFont systemFontSizeForControlSize:NSSmallControlSize]]];
		return cell;
	}
	
	// Default cell
	NSCell *cell = [tableColumn dataCellForRow:[outlineView rowForItem:item]];
	return cell;
}

- (BOOL)outlineView:(NSOutlineView *)theView shouldEditTableColumn:(NSTableColumn *)tableColumn item:(id)item {
	BOOL shouldEdit = NO;
	NSTreeNode *currentNode = item;
	
	if (tableColumn == keyColumn) {
		NSTreeNode *parentNode = [currentNode parentNode];
		NodeObject *parentObject = [parentNode representedObject];
		shouldEdit = parentObject && parentObject.type == kNodeObjectTypeDictionary;
	}
	else if (tableColumn == typeColumn) {
		shouldEdit = YES;	
	}
	else if (tableColumn == valueColumn) {
		NodeObjectType type = [(NodeObject *)[currentNode representedObject] type];
		shouldEdit = (type == kNodeObjectTypeString ||
					  type == kNodeObjectTypeNumber ||
					  type == kNodeObjectTypeBool);
	}
	
	return shouldEdit;
}

#pragma mark -
#pragma mark Outline view data source

- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)childIndex ofItem:(id)parent {
	if (parent == nil) return [(Document *)[self document] rootNode];
	
	NSTreeNode *parentNode = parent;
	return [[parentNode childNodes] objectAtIndex:childIndex];
}

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)parent {
	return (parent == nil) ? 1 : [[(NSTreeNode *)parent childNodes] count];
}

- (BOOL)outlineView:(NSOutlineView *)view isItemExpandable:(id)item {
	return ! [(NSTreeNode *)item isLeaf];
}

- (id)outlineView:(NSOutlineView *)theOutlineView
objectValueForTableColumn:(NSTableColumn *)tableColumn
		   byItem:(id)item
{
	NSTreeNode *node = item;
	NodeObject *object = [node representedObject];

	/***** Key column *****/
	if (tableColumn == keyColumn) {
		// The root object has a literal key
		if (! [outlineView parentForItem:item]) return NSLocalizedString(@"Root", @"");

		// If it belongs to a dictionary, return its key
		if (object.key) return object.key;
		
		// If it doesn't belong to a dictionary then it belongs to an array. Return its position within the array
		NSIndexPath *indexPath = [node indexPath];
		NSUInteger position = [indexPath indexAtPosition:[indexPath length] - 1];
		return [NSString stringWithFormat:NSLocalizedString(@"Item %u", @""), position];
	}
	/***** Type column *****/
	else if (tableColumn == typeColumn) {
		// Because of the separator between dictionary/array and scalar values,
		// we need to change the type sent to the table view
		NSUInteger type = object.type;
		if (type > 1) type++;
		return [NSNumber numberWithLong:type];
	}
	/***** Value column *****/
	else if (tableColumn == valueColumn) {
		// Collections show the number of items
		if ([object typeIsCollection]) {
			NSUInteger count = [[node childNodes] count];
			if (count == 1) return [NSString stringWithString:NSLocalizedString(@"(1 item)", @"")];
			return [NSString stringWithFormat:NSLocalizedString(@"(%d items)", @""), count];
		}
		// Null shows, erm, null
		else if (object.type == kNodeObjectTypeNull) return NSLocalizedString(@"(null)", @"");
		// Otherwise show the item itself
		else return object.value;	
	}

	return @"";
}

- (void)changeTypeTo:(NSUInteger)newType {
	NSIndexSet *selectedIndexSet = [outlineView selectedRowIndexes];
	
	for (NSUInteger currentIndex = [selectedIndexSet firstIndex];
		 currentIndex != NSNotFound;
		 currentIndex = [selectedIndexSet indexGreaterThanIndex:currentIndex]) {
		NSTreeNode *currentNode = [outlineView itemAtRow:currentIndex];
		NSTreeNode *parentNode = [outlineView parentForItem:currentNode];
		NodeObject *currentObject = [currentNode representedObject];
		
		currentObject.type = (NodeObjectType)newType;

		if (parentNode == nil) { // replacing the root object
			Document *doc = [self document];
			doc.contents = currentObject.value;
			[outlineView reloadData];
		}
		else [outlineView reloadItem:currentNode];
		
		[[self document] updateChangeCount:NSChangeDone];
	}	
}

- (void)outlineView:(NSOutlineView *)theOutlineView
	 setObjectValue:(id)newValue
	 forTableColumn:(NSTableColumn *)tableColumn
			 byItem:(id)item
{
	Document *doc = [self document];
	BOOL changed = NO;
	
	/***** Key column *****/
	if (tableColumn == keyColumn) {
		NSTreeNode *currentNode = item;
		NSTreeNode *parentNode = [outlineView parentForItem:currentNode];
		NodeObject *currentObject = [currentNode representedObject];
		NodeObject *parentObject = [parentNode representedObject];
		
		// Only dictionary items can have their key changed
		if (parentObject.type == kNodeObjectTypeDictionary) {
			NSMutableArray *children = [parentNode mutableChildNodes];
			
			// We only allow replacing an existing key with a non-existing one
			if (! [children containsObject:newValue]) {
				currentObject.key = newValue;
				[outlineView reloadItem:currentNode];
				changed = YES;
			}
		}
	}
	/***** Type column *****/
	else if (tableColumn == typeColumn) {
		// Because of the separator between dictionary/array and scalar values,
		// we need to change the type sent by the table view
		NSUInteger newType = [newValue intValue];
		if (newType > 1) newType--;
		[self changeTypeTo:newType];
		changed = YES;
	}
	/***** Value column *****/
	else if (tableColumn == valueColumn) {
		NSTreeNode *currentNode = item;
		NSTreeNode *parentNode = [outlineView parentForItem:currentNode];
		
		if (! parentNode) doc.contents = newValue;
		else {
			NodeObject *currentObject = [currentNode representedObject];
			currentObject.value = newValue;
			[outlineView reloadItem:currentNode];
		}
		changed = YES;
	}
	
	if (changed) [[self document] updateChangeCount:NSChangeDone];	
}
 
#pragma mark -
#pragma mark Actions

- (IBAction)addRow:(id)sender {
	// Search for a collection (array, dictionary) starting from the currently
	// selected item, up the hierarchy
	NSInteger row = [outlineView selectedRow];
	NSTreeNode *parentNode = [outlineView itemAtRow:row];

	while (parentNode && ! [(NodeObject *)[parentNode representedObject] typeIsCollection]) {
		parentNode = [parentNode parentNode];
	}
	
	if (! parentNode) {
		row = 0;
		parentNode = [outlineView itemAtRow:0];
	}
	else row = [outlineView rowForItem:parentNode];
	
	NSAssert(row >= 0, @"addRow: row < 0");
	
	NodeObject *parentObject = [parentNode representedObject];
	// We can only add rows to arrays/dictionaries
	if (! [parentObject typeIsCollection]) return;

	NodeObject *newObject = [[NodeObject alloc] initWithValue:@""];
	
	// Rows belonging to a dictionary need a key. Find a key that doesn't exist yet
	if (parentObject.type == kNodeObjectTypeDictionary) {
		NSUInteger i = 0;
		NSString *newKey;
		BOOL foundKey;
		do {
			newKey = [NSString stringWithFormat:NSLocalizedString(@"New item %u", @""), i++];
			foundKey = [[parentNode childNodes] indexOfObjectPassingTest:^(NSTreeNode *node, NSUInteger idx, BOOL *stop) {
				NodeObject *obj = [node representedObject];
				if ([obj.key isEqualToString:newKey]) {
					*stop = YES;
					return YES;
				}
				return NO;
			}] != NSNotFound;
		} while (foundKey);
		
		newObject.key = newKey;
	}

	NSTreeNode *newNode = [[NSTreeNode alloc] initWithRepresentedObject:newObject];
	[[parentNode mutableChildNodes] addObject:newNode];
	[outlineView reloadItem:parentNode reloadChildren:YES];
	[outlineView expandItem:parentNode];
	
	NSInteger columnToEdit = (parentObject.type == kNodeObjectTypeDictionary) ? 0 : 2;
	NSInteger childRow = row + [[parentNode childNodes] count];
	
	[outlineView selectRowIndexes:[NSIndexSet indexSetWithIndex:childRow] byExtendingSelection:NO];
	[outlineView editColumn:columnToEdit row:childRow withEvent:nil select:YES];
	
	[self resizeOutlineView];
	
	[[self document] updateChangeCount:NSChangeDone];
}

- (IBAction)deleteRow:(id)sender {
	Document *doc = [self document];
	NSIndexSet *selectedIndexSet = [outlineView selectedRowIndexes];
	
	for (NSUInteger currentIndex = [selectedIndexSet firstIndex];
		 currentIndex != NSNotFound;
		 currentIndex = [selectedIndexSet indexGreaterThanIndex:currentIndex])
	{
		NSTreeNode *currentNode = [outlineView itemAtRow:currentIndex];
		NSTreeNode *parentNode = [currentNode parentNode];
		
		if (! parentNode) { // removing the root object
			[doc resetContents];
			[outlineView reloadData];
			[[self document] updateChangeCount:NSChangeDone];
		}
		else {
			NSIndexPath *path = [currentNode indexPath];
			NSUInteger position = [path indexAtPosition:[path length] - 1];
			[[parentNode mutableChildNodes] removeObjectAtIndex:position];
			[outlineView reloadItem:parentNode reloadChildren:YES];
			[[self document] updateChangeCount:NSChangeDone];
		}
	}
	
	[self resizeOutlineView];
	
	// If only one row has been deleted, select the row that was below it
	if ([selectedIndexSet count] == 1) {
		[outlineView selectRowIndexes:[NSIndexSet indexSetWithIndex:[selectedIndexSet firstIndex]]
				 byExtendingSelection:NO];
	}
}

- (IBAction)changeType:(id)sender {
	[self changeTypeTo:[sender tag]];
}

- (IBAction)toggleViewTableText:(id)sender {
	Document *doc = [self document];
	
	// Switching from text to table
	if ([outlineScrollView isHidden]) {
		NSError *error = nil;
		SBJsonParser *parser = [SBJsonParser new];
		id parsedContents = [parser objectWithString:[textView string] error:&error];
		if (error) {
			[self showParseError:error];
			return;
		}
		
		doc.contents = parsedContents;
		[outlineView reloadData];
		[outlineView expandItem:[outlineView itemAtRow:0] expandChildren:YES];
		[textScrollView setHidden:YES];
		[outlineScrollView setHidden:NO];
	}
	// Switching from table to text
	else [self switchToTextWithString:[doc stringRepresentation]];
}

- (void)switchToTextWithString:(NSString *)string {
	[textView setString:string];
	[textView setSelectedRange:NSMakeRange(0, 0)];
	[outlineScrollView setHidden:YES];
	[textScrollView setHidden:NO];
	[[self window] makeFirstResponder:textView];	
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
		NSMenuItem *menuItem = item;
		
		[menuItem setTitle:[textScrollView isHidden] ?
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
	NSLog(@"last line break = %lu", (unsigned long)lastLineBreakPosition);
	NSRange errorLineRange = NSMakeRange(lastLineBreakPosition, errorPosition - lastLineBreakPosition);
	
	[[textView textStorage] addAttribute:NSBackgroundColorAttributeName
								   value:kHighlightErrorColour
								   range:errorLineRange];
	[textView scrollRangeToVisible:errorLineRange];
	[textView setSelectedRange:NSMakeRange(errorPosition, 0)];
}

- (void)didPresentErrorWithRecovery:(BOOL)didRecover contextInfo:(void  *)contextInfo {
}

#pragma mark -

- (void)resizeOutlineView {
	CGFloat usedHeight = [[outlineView headerView] frame].size.height +
	[outlineView numberOfRows] * ([outlineView rowHeight] + [outlineView intercellSpacing].height);
	
	if (usedHeight < outlineViewMaxHeight) {
		[outlineScrollView setFrameSize:NSMakeSize([outlineScrollView frame].size.width, usedHeight)];
		[outlineScrollView setFrameOrigin:NSMakePoint([outlineScrollView frame].origin.x,
													  outlineViewMaxHeight - usedHeight + bottomMargin)];
		[outlineScrollView setNeedsDisplay:YES];
	}
}

@end
