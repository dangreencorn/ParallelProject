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

@interface DSViewController : UIViewController <SRWebSocketDelegate> {
	IBOutlet UILabel *lat;
	IBOutlet UILabel *lon;
	IBOutlet UILabel *alt;
	IBOutlet UILabel *error;
	IBOutlet UILabel *connectionStatus;

@private
	SRWebSocket *controlSocket;
	
}

-(IBAction)runSimulation:(id)sender;
-(BOOL)connectWebsockets;
-(void)disconnectWebsockets;

-(void)startLocationUpdates;
-(void)stopLocationUpdates;

@end
