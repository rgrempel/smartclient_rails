isc.defineClass("RailsDataSource", "RestDataSource");

isc.RailsDataSource.addProperties({
  operationBindings: [
    {operationType: "fetch", dataProtocol: "getParams"},
    {operationType: "add", dataProtocol: "postMessage"},
    {operationType: "remove", dataProtocol: "postParams", requestProperties: {httpMethod: "DELETE"}},
    {operationType: "update", dataProtocol: "postMessage", requestProperties: {httpMethod: "PUT"}}
  ],

  // For array paramaters, if the operationType is getParams, we add the [] that Rails expects.
  // For fetches, we also shift the criteria data into a criteria parameter, because otherwise
  // it can clash with some automatic parameters that Rails adds (controller, action).
  transformRequest: function(dsRequest) {
    // First we shift the criteria for fetches, and we stuff the textMatchStyle in with the criteria
    if (dsRequest.operationType === "fetch") {
      dsRequest.data["_textMatchStyle"] = dsRequest.textMatchStyle;
      delete dsRequest.textMatchStyle;
      dsRequest.data = {
        criteria: dsRequest.data
      }
    }
    // Then we let the superclass do its thing
    var params = this.Super("transformRequest", arguments);
    // Finally, we change the name of params with array values
    // so that Rails will deserialize properly.
    if (this.getDataProtocol(dsRequest) == "getParams") {
      for (var key in params) {
        if (isc.isA.Array(params[key])) {
          params[key + "[]"] = params[key]
          delete params[key]
        }
      }
    }
    return params;
  },

  getDataURL: function(dsRequest) {
    var url = this.Super("getDataURL", arguments);
    switch(dsRequest.operationType) {
      case "fetch":
      case "add":
        url += ".isc";
        break;
      case "remove":
      case "update":
        var pkFieldName = this.getPrimaryKeyFieldName();
        var pkValue = dsRequest.unconvertedDSRequest.data[pkFieldName];
        url += "/" + escape(pkValue) + ".isc";
        break;
    }
    return url;
  }
});
