//
//  DSViewController.m
//  DistributedSimulation
//
//  Created by Dan Greencorn on 11/20/2013.
//  Copyright (c) 2013 Dan Greencorn. All rights reserved.
//

#import "DSViewController.h"
#import <CoreMotion/CoreMotion.h>
#import <CoreLocation/CoreLocation.h>
#import "SRWebSocket.h"

@interface DSViewController ()

@end

@implementation DSViewController


-(void)runSimulation:(id)sender {
	NSLog(@"Starting simulation--doesn't actually do anything yet");
}

#pragma mark -
#pragma mark WebSockets

-(BOOL)connectWebsockets {
	return NO;
}

-(void)disconnectWebsockets {
	
}

#pragma mark -
#pragma mark Location Updates

-(void)startLocationUpdates {
	
}

-(void)stopLocationUpdates {
	
}


#pragma mark -
#pragma mark SRWebSocketDelegate

-(void)webSocket:(SRWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean {
	NSLog(@"Websocket Closed");
}

-(void)webSocket:(SRWebSocket *)webSocket didFailWithError:(NSError *)error {
	NSLog(@"ERROR: websocket failed");
}

-(void)webSocket:(SRWebSocket *)webSocket didReceiveMessage:(id)message {
	NSLog(@"%@", message);
}

-(void)webSocketDidOpen:(SRWebSocket *)webSocket {
	NSLog(@"Opened WebSocket");
	[webSocket send:@"Hello"];
}

#pragma mark -
#pragma mark UIViewController
- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
	
	// connect to websockets
	NSLog(@"View Loaded");
	SRWebSocket *sock = [[SRWebSocket alloc] initWithURL:[NSURL URLWithString:@"ws://wpa144134.wireless.mcgill.ca:8000"]];
	[sock open];
	[sock setDelegate:self];
	

	
	// start getting location updates
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
