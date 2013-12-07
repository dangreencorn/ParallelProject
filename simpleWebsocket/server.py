#!/usr/bin/python

from SimpleWebSocketServer import WebSocket, SimpleWebSocketServer
import time
import thread
import json


# time benchmarks
startTime = None
startFinishedSendingTime = None
endTime = None


# count of the number of data received; will be 2*n (where n is the number of devices)
# (because each device will send two points over the data socket: raw GPS data and then the calculated result)
dataReceived = 0

# whether we are performing distributed or local calculations
experimentType = ""

# collection of all final calculated results received from the client devices
resultsReceived = []

# used to make sure that we have the same number of connections over control and data sockets
numClientsControl = 0
numClientsData = 0

# a reference to the server (ourself)
server = None

# saveResults -- saves the experiment data to a file
# TODO: implementation
def saveResults():
	global startTime
	global startFinishedSendingTime
	global endTime
	global resultsReceived
	print "--------------------------------------------------------"
	print "-- RESULTS - %s" % experimentType
	print "--------------------------------------------------------"
	print "Start Time: %s" % startTime
	print "Start Sending Time: %s" % (startFinishedSendingTime - startTime)
	print "End Time:   %s" % endTime
	print "--------------------------------------------------------"
	print "Results by Device:"
	# loop over all locations
	for data in resultsReceived:
		# get the data in JSON format
		try:
			data = json.loads(str(data))
			if experimentType == "SERIAL":
				print "-- %s -------------------------------------" % data['deviceName']
				print "   | startToAllData:        %.12f" % data['startToAllData']
				print "   | firstDataToAllData:    %.12f" % data['firstDataToAllData']
				print "   | startToEnd:            %.12f" % data['startToEnd']
				print "   | dataToEnd:             %.12f" % data['dataToEnd']
				print "   | time N-1 computations: %.12f" % data['timeOthers']
				print "   |- Vectors -------------------------------------"
				
				
				for result in data['Results']:
					print "   | vector -> x: %.12f y: %.12f z: %.12f | origin -> x: %.12f y: %.12f z: %.12f |" % (result['vector']['x'], result['vector']['y'], result['vector']['z'], result['origin']['x'], result['origin']['y'], result['origin']['z']),
					if result.has_key('time'):
						print " time: %.12f" % result['time']
					else:
						print ""
			elif experimentType == "DISTRIBUTED":
				print "-- %s -------------------------------------" % data['deviceName']
				print "   | startToAllData:     %.12f" % data['startToAllData']
				print "   | firstDataToAllData: %.12f" % data['firstDataToAllData']
				print "   | startToEnd:         %.12f" % data['startToEnd']
				print "   | dataToEnd:          %.12f" % data['dataToEnd']
				print "   | avgComputationTime: %.12f (time to compute influence of one other body)" % data['avgComputationTime']
				print "   |- Vector --------------------------------------"
				print "   | vector -> x: %.12f y: %.12f z: %.12f | origin -> x: %.12f y: %.12f z: %.12f |" % (data['vector']['x'], data['vector']['y'], data['vector']['z'], data['origin']['x'], data['origin']['y'], data['origin']['z'])
				
				
				
		except Exception:
			print "Exception"
	print "--------------------------------------------------------"

# reset -- resets startTime, endTime, dataReceived, experimentType, results received
def reset():
	# the number of connected cliends will remain accurate
	# we do not ever reset them
	global experimentType
	global resultsReceived
	global dataReceived
	global startTime
	global startFinishedSendingTime
	global endTime
	global server
	experimentType = ""
	resultsReceived = []
	dataReceived = 0
	startTime = None
	startFinishedSendingTime = None
	endTime = None

	for conn in server.connections.itervalues():
		conn.sendMessage(str("{'command':'RESET'}"))



# not used any more -- GOOD Example code
class SimpleEcho(WebSocket):

	def handleMessage(self):
		if self.data is None:
			self.data = ''
			
		print self.data
		print self.server.connections
		for conn in self.server.connections.itervalues():
			conn.sendMessage(str(self.data))

	def handleConnected(self):
		print self.address, 'connected'

	def handleClose(self):
		print self.address, 'closed'

# logic for handling the control socket
class ControlSocket(WebSocket):
	
	# handles an incoming message to the socket
	def handleMessage(self):
		global numClientsControl
		global startFinishedSendingTime
		global startTime
		global server
		global experimentType
		
		server = self.server
		
		if self.data is None:
			self.data = ''
		
		# get the data in JSON format
		try:
			data = json.loads(str(self.data))
			print data
		except Exception:
			print "Exception"
		
		# branch based on command
		if data['command'] == 'START':
			# start command received
			# record the current time as the start of the experiment
			startTime = time.time()
			data['numClients'] = numClientsControl
			experimentType = data['experimentType']
			
			print "%s Starting Experiment with %s devices" % (startTime, numClientsControl)
			
			# forward the start message to all devices (including origin device) to signal them to snapshot data and perform their calculations
			for conn in self.server.connections.itervalues():
				conn.sendMessage(str(data))
			
			# record the time after we've sent all data - we use this to benchmark communication speed
			# TODO: check to see if sendMessage is synchronous or asynchronous (i.e. is it blocking until the data has sent or not; if it isn't blocking, this metric will be flawed)
			startFinishedSendingTime = time.time()

	def handleConnected(self):
		global numClientsControl
		print self.address, "Connected Control"
		numClientsControl += 1

	def handleClose(self):
		global numClientsControl
		global startTime
		
		print self.address, "Closed Control"
		numClientsControl -= 1
		
		# deal with disconnect during experiment
		if startTime is not None:
			print "---ERROR---\nClient disconnected (control) mid-experiment\n-----------"
			for conn in self.server.connections.itervalues():
				conn.sendMessage("{\"command\":\"RESET\"}")
			startTime = None

# logic for handling the data socket
class DataSocket(WebSocket):
	def handleMessage(self):
		global dataReceived
		global resultsReceived
		global startTime
		global endTime
		global numClientsData
		
		if self.data is None:
			self.data = ''
		
		print "DATA MESSAGE ----------------------"
		print self.data
		
		# branch based on the data series we are expecting (either raw GPS to be forwarded to other devices or calculated results)
		# out of 2*n messages that will be received, the first n are raw GPS, the second n are calculated results
		if startTime is not None and dataReceived < numClientsData:
			# we are in the first n received messages; forward the data to all other devices
			dataReceived += 1
			print "Have data from %s devices" % dataReceived
			#print "Data: %s" % str(self.data)
			
			# forward message to all devices (except origin device)
			for conn in self.server.connections.itervalues():
				if conn != self:
					conn.sendMessage(str(self.data))
		elif startTime is not None and dataReceived == numClientsData:
			# we are in the second n received messages; store the results
			resultsReceived.append(self.data)
			
			if len(resultsReceived) == numClientsData:
				# we have finished collection; save end experiment timing, save, and reset the experiment
				endTime = time.time()
				print "%s Experiment complete" % endTime
				saveResults()
				reset()

	def handleConnected(self):
		global numClientsData
		print self.address, "Connected Data"
		numClientsData += 1

	def handleClose(self):
		global numClientsData
		global startTime
		print self.address, "closed Data"
		numClientsData -= 1
		
		# deal with disconnect during experiment
		if startTime is not None:
			print "---ERROR---\nClient disconnected (data) mid-experiment\n-----------"
			startTime = None

serverControl = SimpleWebSocketServer('', 9000, ControlSocket)
serverData = SimpleWebSocketServer('', 9001, DataSocket)
# create two threads as follows
try:
	thread.start_new_thread( serverControl.serveforever, () )
except:
	print "Error: unable to start thread"

serverData.serveforever()