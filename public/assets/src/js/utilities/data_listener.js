"use strict";
var App = App || {};

App.data_listener = function(debug) {

  // Connect to our node/websockets server
  let socket;
  if(App.debug) {
    socket = io.connect('http://localhost:8000', {autoConnect: false});
  }
  else {
    socket = io.connect('http://catalan.evl.uic.edu:8000', {autoConnect: false, secure:true});
  }

  return {
    connect: function () {
      return new Promise(function (resolve, reject) {

        // New socket connected, display new count on page
        socket.on('users connected', function (data) { console.log("connected")});

        /* Open the connection */
        socket.open();
        resolve();
      });
    },

    setCallbackForURL : function(url, cb){ socket.on(url,cb) }
  }
};