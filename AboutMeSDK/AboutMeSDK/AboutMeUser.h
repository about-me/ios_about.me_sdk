//
//  AboutMeUser.h
//  About-Me
//
//  Created by Lorien Henry-Wilkins on 10/26/11.
//  Copyright (c) 2011 Blazing Cloud, Inc. All rights reserved.
//

typedef enum _ProfilePosition {
    ProfilePositionLeft = -1,
    ProfilePositionCenter = 0,
    ProfilePositionRight = 1
} ProfilePosition;

typedef enum _ThumbnailSizes {
    XLThumbnail = 1, //803x408
    LargeThumbnail = 2, //260x176
    MediumThumbnail = 3, //198x134
    SmallThumbnail = 4 //161x109
} ThumbnailSizes;

@interface AboutMeUser : NSObject 

@property(nonatomic, strong) NSDictionary *attributes;

- (id) initWithUsername:(NSString*)username;
- (id) initWithDictionary:(NSDictionary*)dict;

- (NSString*) fullName;
- (NSString*) firstName;
- (NSString*) lastName;
- (NSString*) username;
- (NSString*) email_address;
- (NSString*) headline;
- (NSString*) biography;
- (NSURL*) backgroundURL;
- (UIColor*) backgroundColor;
- (UIColor*) linksColor;
- (NSURL*) thumbnailURL:(ThumbnailSizes)size;

- (NSArray*) socialServices;
- (NSArray*) webSites;

- (int) profilePosition;
- (BOOL) isFavorite;

- (NSArray*) availableBackgrounds;
- (NSArray*) savedBackgrounds;

@end
