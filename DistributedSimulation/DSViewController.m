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
	connectionStatus.text = @"Not Connected";
	
	// initialize web sockets and set delegates to self
	NSString *control = [NSString stringWithFormat:@"ws://%@:%@/", WEBSOCKET_HOST, WEBSOCKET_PORT_CONTROL];
	controlSocket = [[SRWebSocket alloc] initWithURL:[NSURL URLWithString:control]];
	[controlSocket setDelegate:self];
	
	NSLog(@"Control %@", control);
	
	NSString *data = [NSString stringWithFormat:@"ws://%@:%@/", WEBSOCKET_HOST, WEBSOCKET_PORT_DATA];
	dataSocket = [[SRWebSocket alloc] initWithURL:[NSURL URLWithString:data]];
	[dataSocket setDelegate:self];
	
	NSLog(@"Data %@", data);
	
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

-(void)triggerSimulation:(id)sender {
	NSLog(@"Triggering simulation");
	[controlSocket send:@"START"];
}
	
-(void)doComputation {
	NSLog(@"executing simulation");
	
	// send our location to all devices
	[self sendLocation];
	
	// reset all state variables
	// myLocation
	
}
	
-(void)sendLocation {
	// get last updated location
	
	// build location string for data passing
	NSString *locationString = [NSString stringWithFormat:@""];
	[dataSocket send:locationString];
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
	// Create the location manager if this object does not
    // already have one.
    if (nil == locationManager)
	locationManager = [[CLLocationManager alloc] init];
	
    locationManager.delegate = self;
    locationManager.desiredAccuracy = kCLLocationAccuracyBest;
	
    // Set a movement threshold for new events.
    locationManager.distanceFilter = kCLDistanceFilterNone;
    [locationManager startUpdatingLocation];
}

-(void)stopLocationUpdates {
	[locationManager stopUpdatingLocation];
}

#pragma mark -
#pragma mark CLLocationManagerDelegate
	
-(void) locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations {
	//get most recent location
	location = [locations lastObject];
	
	lat.text = [NSString stringWithFormat:@"%f", location.coordinate.latitude ];
	lon.text = [NSString stringWithFormat:@"%f", location.coordinate.longitude ];
	alt.text = [NSString stringWithFormat:@"%f", location.altitude ];
	error.text = [NSString stringWithFormat:@"%f", location.horizontalAccuracy ];
}
	
	
#pragma mark -
#pragma mark WebSockets

-(void)connectWebsockets {
	NSLog(@"Attempting to open WebSockets");
	[controlSocket open];
	[dataSocket open];
}

-(void)disconnectWebsockets {
	NSLog(@"Closing WebSockets");
	[controlSocket close];
	[dataSocket close];
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
	connectionStatus.text = @"Connection Failed";
}

-(void)webSocket:(SRWebSocket *)webSocket didFailWithError:(NSError *)error {
	NSLog(@"ERROR: websocket failed");
	if (state == running) {
		state = errorOccured;
	} else {
		state = notReady;
	}
	connectionStatus.text = @"Connection Failed";
}

-(void)webSocket:(SRWebSocket *)webSocket didReceiveMessage:(id)message {
	// cast message to NSString
	NSString *msg = (NSString*) message;
	
	// determine if it's a control or data transfer message
	if (webSocket == controlSocket) {
		// control message
		NSLog(@"CONTROL MESSAGE: %@", msg);
		
	} else if (webSocket == dataSocket) {
		// data message
		NSLog(@"DATA MESSAGE: %@", msg);
	}
}

-(void)webSocketDidOpen:(SRWebSocket *)webSocket {
	NSLog(@"Opened WebSocket");
	if ([self socketStateOK] && state != errorOccured) {
		state = ready;
		connectionStatus.text = @"Connected";
	}
	
}

@end
