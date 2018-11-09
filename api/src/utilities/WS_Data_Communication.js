"use strict";

const path  = require("path"),
    http = require("http"),
    app = require('express');

global.Promise = require("bluebird");

module.exports = class WS_Senders {

  constructor(config) {

    let server = http.createServer({},app);
    server.listen(8000);

    this.io = require('socket.io').listen(server, { wsEngine: 'ws' });
    this.socketCount = 0;

    /* Setup the connection callbacks*/
    this.setupConnectionCBs();
  }

  setupConnectionCBs() {
    let self = this;
    self.io.sockets.on('connection', function(socket) {
      // Socket has connected, increase socket count
      self.socketCount++;

      // Let all sockets know how many are connected
      self.io.sockets.emit('users connected', self.socketCount);

      socket.on('disconnect', function () {
        // Decrease the socket count on a disconnect, emitA few
        self.socketCount--;
        self.io.sockets.emit('users connected', self.socketCount)
      });

    });
  }

  send(url, data) { this.io.sockets.emit(url, data); };

};
