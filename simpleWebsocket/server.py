#!/usr/bin/python

from SimpleWebSocketServer import WebSocket, SimpleWebSocketServer

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

serverControl = SimpleWebSocketServer('', 9000, SimpleEcho)
serverData = SimpleWebSocketServer('', 9001, SimpleEcho)
serverControl.serveforever()
serverData.serveforever()