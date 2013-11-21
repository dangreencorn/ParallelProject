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
	
	// initialize appstate
	state = notReady;
	
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

-(BOOL)socketStateOK {
	if (controlSocket.readyState == SR_OPEN && dataSocket.readyState == SR_OPEN) {
		return YES;
	} else {
		return NO;
	}
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
	if (state == running) {
		state = errorOccured;
	} else {
		state = notReady;
	}
}

-(void)webSocket:(SRWebSocket *)webSocket didFailWithError:(NSError *)error {
	NSLog(@"ERROR: websocket failed");
	if (state == running) {
		state = errorOccured;
	} else {
		state = notReady;
	}
}

-(void)webSocket:(SRWebSocket *)webSocket didReceiveMessage:(id)message {
	NSLog(@"Message Received: %@", message);
	
	// determine if it's a control or data transfer message
	if (webSocket == controlSocket) {
		// control message
		
	} else if (webSocket == dataSocket) {
		// data message
		
	}
}

-(void)webSocketDidOpen:(SRWebSocket *)webSocket {
	NSLog(@"Opened WebSocket");
	if ([self socketStateOK] && state != errorOccured) {
		state = ready;
	}
	
}

@end
