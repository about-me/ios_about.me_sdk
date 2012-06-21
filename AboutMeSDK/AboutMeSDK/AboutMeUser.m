//
//  AboutMeUser.m
//  About-Me
//
//  Created by Lorien Henry-Wilkins on 10/26/11.
//  Copyright (c) 2011 Blazing Cloud, Inc. All rights reserved.
//

#import "AboutMeUser.h"
#import "UIColor+HexString.h"

@implementation AboutMeUser {
    NSDictionary *displayDetails;
}

@synthesize attributes;

- (id) initWithUsername:(NSString*)username {
    if (self = [super init]) {
        [self populateWith:[NSDictionary dictionaryWithObject:username forKey:@"user_name"]];
    }
    return self;
}

- (id)initWithDictionary:(NSDictionary*)dict {
    NSParameterAssert(dict);
    NSParameterAssert(dict != (id)[NSNull null]);
    if (self = [super init]) {
        [self populateWith:dict];
    }
    return self;
}

- (void) populateWith:(NSDictionary*)dict {
    attributes = [[NSMutableDictionary alloc] initWithDictionary:dict];
    displayDetails = [attributes objectForKey:@"display_details"];
}

- (NSArray *)socialServices {
    return [[attributes objectForKey:@"websites"] filteredArrayUsingPredicate:
            [NSPredicate predicateWithFormat:
             @"platform != 'link' && \
             platform != 'facebookpage' && \
             platform != 'favs' \
             && service_url != NULL"]];
}

- (NSArray *)webSites {
    return [[attributes objectForKey:@"websites"] filteredArrayUsingPredicate:
     [NSPredicate predicateWithFormat:@"platform == 'link' || platform == 'facebookpage'"]];
}

- (NSString*)fullName {
    return [attributes objectForKey:@"display_name"];
}

- (NSString*)firstName {
    return [attributes objectForKey:@"first_name"];
}

- (NSString*)lastName {
    return [attributes objectForKey:@"last_name"];
}


- (NSString*) headline {
    return [attributes objectForKey:@"header"];
}

- (NSString*) biography {
    return [attributes objectForKey:@"bio"];
}

- (NSString*) username {
    return [attributes objectForKey:@"user_name"];
}

- (NSString*) email_address {
    return [attributes objectForKey:@"email_address"];
}

- (NSURL*) backgroundURL {
    return [NSURL URLWithString:[self backgroundURLString]];
}

- (NSString*) backgroundURLString {

    NSString* url = [attributes objectForKey:@"mobile_background"];
    
    if (url == nil || [url length] == 0) { 
        url = [attributes objectForKey:@"background"]; 
    }
    
    return url;
}

- (NSURL*) thumbnailURL:(ThumbnailSizes)size {
    NSString *thumbnailKey = [NSString stringWithFormat:@"thumbnail%d", size];
    
    NSString *urlString = [attributes objectForKey:thumbnailKey];
    NSURL *thumbnailURL = nil;
    if (urlString && ![urlString isKindOfClass:[NSNull class]]) {
        thumbnailURL = [NSURL URLWithString:urlString];
    }
    
    return thumbnailURL;
}

- (UIColor*) backgroundColor {
    NSString *hexColor = [displayDetails objectForKey:@"background_color"];

    if (!hexColor) {
        hexColor = @"000"; // Default to black;
    }

    return [UIColor colorWithHexString:hexColor];
}

- (UIColor*) linksColor {
    return [UIColor colorWithHexString:[displayDetails objectForKey:@"links_color"]];
}

- (int) profilePosition {
    int text_left = [[displayDetails objectForKey:@"text_left"] intValue] + 
    ([[displayDetails objectForKey:@"profile_width"] intValue] / 2);
    
    int position = ProfilePositionRight;
    if (text_left <= 320 && text_left >= -320) {
        position = ProfilePositionCenter;
    } else if (text_left < -320) {
        position = ProfilePositionLeft;
    }
    
    return position;
}

- (BOOL) isFavorite {
    return [[attributes objectForKey:@"is_fav"] boolValue];
}

- (NSArray*) savedBackgrounds {
    return [attributes valueForKeyPath:@"available_backgrounds.saved"];
}

- (NSArray*) availableBackgrounds {
    NSMutableArray *backgrounds = [NSMutableArray array];
    NSString* current = [self backgroundURLString];
    if (current) {
        [backgrounds addObject:current];
    }

    NSArray *mobile = [attributes valueForKeyPath:@"available_backgrounds.mobile"];
    NSArray *gallery = [attributes valueForKeyPath:@"available_backgrounds.gallery"];
    
    [gallery enumerateObjectsUsingBlock:^(id bg, NSUInteger idx, BOOL *stop) {
        if (![[self backgroundURLString] hasSuffix:[bg valueForKey:@"image_name"]]) {
            [backgrounds addObject:bg];
        }
    }];

    [mobile enumerateObjectsUsingBlock:^(id bg, NSUInteger idx, BOOL *stop) {
        if (![[self backgroundURLString] isEqualToString:[bg valueForKey:@"image_url"]]){
            [backgrounds addObject:bg];
        }
    }];

    return backgrounds;
}

- (NSString*) description {
    return [[NSString alloc] initWithFormat:@"%@: %@\n%@", [self class], [self username], attributes];
}


@end
