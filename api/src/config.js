"use strict";
module.exports = function () {

  let scopes = ['identify'];
  let args = {dev:true};
  let  port = (args.dev) ? 50451 : 50453,
      // change the second catalan.evl.uic.edu to the host of the server
      addr = (args.dev) ? "http://localhost:" + String(port) : "catalan.evl.uic.edu:" + String(port);

  return {
    address:addr,
    port:port,
    scope: scopes,
    args: args
  };
};