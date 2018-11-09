"use strict";
var App = App || {};

(function(){

  let self = {};

  function createWeightsTable() {
    return $('#weights').DataTable( {
      ajax: '/fake/weighted',
      'processing': true,
      columns: [
        { title: "variable" },
        { title: "feeding_tube_coef" },
        { title: "aspiration_coef" },
        { title: "overall_survival_5y4_coef" },
        { title: "progression_free_5yr_coef" }
        ],
      columnDefs: [
        {
          "targets": '_all',
          "className": 'dt-left'
        }
      ]
    } );
  }

  function createPredictionTable() {
    return $('#predictions').DataTable( {
      ajax: '/fake/predictions',
      'processing': true,
      columns: [
        { title: "ID" },
        { title: "feeding_tube_prob" },
        { title: "aspiration_prob" },
        { title: "overall_survival_5yr_prob" },
        { title: "progression_free_5yr_prob" }
      ],
      columnDefs: [
        {
          "targets": '_all',
          "className": 'dt-left'
        }
      ]
    } );
  }

  function addDataToTable(aURL, wsURL) {
    $.mockjax({
      url: aURL,
      response: function (settings, done) {
        let that = this;
        self.data_listener.setCallbackForURL(wsURL, function(dataSet) {
          that.responseText = {data: _.map(dataSet, o=>_.toArray(o).slice(1))};
          done();
        });
      }
    });
  }

  function setupDataCallBacks() {

    addDataToTable('/fake/weighted', "weighted coefficients");
    addDataToTable('/fake/predictions', "risk predictions");

    /* Set the listener for the weighted coefficients */
    let weightsTable = createWeightsTable().draw()
      , predictionsTable = createPredictionTable();
  }

  function init() {
    App.debug = false;
    /* Turn off table searching */
    $.extend( true, $.fn.dataTable.defaults, {"searching": false} );

    /* Setup the data communication */
    self.data_listener = App.data_listener();
    self.data_listener.connect().then(setupDataCallBacks);
  }

  /* start the application once the DOM is ready */
  document.addEventListener('DOMContentLoaded',init);

})();