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

#import "NodeObject.h"

@implementation NodeObject

@synthesize key;
@synthesize value;

- (id)initWithKey:(id)theKey value:(id)theValue {
	self = [super init];
	if (self) {
		key = theKey;
		value = theValue;
	}

	return self;
}

- (id)initWithValue:(id)theValue {
	return [self initWithKey:nil value:theValue];
}

- (NodeObjectType)type {
	if ([value isKindOfClass:[NSDictionary class]]) return kNodeObjectTypeDictionary;
	else if ([value isKindOfClass:[NSArray class]]) return kNodeObjectTypeArray;
	else if ([value isKindOfClass:[NSString class]]) return kNodeObjectTypeString;
	else if ([[value className] isEqualToString:@"NSCFBoolean"]) return kNodeObjectTypeBool;
	else if ([value isKindOfClass:[NSNumber class]]) return kNodeObjectTypeNumber;

	return kNodeObjectTypeNull;
}

- (void)setType:(NodeObjectType)newType {
	id newValue = nil;
	
	// Possible conversions:
	//
	// String -> Number, Boolean
	// Boolean -> String, Number (boolean must be tested before number)
	// Number -> String, Boolean
	
	// From string to...
	if ([value isKindOfClass:[NSString class]]) {
		NSString *stringValue = (NSString *)value;
		
		if (newType == kNodeObjectTypeNumber) { // from string to number
			newValue = [[NSDecimalNumber alloc] initWithString:stringValue];
			if ([newValue isEqual:[NSDecimalNumber notANumber]]) newValue = nil;
		}
		else if (newType == kNodeObjectTypeBool) { // from string to boolean
			newValue = [NSNumber numberWithBool:[stringValue boolValue]];
		}
	}
	// From boolean to...
	else if ([[value className] isEqualToString:@"NSCFBoolean"]) {
		BOOL boolValue = [(NSNumber *)value boolValue];
		
		if (newType == kNodeObjectTypeString) { // from boolean to string
			newValue = [NSString stringWithString:boolValue ?
						NSLocalizedString(@"true", @"") :
						NSLocalizedString(@"false", @"")];
		}
		else if (newType == kNodeObjectTypeNumber) { // from boolean to number
			newValue = [NSNumber numberWithInt:boolValue ? 1 : 0];
		}
	}
	// From number to...
	else if ([value isKindOfClass:[NSNumber class]]) {
		NSDecimalNumber *numberValue = (NSDecimalNumber *)value;
		
		if (newType == kNodeObjectTypeString) { // from number to string
			newValue = [NSString stringWithFormat:@"%@", numberValue];
		}
		else if (newType == kNodeObjectTypeBool) { // from number to boolean
			newValue = [NSNumber numberWithBool:[numberValue boolValue]];
		}
	}
	
	// If no conversion could be applied, instantiate a default value
	// that's not based on the old value
	if (! newValue) {
		switch (newType) {
			case kNodeObjectTypeDictionary: newValue = [NSMutableDictionary new]; break;
			case kNodeObjectTypeArray: newValue = [NSMutableArray new]; break;
			case kNodeObjectTypeString: newValue = @""; break;
			case kNodeObjectTypeNumber: newValue = [NSDecimalNumber numberWithInt:0]; break;
			case kNodeObjectTypeBool: newValue = (id)kCFBooleanFalse; break;
			default: newValue = [NSNull null]; break;
		}
	}

	self.value = newValue;
}

- (BOOL)typeIsCollection {
	return [value isKindOfClass:[NSDictionary class]] || [value isKindOfClass:[NSArray class]];
}

@end
