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
	NSDictionary *commandDictionary = [[NSDictionary alloc] initWithObjectsAndKeys:@"START", @"command", nil];
	
	NSData *jsonData = [NSJSONSerialization dataWithJSONObject:commandDictionary options:0 error:nil];
	NSString *jsonString = [[NSString alloc] initWithBytes:[jsonData bytes] length:[jsonData length] encoding:NSUTF8StringEncoding];
	[controlSocket send:jsonString];
}
	
-(void)doComputation {
	NSLog(@"executing simulation");
	// our location should have been sent already
	
	
	
	
	// send computed results to server
	// - build message
	NSString *result = @"{\"x\":12345.7,\"y\":12345.7,\"z\":12345.7}";
	// - send to server
	[dataSocket send:result];
	
	// reset all state variables
	// - myLocation
	
}
	
-(void)sendLocation {
	// get last updated location
	experimentLocation = location;
	
	// build location JSON string for data passing
	NSNumber *numLat = [NSNumber numberWithDouble:experimentLocation.coordinate.latitude];
	NSNumber *numLon = [NSNumber numberWithDouble:experimentLocation.coordinate.longitude];
	NSNumber *numAlt = [NSNumber numberWithDouble:experimentLocation.altitude];
	
	NSDictionary *locationDictionary = [[NSDictionary alloc] initWithObjectsAndKeys: numLat, @"lat",
										numLon, @"lon",
										numAlt, @"alt", nil];
	NSData *jsonData = [NSJSONSerialization dataWithJSONObject:locationDictionary options:0 error:nil];
	NSString *locationString = [[NSString alloc] initWithBytes:[jsonData bytes] length:[jsonData length] encoding:NSUTF8StringEncoding];
	[dataSocket send:locationString];
}

-(BOOL)socketStateOK {
	if (controlSocket.readyState == SR_OPEN && dataSocket.readyState == SR_OPEN) {
		return YES;
	} else {
		return NO;
	}
}

-(NSDictionary*)getDictionaryFromJSON:(NSString*)message {
	// make string ok for use with NSJSONSerialization
	// remove single quotes and unicode
	message = [message stringByReplacingOccurrencesOfString:@"u'" withString:@"\""];
	message = [message stringByReplacingOccurrencesOfString:@"'" withString:@"\""];
	
	// make the data object for serialization
	NSData *jsonData = [message dataUsingEncoding:NSUTF16StringEncoding];
	
	// serialize the json command into
	NSError *err;
	NSDictionary *controlDictionary = [NSJSONSerialization JSONObjectWithData:jsonData options:NSJSONReadingAllowFragments error:&err];
	
	if (err) {
		NSLog(@"ERROR: %@", [err localizedDescription]);
		return NULL;
	}
	
	return controlDictionary;
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
	// initialize web sockets and set delegates to self
	NSString *control = [NSString stringWithFormat:@"ws://%@:%@/", WEBSOCKET_HOST, WEBSOCKET_PORT_CONTROL];
	controlSocket = [[SRWebSocket alloc] initWithURL:[NSURL URLWithString:control]];
	[controlSocket setDelegate:self];
	NSLog(@"Control %@", control);
	
	NSString *data = [NSString stringWithFormat:@"ws://%@:%@/", WEBSOCKET_HOST, WEBSOCKET_PORT_DATA];
	dataSocket = [[SRWebSocket alloc] initWithURL:[NSURL URLWithString:data]];
	[dataSocket setDelegate:self];
	NSLog(@"Data %@", data);
	
	// attempt to open the sockets
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
	
	// get dictionary for JSON message
	// NULL if JSON is malformed
	NSDictionary *controlDictionary = [self getDictionaryFromJSON:msg];
		
	// determine if it's a control or data transfer message
	if (webSocket == controlSocket) {
		// control message
		NSLog(@"CONTROL MESSAGE: %@", msg);
				
		NSString *commandString = [controlDictionary objectForKey:@"command"];
		NSLog(@"COMMAND: %@", controlDictionary);
		if ([commandString isEqualToString:@"START"]) {
			[self sendLocation];
			state = running;
		} else if ([commandString isEqualToString:@"RESET"]) {
			
		}
		
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
