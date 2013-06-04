pir = require './pir'
util = require './util'
bigint = require 'bigint-node'
read = require 'read'
fs = require 'fs'
argv = require('optimist') .argv
wrap = require('wordwrap').hard(0,160)

class FileDbProvider extends util.DbProvider

  constructor: (@size,@translator, filename)->
    data = fs.readFileSync filename, 'utf8'
    @_db = []
    for line,i in data.split('\n')
      break if i > @size
      @_db.push line

  at: (i)->
    @timers = @timers || []
    starttimer = new Date()
    if i > @size
      throw new Error "OutOfRange"

    @timers.push new Date().getTime() - starttimer.getTime()
    return @_db[i]


class TestDbProvider extends util.DbProvider

  _db: ["101101", "110011"]

  at: (i)=>
    if i > @size
      throw new Error "OutOfRange"

    return bigint.ParseFromString(@_db[i],2,2)

class LargeTestDbProvider extends TestDbProvider
  old_db: [
     "            my name is fred                                     ",
     "                    his name is james                           ",
     "alfred once knew                                          his ti",
     "v000000000000000000000000000000000000000000000000000000000000000",
     "1900000000000000000000000000000000000000000000000000000000000000",
     "1j00000000000000000000000000000000000000000000000000000000000000",
     "1t00000000000000000000000000000000000000000000000000000000000000",
     "2700000000000000000000000000000000000000000000000000000000000000",
     "2h00000000000000000000000000000000000000000000000000000000000000",
     "2r00000000000000000000000000000000000000000000000000000000000000"
  ]

  _db: [
    "3780a7e0aa0f28c74655254c5c2d54347c31fd9fa0781fb09b387bd03558d0363d2cc1da",
    "c148b8f74dac0c985671ac96e7b4b0ba5e7b961253d588cfcf01cca3a8c9c74ee4bdeb4628e3c7e977c253e93bdf1a",
    "5950bf872ea2c9a636da4ae21cb0ebab4b3fde3e8852ddc6492b9fa2cd969aaf7d7400a3",
    "cc0bcd2aa56ee6bd34ce0880094750358b2eb67cc37304dd7123c687dc9faae0ccc3d0b6c0c9b50ec2",
    "c9a952d5aabded9233fa11a13f286f76475478408f7f63f78e788f3a20cc123438",
    "6876ea599cd6c27030677e6e1eaaed341e4d0cea9cb5b00328bb66dd42a499c89e0fcfe4810190351a21d00c45f9838e9eba311429dde12775ab",
    "66817d42cdcf0b2c7e62251af6801cb9fc5747fdfe72618dacfc0fd97f140af027f7",
    "e8d367e617bd8ccff935663056f3e66d15d9cddc1da12c66466c42b86c5e7a11fd036eeb8c4aa21a7c04aa",
    "9ab6ff43da1a7f617b6d710861e9f309bcaf1a5d1914d74ac8345fbc40d2e98e9601",
    "e2f3924c8d7efce1d1de1a448b0fc509cb736537b2c92a1bcf3df4d7608820bbf1642f65e1a4fd027fb737ed",
  ]

  at: (i)=>
    @timers = @timers || []
    starttimer = new Date()

    if i > @size
      throw new Error "OutOfRange"

    val = @translator @_db[i]
    @timers.push new Date().getTime() - starttimer.getTime()
    return val

big_params =
      N: 64
      n: 10
      l: 512
      l_0: 8
      P: bigint.ParseFromString('16777259',10,0)


new_params = null
switch argv.params
  when "50-20"
    new_params =
      N: 50
      n: 10
      l: 1000
      l_0: 20
      P: bigint.ParseFromString('1152921504606847009',10,0)
  when "50-12"
    new_params =
      N: 50
      n: 10
      l: 600
      l_0: 12
      P: bigint.ParseFromString('68719476767',10,0)
  when "50-16"
    new_params =
      N: 50
      n: 10
      l: 800
      l_0: 16
      P: bigint.ParseFromString('281474976710677',10,0)
  when "50-8"
    new_params =
      N: 50
      n: 10
      l: 400
      l_0: 8
      P: bigint.ParseFromString('16777259',10,0)

util.Log(new_params)

throw new Error "--params argument required" if not new_params?

    #params =
      #N: 2
      #n: 2
      #l: 6
      #P: 521
      #

p = new pir.PirInstance new_params
#chain = util.AESHexTranslator.UTFChainHelper(bigint.FromRawBytes)
options =
  chain: (val)->
    converted = bigint.FromRawBytes val
    #if converted.length != new_params.l
      #n_missing = new_params.l % 8
      #converted.shiftLeft(n_missing)
      #converted.addEquals(bigint.FromInt((1 << n_missing)- 1))


t = new util.AESHexTranslator("50db7d7ce3dd17af01c43c94825deed6c65eccf84fb1d9f5b3f2830b238c715a",options)
t.setPadLength(Math.floor(new_params.l/8))

dbReader = new LargeTestDbProvider(new_params.n,t.translate)
p.setDbReader(dbReader)

#p = new pir.PirInstance params
#dbReader = new TestDbProvider(params.n)
#p.setDbReader(dbReader)

throw new Error "--query argument required" if not argv.query

starttimer = new Date()

queryReader = new FileDbProvider(p.params.n,null,argv.query)

user_queries = []
queryReader.each (queryMatrix)->
  #console.log("Q: #{queryMatrix}")
  user_queries.push util.decodeMatrix(queryMatrix)

util.Log "Have #{user_queries.length} query matrices. "
util.Log "Each matrix has #{user_queries[0].length} elements"

dbReader.each (elem)->
  if p.params.l_0 == 8
    console.log "#{elem.toRawBytes()}"
  else
    s = elem.toStr(2,8)
    console.log wrap("#{s}")

computed = [p.computeResponse_old(user_queries)]
for row,i in computed
  console.log(wrap("Row #{i} [#{row.length} elements]: #{util.inspectArray(row)}"))

encoded = pir.PirInstance.encodeResponse(computed)
#console.log(wrap("Encoded (#{encoded.length} bytes): #{encoded}"))

fs.writeFile "answer.dat", encoded, (err) ->
  if err
    util.Log(err)
  else
    util.Log "Wrote response to 'answer.dat'"

util.Log("Started: #{starttimer.getTime()}. Ended: #{new Date().getTime()}")
util.Log("Timer:Server:Total:#{(new Date().getTime() - starttimer.getTime())/1000.0}")
util.Log("DBRead: #{dbReader.timers.join(",")} milliseconds")
util.Log("QueryRead: #{queryReader.timers.join(",")} milliseconds")


