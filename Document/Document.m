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

#import "Document.h"
#import "DocumentWC.h"
#import "JSON.h"
#import "NodeObject.h"

@interface Document ()
- (void)readChildrenOf:(NSTreeNode *)parentNode;
- (void)writeChildrenOf:(NSTreeNode *)parentNode toObject:(id)object;
@end

@implementation Document

@synthesize rootNode;
@synthesize parseError;
@synthesize invalidContents;

#pragma mark Lifecycle

- (id)init {
	self = [super init];
	if (self) [self resetContents];
	return self;
}

- (void)makeWindowControllers {
	[self addWindowController:[DocumentWC new]];
}

#pragma mark -
#pragma mark Tree/object/string representation

- (void)resetContents {
	self.contents = [NSMutableDictionary new];
}

- (void)setContents:(id)contents {
	NodeObject *data = [[NodeObject alloc] initWithValue:contents];
	rootNode = [[NSTreeNode alloc] initWithRepresentedObject:data];
	[self readChildrenOf:rootNode];
}

- (id)contents {
	NodeObject *rootObject = [rootNode representedObject];
	id contents = rootObject.value;
	[self writeChildrenOf:rootNode toObject:contents];
	return contents;
}

- (void)readChildrenOf:(NSTreeNode *)parentNode {
	id parentObject = [[parentNode representedObject] value];
	NSMutableArray *children = [parentNode mutableChildNodes];

	if ([parentObject isKindOfClass:[NSMutableArray class]]) {
		NSMutableArray *parentArray = parentObject;
		for (id childContents in parentArray) {
			// Add a node for the child...
			NodeObject *childObject = [[NodeObject alloc] initWithValue:childContents];
			NSTreeNode *childNode = [[NSTreeNode alloc] initWithRepresentedObject:childObject];
			[children addObject:childNode];
			
			// ...and recursively add its children
			[self readChildrenOf:childNode];
		}
		
		// We don't need the children in the original array because NSTreeNode::childNodes already keeps those
		[parentArray removeAllObjects];
	}
	else if ([parentObject isKindOfClass:[NSMutableDictionary class]]) {
		NSMutableDictionary *parentDict = parentObject;
		for (NSString *key in [[parentDict allKeys] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)]) {
			// Add a node for the child...
			NodeObject *childObject = [[NodeObject alloc] initWithKey:key value:[parentDict objectForKey:key]];
			NSTreeNode *childNode = [[NSTreeNode alloc] initWithRepresentedObject:childObject];
			[children addObject:childNode];
			
			// ...and recursively add its children
			[self readChildrenOf:childNode];
		}

		// We don't need the children in the original dictionary because NSTreeNode::childNodes already keeps those
		[parentDict removeAllObjects];
	}
}

- (NSString *)stringRepresentation {
	SBJsonWriter *parser = [SBJsonWriter new];
	parser.humanReadable = YES;
	parser.sortKeys = YES;
	NSString *string = [parser stringWithObject:self.contents];
	return string;
}

- (void)writeChildrenOf:(NSTreeNode *)parentNode toObject:(id)object {
	NodeObject *parentObject = [parentNode representedObject];
	
	if (parentObject.type == kNodeObjectTypeArray) {
		NSMutableArray *array = object;
		for (NSTreeNode *childNode in [parentNode childNodes]) {
			// Add the child object...
			NodeObject *childObject = [childNode representedObject];
			[array addObject:childObject.value];
			
			// ...and recursively add its children
			[self writeChildrenOf:childNode toObject:childObject.value];
		}
	}
	else if (parentObject.type == kNodeObjectTypeDictionary) {
		NSMutableDictionary *dict = object;
		for (NSTreeNode *childNode in [parentNode childNodes]) {
			// Add the child object...
			NodeObject *childObject = [childNode representedObject];
			[dict setObject:childObject.value forKey:childObject.key];
			
			// ...and recursively add its children
			[self writeChildrenOf:childNode toObject:childObject.value];
		}
	}
}

#pragma mark -
#pragma mark Read and write

- (BOOL)readFromData:(NSData *)data ofType:(NSString *)typeName error:(NSError **)outError {
	NSError *error = nil;
	NSString *strData = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
	SBJsonParser *parser = [SBJsonParser new];
    id parsedContents = [parser objectWithString:strData error:&error];
	parseError = error;
	// If there was a parse error, keep the (invalid) string in stringContents...
	if (parseError) invalidContents = strData;
	// ...otherwise, we have a valid object to use as contents
	else self.contents = parsedContents;
	
	return YES;
}

- (BOOL)writeToURL:(NSURL *)absoluteURL ofType:(NSString *)typeName error:(NSError **)outError {
	NSError *error = nil;
	NSString *string = [self stringRepresentation];
	[string writeToURL:absoluteURL atomically:YES encoding:NSUTF8StringEncoding error:&error];
	if (error) {
		if (outError) *outError = error;
		return NO;
	}

	return YES;
}

- (BOOL)canConcurrentlyReadDocumentsOfType:(NSString *)typeName {
	return YES;
}

@end
