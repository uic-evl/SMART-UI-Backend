"use strict";

const express  = require('express')
    , session  = require('express-session')
    , https = require('https')
    , path     = require("path")
    , args = require('yargs').argv
    , config = require('./config')(args)
    , app      = express()
    , compression = require('compression')
    , R_Utils  = require("./utilities/R_Execution")
    , WS_Utils = require("./utilities/WS_Data_Communication")
;

(function() {

  const risk_prediction = new R_Utils("../../../public/R/risk_preds_11_18.R", {data: "../../../public/data"})
      , ws_utilities = new WS_Utils({port:8000});

  let processing = false;

  /* Middleware */
  app.use(require('cookie-parser')());
  app.use(compression());
  app.use('/assets', express.static(path.join(__dirname, '../../public/assets'), config.express_options));

  app.get('/', function(req, res) { console.log('/');});

  app.get('/logout', function(req, res) {
    req.logout();
    res.redirect('/');
  });

  app.get('/risk_predictions', function(req, res) {

    if(!processing) {
      processing = true;
      console.log("runing R code");
      risk_prediction.execute().then(function(values){

        let predictions = values[0]
            , weights = values[1];

        processing = false;

        /* Send the weights and predictions to the client */
        ws_utilities.send("weighted coefficients", weights);
        ws_utilities.send("risk predictions", predictions);

      });
    }

    res.sendFile(path.join(__dirname + '/../index.html'));

  });

// create an HTTPS service
    app.listen(config.port, function (err) {
      if (err) return console.log(err);
      console.log('Listening at ' + config.address)
    });


})();

