//
//  AMViewController.m
//  AboutMeSDKExample
//
//  Created by Mason Glaves on 6/21/12.
//  Copyright (c) 2012 about.me. All rights reserved.
//

#import "AMViewController.h"
#import "AboutMe.h"
#import "AboutMeUser.h"

@interface AMViewController ()

@end

@implementation AMViewController {
    
    IBOutlet UITextField *username;
    IBOutlet UITextField *password;
    IBOutlet UITextView *output;
    
}

- (IBAction)login {
    [username resignFirstResponder];
    [password resignFirstResponder];
    
    output.text = @"Please wait, logging in...";
    
    AboutMe* aboutme = [AboutMe singleton];
    [aboutme signInWithUsername:[username text] andPassword:[password text] onComplete:^(BOOL success) {
        if (success) {
            output.text = [aboutme.currentUser description];
        }
    }];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
}

- (void)viewDidUnload
{
    username = nil;
    password = nil;
    output = nil;
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

@end
