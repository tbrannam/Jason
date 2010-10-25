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

#import "OutlineViewVC.h"
#import "OutlineView.h"
#import "NodeObject.h"
#import "Document.h"

@interface OutlineViewVC ()
- (void)refreshView;
@end

@implementation OutlineViewVC

static NSNumberFormatter *numberFormatter = nil;

@synthesize outlineScrollView;
@synthesize outlineView;
@synthesize keyColumn;
@synthesize typeColumn;
@synthesize valueColumn;

+ (void)initialize {
	numberFormatter = [NSNumberFormatter new];
	[numberFormatter setMaximumFractionDigits:100];
}

- (id)init {
	return [super initWithNibName:@"OutlineView" bundle:nil];
}

- (void)finalize {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)loadView {
	[super loadView];
	
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(resizeView:)
												 name:NSWindowDidResizeNotification
											   object:[[self view] window]];

	// Insert ourselves between the outline view and its next responder
	// in the responder chain
	NSResponder *nextResponder = [outlineView nextResponder];
	[outlineView setNextResponder:self];
	[self setNextResponder:nextResponder];
	
	[outlineView sizeLastColumnToFit];
	[self refreshView];
}

- (void)setRepresentedObject:(id)representedObject {
	[super setRepresentedObject:representedObject];
	[self refreshView];
}

- (void)refreshView {
	[outlineView reloadData];
	[outlineView expandItem:[outlineView itemAtRow:0] expandChildren:YES];	
}

- (void)resizeView:(NSNotification *)notification {
	const CGFloat margin = 20.0;
	const CGFloat doubleMargin = margin + margin;
	
	NSSize contentViewSize = [[[[self view] window] contentView] frame].size;
	CGFloat outlineViewMaxHeight = contentViewSize.height - doubleMargin;
	CGFloat usedHeight = [[outlineView headerView] frame].size.height +
	[outlineView numberOfRows] * ([outlineView rowHeight] + [outlineView intercellSpacing].height);
	
	if (usedHeight < outlineViewMaxHeight) {
		[outlineScrollView setFrameSize:NSMakeSize(contentViewSize.width - doubleMargin, usedHeight)];
		[outlineScrollView setFrameOrigin:NSMakePoint(margin,
													  outlineViewMaxHeight - usedHeight + margin)];
		[outlineScrollView setNeedsDisplay:YES];
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
	if (parent == nil) return [(Document *)[self representedObject] rootNode];
	
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
	Document *doc = [self representedObject];
	
	for (NSUInteger currentIndex = [selectedIndexSet firstIndex];
		 currentIndex != NSNotFound;
		 currentIndex = [selectedIndexSet indexGreaterThanIndex:currentIndex]) {
		NSTreeNode *currentNode = [outlineView itemAtRow:currentIndex];
		NSTreeNode *parentNode = [outlineView parentForItem:currentNode];
		NodeObject *currentObject = [currentNode representedObject];
		
		currentObject.type = (NodeObjectType)newType;
		
		if (parentNode == nil) { // replacing the root object
			doc.contents = currentObject.value;
			[outlineView reloadData];
		}
		else [outlineView reloadItem:currentNode];
		
		[doc updateChangeCount:NSChangeDone];
	}	
}

- (void)outlineView:(NSOutlineView *)theOutlineView
	 setObjectValue:(id)newValue
	 forTableColumn:(NSTableColumn *)tableColumn
			 byItem:(id)item
{
	Document *doc = [self representedObject];
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
	
	if (changed) [doc updateChangeCount:NSChangeDone];	
}

#pragma mark -
#pragma mark IB Actions

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
	
	[self resizeView:nil];
	
	Document *doc = [self representedObject];
	[doc updateChangeCount:NSChangeDone];
}

- (IBAction)deleteRow:(id)sender {
	Document *doc = [self representedObject];
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
			[doc updateChangeCount:NSChangeDone];
		}
		else {
			NSIndexPath *path = [currentNode indexPath];
			NSUInteger position = [path indexAtPosition:[path length] - 1];
			[[parentNode mutableChildNodes] removeObjectAtIndex:position];
			[outlineView reloadItem:parentNode reloadChildren:YES];
			[doc updateChangeCount:NSChangeDone];
		}
	}
	
	[self resizeView:nil];
	
	// If only one row has been deleted, select the row that was below it
	if ([selectedIndexSet count] == 1) {
		[outlineView selectRowIndexes:[NSIndexSet indexSetWithIndex:[selectedIndexSet firstIndex]]
				 byExtendingSelection:NO];
	}
}

- (IBAction)changeType:(id)sender {
	[self changeTypeTo:[sender tag]];
}

@end
