function checkImports() {
  Logger.log("BigInt: " + bigint);
  Logger.log("sv: " + sv);
  Logger.log("util: " + util);
  Logger.log("pir: " + pir);
}

function setProps() {
  ScriptProperties.setProperties({
      "N": 2,
      "n": 2,
      "l": 6,
      "P": 521,
    });
}

/** Translate an element from a base32 
 *  *  string to a bigint
 *   *
 *    * @param {string} elem The element to translate
 *     * @return {bigint} A bigint representation
 *      */
function translateBase32(elem) {
  var val;
  val = bigint.parseFromString(elem, 32, 2);
  return val;
}


function requestComputation() {
  var ss, options, t, partial_cell,partial;
  var timeval = new Date() ;
  ss = SpreadsheetApp.getActiveSpreadsheet();
  var querySheet = ss.getSheetByName("Request")
  var query_start,N,n,l,P,dbNo;
  var toProcess;
  var functionTimer = new Date().getTime();
  var query = querySheet.getRange("A61");  
  var params = query.getValue().split("|")
  query_start = params[1]
  N = params[2]
  n = params[3]
  l = params[4]
  P = params[5]
  dbNo = params[6]

  var properties = {
    "N": N,
    "n": n,
    "l": l,
    "P": bigint.parseFromString(P,10),
    "l_0": l / N
  }
  Logger.log("Params: "+query_start+", "+N+", "+n+", "+l+", "+P+", "+dbNo)

  options = { 
    "chain": function(val){
      return bigint.FromRawBytes( val )
    }
  }

  t = new util.AESHexTranslator("50db7d7ce3dd17af01c43c94825deed6c65eccf84fb1d9f5b3f2830b238c715a",options)
  t.setPadLength(Math.floor(properties.l/8))


  db = new util.SpreadsheetDbProvider(properties.n,
                                      t.translate,
                                      ScriptProperties.getProperty("DbSheet"),
                                      dbNo); 

  if (querySheet == null) {
    Logger.log("Error, querySheet was null")
    }
  var dbReadTimer = querySheet.getRange("B64");
  var queryReadTimer = querySheet.getRange("B65");
  var iterTimer = querySheet.getRange("B66")
  var processingStatus = querySheet.getRange("A62")
  var responseCell = querySheet.getRange("A63")

  while (true) {
    timeval = new Date()
    if (processingStatus.getValue() == "Processing") {
      toProcess = 0
      queryReadTimer.setValue(0)
      dbReadTimer.setValue(0)
    }
    else  {
      toProcess = parseInt(processingStatus.getValue())
    }
    if (toProcess >= parseInt(properties.n)) {
      var answer = []
      var timeAvg = 0
      for (var _i = 0; _i < (2 * properties.N); _i++){
        var timer = new Date().getTime()
        answer.push(bigint.Zero())
        util.Profiler.addTime('zeroPush',new Date().getTime() - timer)
      }
      for (var _i = 0; _i < properties.n; _i++) {
        timeAvg += querySheet.getRange(59,_i+1).getValue()
        partial_cell = querySheet.getRange(60,_i+1)
        partial = util.decodeMatrix(partial_cell.getValue()) 

        answer = util.safeVectorAdd(answer,partial[0],properties.P)
      }
      responseCell.setValue(util.encodeMatrix(answer))
      iterTimer.setValue(timeAvg)
      querySheet.getRange("B63").setValue(new Date().getTime())
      processingStatus.setValue("Complete")
      var triggers = ScriptApp.getProjectTriggers();
      for(var i in triggers) {
        if (triggers[i].getHandlerFunction() == "requestComputation") {
          ScriptApp.deleteTrigger(triggers[i]);
        }
      }
      Logger.log("Profile: " + util.Profiler.print());
      return
    }


    request_reader = new util.SpreadsheetQueryProvider(properties.n,
                                                        null,
                                                        querySheet,
                                                        query_start,
                                                        N);
    
    instance = new pir.PirInstance(properties)  
    instance.setDbReader(db);

    query = request_reader.at(toProcess)
    var queryMatrix = util.decodeMatrix(query)
    partial_cell = querySheet.getRange(60,toProcess+1)
    partial = instance.computeResponsePartial(toProcess,queryMatrix)
    partial_cell.setValue(util.encodeMatrix(partial))
    var iterationTimeTaken = new Date().getTime() - timeval.getTime()
    querySheet.getRange(59,toProcess+1).setValue(iterationTimeTaken)

    var timeval = parseInt(dbReadTimer.getValue())
    timeval += db.timers[0]
    dbReadTimer.setValue(timeval)
    var timeval = parseInt(queryReadTimer.getValue())
    timeval += request_reader.timers[0]
    queryReadTimer.setValue(timeval)

    processingStatus.setValue(toProcess+1)

    var functionTimeTaken = new Date().getTime() - functionTimer
    /* If we have less than 2x the amount of time required for the 
     * last iteration, reset */
    querySheet.getRange(58,toProcess+1).setValue(300000 - functionTimeTaken)
    if ((300000 - functionTimeTaken) < 2 * iterationTimeTaken) {
        timeval = new Date()
        timeval.setMinutes(timeval.getMinutes()+1)
        Logger.log("Profile: " + util.Profiler.print());
      ScriptApp.newTrigger("requestComputation")
         .timeBased()
         .at(timeval)
         .create();
        return
    }
  }
}

