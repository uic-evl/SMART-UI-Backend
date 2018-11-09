"use strict";

global.Promise = require("bluebird");

const R     = require("../../../lib/r-script/index.js")
    , path  = require("path")
    , csv = require('csvtojson');
;

module.exports = class R_Execution {

  constructor(script, args) {
    this.r_script = script;
    this.r_args = args;
  }

  execute() {
    let self = this
        , script = path.join(__dirname, self.r_script)
        , data_path = path.join(__dirname, self.r_args.data)
        , attitude = JSON.parse( require("fs").readFileSync(path.join(__dirname, "attitude.json"), "utf8") );

    return new Promise(function(resolve, reject){

      let out = R(script)
      .data({df: attitude, data_path: data_path})
      .call(function(err,d){
        if(err) throw(err);

        let final_preds = data_path + "/Risk_preds.csv"
            , final_weights = data_path + "/Risk_pred_model_coefficients_11_18.csv";

        let preds_promise = new Promise(function(resolve, reject){
        csv()
        .fromFile(final_preds)
        .then(resolve)
        });

      let weights_promise = new Promise(function(resolve, reject){
        csv()
        .fromFile(final_weights)
        .then(resolve)
      });
      
        Promise.all([preds_promise, weights_promise]).then(function(values){
          resolve(values);
        });


      })

    });

  }

};