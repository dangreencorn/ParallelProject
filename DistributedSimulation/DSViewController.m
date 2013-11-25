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
	
	NSString *expTypeString;
	
	if ([experimentSwitch isOn]) {
		expTypeString = @"SERIAL";
	} else {
		expTypeString = @"DISTRIBUTED";
	}
	
	NSDictionary *commandDictionary = [[NSDictionary alloc] initWithObjectsAndKeys:@"START", @"command", expTypeString, @"experimentType", nil];
	
	NSData *jsonData = [NSJSONSerialization dataWithJSONObject:commandDictionary options:0 error:nil];
	NSString *jsonString = [[NSString alloc] initWithBytes:[jsonData bytes] length:[jsonData length] encoding:NSUTF8StringEncoding];
	[controlSocket send:jsonString];
}
	
-(void)doComputationLat:(NSNumber*)latitude lon:(NSNumber*)longitude alt:(NSNumber*)altitude gpsError:(NSNumber*)gpsError{
	NSLog(@"Computing Force---");
	
	//get timestamp if first data
	if (dataComputed == 0) {
		firstData = [NSDate date];
		NSLog(@"FIRST DATA");
		dataPoints = [[NSMutableArray alloc] init];
	}
	dataComputed++;
	//get start time
	NSDate *computationStart = [NSDate date];
	
	// store this data point
	NSDictionary *thisPoint = [[NSDictionary alloc] initWithObjectsAndKeys:latitude, @"latitude", longitude, @"longitude", altitude, @"altitude", gpsError, @"gpsError", nil];
	[dataPoints addObject:thisPoint];
	
	// get the coords for deltas
	CLLocationCoordinate2D coordsX;
	coordsX.latitude = [latitude doubleValue];
	coordsX.longitude = experimentLocation.coordinate.longitude;
	
	CLLocationCoordinate2D coordsY;
	coordsY.latitude = experimentLocation.coordinate.latitude;
	coordsY.longitude = [longitude doubleValue];
	
	
	// get points for deltas in (x, y, z) ~ (lat, lon, alt)
	CLLocation *otherPointX = [[CLLocation alloc] initWithCoordinate:coordsX altitude:experimentLocation.altitude horizontalAccuracy:[gpsError doubleValue] verticalAccuracy:0 timestamp:[NSDate date]];
	CLLocation *otherPointY = [[CLLocation alloc] initWithCoordinate:coordsY altitude:experimentLocation.altitude horizontalAccuracy:[gpsError doubleValue] verticalAccuracy:0 timestamp:[NSDate date]];
	
	// get deltas
	CLLocationDistance distX = [experimentLocation distanceFromLocation:otherPointX];
	CLLocationDistance distY = [experimentLocation distanceFromLocation:otherPointY];
	if ([latitude doubleValue] < experimentLocation.coordinate.latitude) {
		distX *= -1;
	}
	if ([longitude doubleValue] < experimentLocation.coordinate.longitude) {
		distY *= -1;
	}
	CLLocationDistance distZ = [altitude doubleValue] - experimentLocation.altitude;
	
	NSLog(@"\nDistX: %f\nDistY: %f\nDistZ: %f\n", distX, distY, distZ);
	// get magnitude and total distance
	double dist = sqrt(distX * distX + distY * distY + distZ * distZ);
	double magnitude = G_CONST * 1000 * 1000 / experimentLocation.horizontalAccuracy  / [gpsError doubleValue] / (dist * dist);
	
	// update vectors
	vectorLat += magnitude * distX / dist;
	vectorLon += magnitude * distY / dist;
	vectorAlt += magnitude * distZ / dist;
	
	// get the end time
	NSDate *computationEnd = [NSDate date];
	
	// add to computation average
	computationAvg += [computationEnd timeIntervalSinceDate:computationStart];
	
	if (dataComputed == numClients - 1) {
		if ([experimentType isEqualToString:@"DISTRIBUTED"]) {
			[self sendResults];
		} else {
			[self computeOtherForces];
		}
	}
	
	
}

-(void)computeOtherForces {
	resultVectors = [[NSMutableArray alloc] init];
	
	double vecLat;
	double vecLon;
	double vecAlt;
	
	NSDate *start = [NSDate date];
	
	for (NSDictionary *point1 in dataPoints) {
		
		// reset our computed vector
		vecLat = 0;
		vecLon = 0;
		vecAlt = 0;
		
		NSDate *startVec = [NSDate date];
		
		for (NSDictionary *point2 in dataPoints) {
			// for every other point
			if (point1 != point2) {
				// get the coords for deltas
				CLLocationCoordinate2D coords1;
				coords1.latitude = [[point1 objectForKey:@"latitude"] doubleValue];
				coords1.longitude = [[point1 objectForKey:@"longitude"] doubleValue];
				
				CLLocationCoordinate2D coords2;
				coords2.latitude = [[point2 objectForKey:@"latitude"] doubleValue];
				coords2.longitude = [[point2 objectForKey:@"longitude"] doubleValue];
				
				CLLocationCoordinate2D coordsX;
				coordsX.latitude = coords2.latitude;
				coordsX.longitude = coords1.longitude;
				
				CLLocationCoordinate2D coordsY;
				coordsY.latitude = coords1.latitude;
				coordsY.longitude = coords2.longitude;
				
				
				// get point for point 1
				CLLocation *loc1 = [[CLLocation alloc] initWithCoordinate:coords1 altitude:[[point1 objectForKey:@"altitude"] doubleValue] horizontalAccuracy:[[point1 objectForKey:@"gpsError"] doubleValue] verticalAccuracy:0 timestamp:[NSDate date]];
				
				// get points for deltas in (x, y, z) ~ (lat, lon, alt)
				CLLocation *otherPointX = [[CLLocation alloc] initWithCoordinate:coordsX altitude:experimentLocation.altitude horizontalAccuracy:[[point2 objectForKey:@"gpsError"] doubleValue] verticalAccuracy:0 timestamp:[NSDate date]];
				CLLocation *otherPointY = [[CLLocation alloc] initWithCoordinate:coordsY altitude:experimentLocation.altitude horizontalAccuracy:[[point2 objectForKey:@"gpsError"] doubleValue] verticalAccuracy:0 timestamp:[NSDate date]];
				
				// get deltas
				CLLocationDistance distX = [loc1 distanceFromLocation:otherPointX];
				CLLocationDistance distY = [loc1 distanceFromLocation:otherPointY];
				if (coords2.latitude < coords1.latitude) {
					distX *= -1;
				}
				if (coords2.longitude < coords1.longitude) {
					distY *= -1;
				}
				CLLocationDistance distZ = [[point2 objectForKey:@"altitude"] doubleValue] - loc1.altitude;
				
				NSLog(@"\nDistX: %f\nDistY: %f\nDistZ: %f\n", distX, distY, distZ);
				// get magnitude and total distance
				double dist = sqrt(distX * distX + distY * distY + distZ * distZ);
				double magnitude = G_CONST * 1000 * 1000 / loc1.horizontalAccuracy  / [[point2 objectForKey:@"gpsError"] doubleValue] / (dist * dist);
				
				// update vectors
				vecLat += magnitude * distX / dist;
				vecLon += magnitude * distY / dist;
				vecAlt += magnitude * distZ / dist;
				
			}
		}
		
		NSDate *endVec = [NSDate date];
		
		NSTimeInterval timeVec = [endVec timeIntervalSinceDate:startVec];
		// store the resulting vector and origin in a result dict
		NSString *resultString = [NSString stringWithFormat:@"{\"vector\":{\"x\":%f,\"y\":%f,\"z\":%f}, \"origin\":{\"x\":%f,\"y\":%f,\"z\":%f}, \"time\":%f}",
								  vecLat,
								  vecLon,
								  vecAlt,
								  [[point1 objectForKey:@"latitude"] doubleValue],
								  [[point1 objectForKey:@"longitude"] doubleValue],
								  [[point1 objectForKey:@"altitude"] doubleValue],
								  timeVec];
		
		[resultVectors addObject:resultString];
	}
	NSDate *end = [NSDate date];
	NSTimeInterval totalTime = [end timeIntervalSinceDate:start];
	
	// build the large string to send
	NSString *resultString = [NSString stringWithFormat:@"{\"Results\":[{\"vector\":{\"x\":%f,\"y\":%f,\"z\":%f}, \"origin\":{\"x\":%f,\"y\":%f,\"z\":%f}}",
							  vectorLat,
							  vectorLon,
							  vectorAlt,
							  experimentLocation.coordinate.latitude,
							  experimentLocation.coordinate.longitude,
							  experimentLocation.altitude];
	for (NSString* str in resultVectors) {
		resultString = [resultString stringByAppendingString:@","];
		resultString = [resultString stringByAppendingString:str];
	}
	resultString = [resultString stringByAppendingString:@"]"];
	NSString *timeString = [NSString stringWithFormat:@", \"deviceName\":\"%@\", \"timeOthers\": -1, \"dataToEnd\": -1, \"startToEnd\": -1, \"firstDataToAllData\": -1, \"startToAllData\": -1}", [UIDevice currentDevice].name];
	resultString = [resultString stringByAppendingString:timeString];
	[dataSocket send:resultString];
}

-(void)sendResults {
	// - build message
	// get times for result string
	NSDate *endDate = [NSDate date];
	NSTimeInterval timeSinceData = [endDate timeIntervalSinceDate:firstData];
	NSTimeInterval timeSinceStart = [endDate timeIntervalSinceDate:startSignal];
	
	computationAvg /= dataComputed;
	
	// send computed results to server
	NSString *resultString = [NSString stringWithFormat:@"{\"vector\":{\"x\":%f,\"y\":%f,\"z\":%f}, \"origin\":{\"x\":%f,\"y\":%f,\"z\":%f}, \"startToEnd\":%f, \"dataToEnd\":%f, \"avgComputationTime\":%f, \"startToAllData\": -1, \"firstDataToAllData\": -1, \"deviceName\":\"%@\"}",
							  vectorLat,
							  vectorLon,
							  vectorAlt,
							  experimentLocation.coordinate.latitude,
							  experimentLocation.coordinate.longitude,
							  experimentLocation.altitude,
							  timeSinceStart,
							  timeSinceData,
							  computationAvg,
							  [UIDevice currentDevice].name ];
	[dataSocket send:resultString];
	
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
	NSNumber *numGps = [NSNumber numberWithDouble:experimentLocation.horizontalAccuracy];
	
	NSDictionary *locationDictionary = [[NSDictionary alloc] initWithObjectsAndKeys: numLat, @"lat",
										numLon, @"lon",
										numAlt, @"alt", numGps, @"gpsError", nil];
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

-(void)resetApp {
	// shut down everything
	[self disconnectWebsockets];
	
	[self stopLocationUpdates];
	
	// reset app state
	state = notReady;
	numClients = 0;
	dataComputed = 0;
	
	vectorLat = 0;
	vectorLon = 0;
	vectorAlt = 0;
	
	dataPoints = Nil;
	resultVectors = Nil;
	
	// re-initialize websockets
	[self startLocationUpdates];
	[self connectWebsockets];
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
	
	if (!controlSocket || controlSocket.readyState != SR_OPEN || state == notReady) {
		// initialize web sockets and set delegates to self
		NSString *control = [NSString stringWithFormat:@"ws://%@:%@/", WEBSOCKET_HOST, WEBSOCKET_PORT_CONTROL];
		controlSocket = [[SRWebSocket alloc] initWithURL:[NSURL URLWithString:control]];
		[controlSocket setDelegate:self];
		NSLog(@"Control %@", control);
	}
	
	if (!dataSocket || dataSocket.readyState != SR_OPEN || state == notReady) {
		NSString *data = [NSString stringWithFormat:@"ws://%@:%@/", WEBSOCKET_HOST, WEBSOCKET_PORT_DATA];
		dataSocket = [[SRWebSocket alloc] initWithURL:[NSURL URLWithString:data]];
		[dataSocket setDelegate:self];
		NSLog(@"Data %@", data);
	}
	
	// attempt to open the sockets
	NSLog(@"Attempting to open WebSockets");
	if (controlSocket.readyState != SR_OPEN)
		[controlSocket open];
	if (dataSocket.readyState != SR_OPEN)
		[dataSocket open];
}

-(void)disconnectWebsockets {
	NSLog(@"Closing WebSockets");
	if (controlSocket) {
		[controlSocket close];
	}
	if (dataSocket) {
		[dataSocket close];
	}
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
			startSignal = [NSDate date];
			experimentType = [controlDictionary objectForKey:@"experimentType"];
			numClients = [[controlDictionary objectForKey:@"numClients"] integerValue];
			state = running;
			
			[self sendLocation];
			
			//special case that we computed all other locations before sending receiving start
			if (dataComputed == numClients - 1) {
				if ([experimentType isEqualToString:@"DISTRIBUTED"]) {
					// send our result string
					[self sendResults];
				} else {
					[self computeOtherForces];
				}
			}
		} else if ([commandString isEqualToString:@"RESET"]) {
			[self resetApp];
		}
		
	} else if (webSocket == dataSocket) {
		// data message
		NSLog(@"DATA MESSAGE: %@", msg);
		NSNumber *latitude = [controlDictionary objectForKey:@"lat"];
		NSNumber *longitude = [controlDictionary objectForKey:@"lon"];
		NSNumber *altitude = [controlDictionary objectForKey:@"alt"];
		NSNumber *gpsErr = [controlDictionary objectForKey:@"gpsError"];
		
		[self doComputationLat:latitude lon:longitude alt:altitude gpsError:gpsErr];
	}
}

-(void)webSocketDidOpen:(SRWebSocket *)webSocket {
	if (webSocket == controlSocket) {
		NSLog(@"Opened control");
	} else if (webSocket == dataSocket) {
		NSLog(@"Opened data");
	}
	if ([self socketStateOK] && state != errorOccured) {
		state = ready;
		connectionStatus.text = @"Connected";
	}
	
}

@end
