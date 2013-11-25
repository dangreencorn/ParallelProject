//
//  DSViewController.h
//  DistributedSimulation
//
//  Created by Dan Greencorn on 11/20/2013.
//  Copyright (c) 2013 Dan Greencorn. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SRWebSocket.h"
#import "config.h"
#import <CoreLocation/CoreLocation.h>

enum AppState {
	notReady = 0,
	ready = 1,
	running = 2,
	errorOccured = 3
	};

@interface DSViewController : UIViewController <SRWebSocketDelegate, CLLocationManagerDelegate> {
	IBOutlet UILabel *lat;
	IBOutlet UILabel *lon;
	IBOutlet UILabel *alt;
	IBOutlet UILabel *error;
	IBOutlet UILabel *connectionStatus;
	IBOutlet UISwitch *experimentSwitch;

@private
	//sockets and app state
	SRWebSocket *controlSocket;
	SRWebSocket *dataSocket;
	enum AppState state;
	
	// experiment vars
	NSInteger numClients;
	NSInteger dataComputed;
	
	NSString *experimentType;
	
	NSMutableArray *dataPoints;
	NSMutableArray *resultVectors;
	
	double vectorLat;
	double vectorLon;
	double vectorAlt;
	
	// experiment times
	NSDate *firstData;
	NSDate *startSignal;
	
	NSTimeInterval computationAvg;
	
	// location vars
	CLLocationManager *locationManager;
	CLLocation *location;
	CLLocation *experimentLocation;
	
}

-(IBAction)triggerSimulation:(id)sender;
-(void)doComputationLat:(NSNumber*)latitude lon:(NSNumber*)longitude alt:(NSNumber*)altitude gpsError:(NSNumber*)gpsError;

-(void)connectWebsockets;
-(void)disconnectWebsockets;

-(void)startLocationUpdates;
-(void)stopLocationUpdates;

@end
