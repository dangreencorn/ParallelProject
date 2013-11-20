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

#pragma mark -
#pragma mark UIViewController
- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
	
	// initialize web sockets and set delegates to self
	controlSocket = [[SRWebSocket alloc] initWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"ws://WEBSOCKET_HOST:WEBSOCKET_PORT_CONTROL/"]]];
	[controlSocket setDelegate:self];
	
	dataSocket = [[SRWebSocket alloc] initWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"ws://WEBSOCKET_HOST:WEBSOCKET_PORT_DATA/"]]];
	[dataSocket setDelegate:self];
	
	// connect to websockets
	[self connectWebsockets];
	
	// start getting location updates
	[self startLocationUpdates];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark -
#pragma mark Simulation Functions

-(void)runSimulation:(id)sender {
	NSLog(@"Starting simulation--doesn't actually do anything yet");
}

#pragma mark -
#pragma mark Location Updates

-(void)startLocationUpdates {
	
}

-(void)stopLocationUpdates {
	
}

#pragma mark -
#pragma mark WebSockets

-(void)connectWebsockets {
	[controlSocket open];
	[dataSocket open];
}

-(void)disconnectWebsockets {
	
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

@end
