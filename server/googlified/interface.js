function checkAndDoPIR() {
  var ss = SpreadsheetApp.getActiveSpreadsheet();
  var sheet = ss.getSheetByName("Request");     
  var query = sheet.getRange("A61");  
  var status  = sheet.getRange("A62");
  var answer = sheet.getRange("A63");
  var starttimer = sheet.getRange("B62");


  var req= status.getValue()
  Logger.log("Request value is " + req);
  if (req == "Requested") {
    var params = query.getValue().split("|")
    if (params.length != 7) {
      Logger.log("Parsed, but found no params")
      } else {
        Logger.log("Would run requestComputation(" + params[0] + ","
                                                   + params[1] + ","
                                                   + params[2] + ","
                                                   + params[3] + ","                   
                                                   + params[4] + ","
                                                   + params[5] + ","
                                                   + params[6] + ")")
        starttimer.setValue(new Date().getTime());
        status.setValue("Processing")
        pirlib.requestComputation();

      }
                   
  }    

}

function requestComputation() {
  pirlib.requestComputation()
  MailApp.sendEmail("pirdbtest@gmail.com",
                    "Execution Log",
                    Logger.getLog());
}
