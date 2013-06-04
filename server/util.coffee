bigint = require 'bigint-node'
Crypto = (require './cryptojs/cryptojs').Crypto
###### Matrix operations #######
# These are helpers that translate
# to/from encoded form.
#

inspectArray = (arr)->
  return null unless arr?
  (elem.toStr(10) for elem in arr)

class Profiler

  constructor: ()->
    @root = {}
    @current = @root
    @outstanding = {}

  start: (label)->
    @outstanding[label] = new Date().getTime()
    if not @current[label]?
      @current[label] =
        self:
          name: label
          sum: 0
          count: 0
        _p: @current

    end: (label) ->
      if label != @current.self.name
        throw new Error "Ended '#{label}' but expected '#{@current.self.name}'"
      @current.self.sum += new Date().getTime() - outstanding[label]
      @current.self.count += 1
      @current = @current.self._p
      delete outstanding[label]


  addTime: (label,time)->

    if not @root[ label ]?
      @root[ label ] =
        sum: time
        count: 1
    else
      @root[ label ].sum += time
      @root[ label ].count++

  print: (str = "")->
    for label of @root
      str += "#{label}: #{@root[ label ].count} calls, #{@root[ label ].sum} ms\n"

    return str


profile = new Profiler()

Log = (string)->
  if console?
    console.log(string)
  else if Logger?
    Logger.log(string)

class DbProvider

  _it: 0

  constructor:(@size,@translator)->
    @_it = 0

  reset: =>
    @_it = 0

  next: =>
    if @_it == @size
      return null
    elem = @at(@_it)
    @_it++
    return elem

  each: (func)=>
    @reset()
    # Google doesn't like throwing errors, so this is now standard loop
    func(@next()) while @_it < @size
    @reset()
    @size

class AESHexTranslator

  constructor: (@key, @options = {}) ->
    @mode = @options.mode || new Crypto.mode.OFB
    @chain = @options.chain || null
    @key = if @key instanceof Array then  @key else Crypto.util.hexToBytes @key
    @options.padLen = @options.padLen || -1

  setPadLength: (len) ->
    @options.padLen = len

  translate: (val,iv=null)=>
    bytes = Crypto.util.hexToBytes(val)
    bytes = Crypto.AES.decrypt bytes, @key, {mode: @mode, iv: iv, asBytes: true}

    bytes.push(255) while bytes.length < @options.padLen and @options.padLen > 0

    if @chain
      bytes = @chain(bytes)

    return bytes

  decrypt: (val,iv=null)->
    @translate(val,iv)

  @UTFChainHelper: (chain)->
    (val)->
      chain(Crypto.charenc.UTF8.bytesToString(val))

  encrypt: (val,iv=null)->
    bytes = Crypto.charenc.UTF8.stringToBytes val
    Crypto.AES.encrypt(bytes, @key, {mode: @mode, iv: iv, asBytes: true, in_place: true})
    return Crypto.util.bytesToHex(bytes)

  generateDbElem: (val,params)->
    bytes = Crypto.charenc.UTF8.stringToBytes val
    if bytes.length > (params.l/8)
      throw new Error("Requested value is more than #{params.l/8} bytes")

    Crypto.AES.encrypt(bytes, @key, {mode: @mode, as_bytes: true, in_place: true})
    return Crypto.util.bytesToHex(bytes)


class SpreadsheetDbProvider extends DbProvider

  constructor: (@size, @translator, @sheetname,@colnum)->
    @_it = 0
    Log "Creating SpreadsheetDbProvider for sheet #{@sheetname}"
    @timers = []

  at: (i)->
    starttimer = new Date()
    if i > @size
      throw new Error "OutOfRange"

    ss = SpreadsheetApp.getActiveSpreadsheet()
    sheet = ss.getSheetByName(@sheetname)
    range = sheet.getRange(1+i,@colnum)

    val = range.getValue()
    val = @translator(val) if @translator?
    @timers.push new Date().getTime() - starttimer.getTime()
    return val

class SpreadsheetQueryProvider extends DbProvider

  constructor: (@size, @translator, @sheet,start_ref,@N)->
    @_it = 0
    Log "Creating QueryProvider on sheet #{@sheet} at #{start_ref}"
    @start_row = @sheet.getRange(start_ref).getRow()
    @start_column = @sheet.getRange(start_ref).getColumn()
    @timers = []

  at: (i)->
    starttimer = new Date()
    if i > @size
      throw new Error "OutOfRange"

    range = @sheet.getRange(@start_row+i,@start_column,1,@N)
    values = range.getValues()

    joined = values[0].join "|"
    joined = @translator(joined) if @translator?
    @timers.push new Date().getTime() - starttimer.getTime()
    return joined

_encodeVector = (vec) ->
  val = []
  vec.each (e)->
    val.push bigint.FromInt(e).toStr(32)
  val.join()

_encodeArray = (arr) ->
  convert = (elem)->
    return if elem instanceof bigint then elem.toStr(32) else bigint.FromInt(e).toStr(32)

  (convert(e) for e in arr).join()


encodeMatrix = (m) ->
  if m[0] instanceof Array
    ret = (_encodeArray(v) for v in m).join("|")
  else
    ret = _encodeArray m

  ret

decodeMatrix = (string) ->
  resultArr = []
  rows = string.split("|")
  for row in rows
    do (row)->
      b32StoInt = (str)->
        val = bigint.ParseFromString(str,32,2)
        val.asInt()
      b32StoBigInt = (str)->
        bigint.ParseFromString(str,32,2)
      elems = ( b32StoBigInt(elem) for elem in row.split(",") )
      resultArr.push elems

  return resultArr

###### VECTOR FUNCTIONS ######
# These handle overflow by transforming to
# bigints, doing the operation, moduloing,
# and returning
#

safeVectorAdd = (v1,v2,modulo) ->
  throw new Error "InsufficientArgs" unless modulo?

  for e,i in v1
    timer = new Date().getTime()
    e.addEquals(v2[i])
    profile.addTime 'add', new Date().getTime() - timer
    timer = new Date().getTime()
    e.modEquals(modulo)
    profile.addTime 'modulo', new Date().getTime() - timer
    e

safeVectorMultiply = (v,scalar,modulo)->
  #scalar is a bigint, v is probably not a Vector
  throw new Error "InsufficientArgs" unless modulo?
  # We have to watch for overflows like crazy!
  if typeof scalar is not "BigInt"
    throw new Error "Invalid Type"

  for rowelem in v
    timer = new Date().getTime()
    #rowelem.modMultiplyEquals(scalar,modulo)
    rowelem.multiplyEquals(scalar)
    profile.addTime 'multiply', new Date().getTime() - timer
    timer = new Date().getTime()
    rowelem.modEquals(modulo)
    profile.addTime 'modulo', new Date().getTime() - timer
    rowelem

module.exports =
  decodeMatrix: decodeMatrix
  safeVectorAdd: safeVectorAdd
  safeVectorMultiply: safeVectorMultiply
  encodeMatrix: encodeMatrix
  DbProvider: DbProvider
  SpreadsheetDbProvider: SpreadsheetDbProvider
  SpreadsheetQueryProvider: SpreadsheetQueryProvider
  Log: Log
  inspectArray: inspectArray
  AESHexTranslator: AESHexTranslator
  Profiler: profile

