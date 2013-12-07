# DistributedSimulation Project #

## Execution Details ##

DistributedSimulation/config.h is for socket host/port configuration. 
Use hostname or ip; DO NOT USE 'localhost' or '127.0.0.1'

Server must be running before app launch. You can have the app try to connect again by locking and unlocking the device.

Build and run the app on as many devices as you like. The iOS simulator can be a device. 

### note ###
If you do not have a valid iOS developer program membership, you will not be able to run any experiments because you will not be able to run the app on physical iOS devices.

You will have to change the identity information in the general project settings, for use with your iOS developer program signing credentials before you can run the app on physical iOS devices.


## Useful Information ##

### Python WebSocket Server ###
http://opiate.github.io/SimpleWebSocketServer/

### Objective-C Websockets ###
https://github.com/square/SocketRocket/blob/master/README.rst