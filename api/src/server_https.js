"use strict";
const express  = require('express')
    , session  = require('express-session')
    , https = require('https')
    , fs       = require("fs")
    , path     = require("path")
    , args = require('yargs').argv
    , config = require('./config')(args)
    , app      = express()
    , compression = require('compression')
    , R_Utils = require("./utilities/R_Execution")
;

(function() {

  const risk_prediction = new R_Utils("../../../public/R/risk_preds_11_18.R", {
    data: "../../../public/data"
  });

  /* Middleware */
  app.use(require('cookie-parser')());
  app.use(compression());
  app.use('/site', express.static(path.join(__dirname, '../public'), config.express_options));

  app.use(session({
    secret: 'smart_ui_secret',
    resave: false,
    saveUninitialized: false
  }));

  app.get('/', function(req, res) {
    console.log('/');
  });

  app.get(`/callback`, function(req, res) {
    console.log('callback');
    res.redirect('/risk_predictions')
  });

  app.get('/logout', function(req, res) {
    req.logout();
    res.redirect('/');
  });

  app.get('/risk_predictions', function(req, res) {

    risk_prediction.execute();

    res.sendFile(path.join(__dirname + '/../index.html'));

  });

  function checkAuth(req, res, next) {
    // console.log("checking auth");
    if (req.isAuthenticated() || args.noAuth) {
      // console.log("is authed");
      return next();
    }
    // console.log('not authed');
    res.redirect(`/callback}`);
  }

// create an HTTPS service
  if(!config.args.dev) {
    // let options = {
    //   key: fs.readFileSync('/etc/letsencrypt/live/uic-raids.com/privkey.pem'),
    //   cert: fs.readFileSync('/etc/letsencrypt/live/uic-raids.com/fullchain.pem')
    // };
    // https.createServer(options, app).listen(config.port);
    // console.log('Listening at ' + config.address)
  }
  else {
    app.listen(config.port, function (err) {
      if (err) return console.log(err);
      console.log('Listening at ' + config.address)
    });
  }

})();

