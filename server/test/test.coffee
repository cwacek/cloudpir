assert = require 'should'
bigint = require 'bigint-node'
util = require '../util'
should = require 'should'
Crypto = (require '../cryptojs/cryptojs').Crypto

describe 'AESHexTranslator', ->
  it 'throws errors when given non-hex string keys',->
    (()->
      new util.AESHexTranslator("james")
    ).should.throw

  #it 'throws an error when keys are invalid sizes'

  it 'accepts hex keys and IVs',->
    t = new util.AESHexTranslator("abcdef")
    t.key.should.eql [171, 205, 239]

  it 'accepts byte keys',->
    t = new util.AESHexTranslator([171,205,239,128])
    t.key.should.eql [171,205,239,128]

  it 'applies the chain function to the decrypted result',->
      opts =
        chain: Crypto.util.bytesToHex

      t = new util.AESHexTranslator("abcdef1234561fedabcdef1234561fed",opts)

      enc = t.encrypt("I am a strange loop.")
      dec = t.translate(enc)

      dec.should.eql "4920616d206120737472616e6765206c6f6f702e"

  it 'decrypts properly', ->
    options =
      chain: (val)->
        Crypto.charenc.UTF8.bytesToString(val)

    t = new util.AESHexTranslator("abcdef1234561fedabcdef1234561fed",options)

    enc = t.encrypt("I am a strange loop.")
    translated = t.translate(enc)
    translated.should.eql "I am a strange loop."

    decrypted = t.decrypt(enc)
    decrypted.should.eql "I am a strange loop."

  it 'different IVs generate different values',->
      t = new util.AESHexTranslator("abcdef1234561fedabcdef1234561fed")

      enc = t.encrypt("I am a strange loop.")
      enc2 = t.encrypt("I am a strange loop.")

      enc.should.not.eql enc2

      dec1 = t.decrypt(enc)
      dec2 = t.decrypt(enc2)

      dec1.should.eql dec2




describe 'Util', ->

  describe 'decodeMatrix', ->
    it "should decode to a matrix", ->
      encoded = "3d,84,5j,2a|at,7p,5,fs"
      decoded = util.decodeMatrix(encoded)
      expected = [[109,260,179,74],[349,249,5,508]]
      should.exist decoded
      decoded.length.should.equal 2
      for row,i in decoded
        for elem,j in expected[i]
          row[j].toInt().should.equal elem

  describe 'safeVectorAdd',->

    v1 = [bigint.FromInt(80), bigint.FromInt(90)]
    v2 = [bigint.FromInt(40), bigint.FromInt(50)]
    exp = [bigint.FromInt(20), bigint.FromInt(40)]

    it 'should throw if not enough args', ->
      (()->
        util.safeVectorAdd(v1,v2)
      ).should.throw("InsufficientArgs")

    it "should do modulo and return correctly", ->
      for elem, i in util.safeVectorAdd(v1, v2, bigint.FromInt(100))
        do (elem,i)->
          elem.eql(exp[i]).should.be.true


      modulo = bigint.ParseFromString("68719476767",10,0)
      c = (val)->(bigint.ParseFromString(val,10,0))
      v1 = [c("89561747398"), c("128000133120"), c("52736856148"), c("67025748836"),c("32670915427")]
      v2 = [c("48999316241"), c("29895063785"), c("7242318366"), c("67264155939"),c("61053910646")]

      expected = [c("1122110105"),c("20456243371"),c("59979174514"),c("65570428008"),c("25005349306")]
      computed = util.safeVectorAdd(v1,v2,modulo)

      for elem,i in computed
        elem.toStr(10).should.eql expected[i].toStr(10)

  describe 'safeVectorMultiply', ->

    v1 = [bigint.FromInt(80), bigint.FromInt(90)]
    scalar = bigint.FromInt(23)

    it 'should throw if not enough args', ->
      (()->
        util.safeVectorMultiply(v1,scalar)
      ).should.throw("InsufficientArgs")

    it 'should return the correct value', ->
      k = bigint.FromInt(241)
      mod = bigint.FromInt(102)

      expected = [bigint.FromInt(2), bigint.FromInt(66)]
      for elem,i in util.safeVectorMultiply(v1,k,mod)
        do (elem,i)->
          elem.eql(expected[i]).should.be.true

    it 'should be okay with zero', ->
      k = bigint.FromInt(0)
      mod = bigint.FromInt(102)

      expected = [bigint.Zero(), bigint.Zero()]
      for elem,i in util.safeVectorMultiply(v1,k,mod)
        do (elem,i)->
          elem.eql(expected[i]).should.be.true
