#!/usr/bin/python

from SimpleWebSocketServer import WebSocket, SimpleWebSocketServer
import time
import thread
import json

startTime = None
endTime = None

dataReceived = 0

experimentType = ""
resultsReceived = []


numClientsControl = 0
numClientsData = 0

# saveResults -- saves the experiment data to a file
# TODO: implementation
def saveResults():
	global startTime
	global endTime
	global resultsReceived
	print "--------------------------------------------------------"
	print "-- RESULTS ---------------------------------------------"
	print "--------------------------------------------------------"
	print "Start Time: %s" % startTime
	print "End Time:   %s" % endTime
	print "--------------------------------------------------------"
	print "Locations:"
	# loop over all locations
	for data in resultsReceived:
		print data
	print "--------------------------------------------------------"

# reset -- resets startTime, endTime, dataReceived, experimentType, results received
def reset():
	# the number of connected cliends will remain accurate
	# we do not ever reset them
	experimentType = ""
	resultsReceived = []
	dataReceived = 0
	startTime = None
	endTime = None


# not used anymore -- GOOD Example code
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
	
	def handleMessage(self):
		global numClientsControl
		global startTime
		if self.data is None:
			self.data = ''
		try:
			data = json.loads(str(self.data))
			print data
		except Exception:
			print "Exception"

		if data['command'] == 'START':
			startTime = time.time()
			data['numClients'] = numClientsControl
			print "%s Starting Experiment with %s devices" % (startTime, numClientsControl)

		# forward message to all devices (including origin device)
		for conn in self.server.connections.itervalues():
			conn.sendMessage(str(data))

	def handleConnected(self):
		global numClientsControl
		print self.address, "Connected Control"
		numClientsControl += 1

	def handleClose(self):
		global numClientsControl
		global startTime
		
		print self.address, "closed Control"
		numClientsControl -= 1
		
		# deal with disconnect during experiment
		if startTime is not None:
			print "---ERROR---\nClient disconnected (control) mid-experiment\n-----------"
			for conn in self.server.connections.itervalues():
				conn.sendMessage("RESET")
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
		
		if startTime is not None and dataReceived < numClientsData:
			dataReceived += 1
			print "Have data from %s devices" % dataReceived
			print "Data: %s" % str(self.data)
			# forward message to all devices (except origin device)
			for conn in self.server.connections.itervalues():
				if conn != self:
					conn.sendMessage(str(self.data))
		elif startTime is not None and dataReceived == numClientsData:
			resultsReceived.append(self.data)
			if len(resultsReceived) == numClientsData:
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
# Create two threads as follows
try:
	thread.start_new_thread( serverControl.serveforever, () )
except:
	print "Error: unable to start thread"

serverData.serveforever()