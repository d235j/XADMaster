/*
 * XADZipSFXParsers.m
 *
 * Copyright (c) 2017-present, MacPaw Inc. All rights reserved.
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
 * MA 02110-1301  USA
 */
#import "XADZipSFXParsers.h"
#import "CSFileHandle.h"

@implementation XADZipSFXParser

+(int)requiredHeaderSize { return 0x10000; }

+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name propertiesToAdd:(NSMutableDictionary *)props;
{
	const uint8_t *bytes=[data bytes];
	int length=[data length];

	if(length<12) return NO;
	if(bytes[0]!=0x4d||bytes[1]!=0x5a) return NO;

	for(int i=2;i<length-9;i++)
	{
        if(bytes[i]=='P'&&bytes[i+1]=='K'&&bytes[i+2]==3&&bytes[i+3]==4) {
            if(bytes[i+4]>=10&&bytes[i+4]<40&&!bytes[i+9]) {
                [props setObject:[NSNumber numberWithLongLong:i] forKey:XADSignatureOffset];
                return YES;
            }
        }
    }

	return NO;
}

-(NSString *)formatName { return @"Self-extracting Zip"; }

@end



@implementation XADWinZipSFXParser

+(int)requiredHeaderSize { return 20480; }

+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name;
{
	const uint8_t *bytes=[data bytes];
	int length=[data length];

	if(length<26) return NO;
	if(bytes[0]!=0x4d||bytes[1]!=0x5a) return NO;

	for(int i=2;i<length-24;++i)
	{
		if(memcmp(bytes+i,"WinZip(R) Self-Extractor",24)==0) return YES;
	}

	return NO;
}

-(NSString *)formatName { return @"WinZip Self-Extractor"; }

@end



@implementation XADZipItSEAParser

+(int)requiredHeaderSize { return 4; }

+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name;
{
	const uint8_t *bytes=[data bytes];
	int length=[data length];

	if(length<4) return NO;
	if(CSUInt32BE(bytes)=='Joy!') return YES;

	return NO;
}

-(NSString *)formatName { return @"ZipIt SEA"; }

@end




@implementation XADZipMultiPartParser

+(int)requiredHeaderSize { return 8; }

+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name
{
	// Only scan actual files which support seeking.
	if(![handle isKindOfClass:[CSFileHandle class]]) return NO;

	// Only scan files named ".zip".
	if(![name matchedByPattern:@"\\.zip" options:REG_ICASE]) return NO;

	// Try to locate the end of central directory.
	[handle seekToEndOfFile];
	off_t end=[handle offsetInFile];

	int numbytes=0x10011;
	if(numbytes>end) numbytes=(int)end;

	uint8_t buf[numbytes];

	[handle skipBytes:-numbytes];
	[handle readBytes:numbytes toBuffer:buf];
	int pos=numbytes-4;

	while(pos>=0)
	{
		if(buf[pos]=='P'&&buf[pos+1]=='K'&&buf[pos+2]==5&&buf[pos+3]==6) return YES;
		pos--;
	}

	return NO;
}

+(NSArray *)volumesForHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name
{
	NSArray *volumes=[self scanForVolumesWithFilename:name
	regex:[XADRegex regexWithPattern:[NSString stringWithFormat:@"^%@\\.(zip|z[0-9]{2})$",
		[[name stringByDeletingPathExtension] escapedPattern]] options:REG_ICASE]
	firstFileExtension:@"z01"];

	if([volumes count]>1) return volumes;

	volumes=[self scanForVolumesWithFilename:name
	regex:[XADRegex regexWithPattern:[NSString stringWithFormat:@"^%@(\\.[0-9]+|())\\.zip$",
		[[name stringByDeletingPathExtension] escapedPattern]] options:REG_ICASE]
	firstFileExtension:nil];

	if([volumes count]>1) return volumes;

	return nil;
}

-(NSString *)formatName { return @"Zip"; }

@end
