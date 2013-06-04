pir = require '../pir'
bigint = require 'bigint-node'
util = require '../util'
should = require 'should'

class TestDbProvider extends util.DbProvider

  _db: ["v","1a"]

  at: (i)=>
    if i > @size
      throw new Error "OutOfRange"

    return bigint.ParseFromString(@_db[i],32,2)

describe 'PirInstance', ->
  params =
    N: 2
    n: 2
    l: 6
    i_0: 2
    P: 521
    l_0: 3

  p = new pir.PirInstance params

  describe '#constructor', ->

    it "should support N=50, l_0=20", ->
      test_params = 
        N: 50
        n: 20
        l: 4000
        l_0: 20
        P: 1152921504606847009

      (()->
        new pir.PirInstance(test_params)
      ).should.not.throw


    it "should set params", ->
      p.params.should.equal params
      p.params.l_0.should.equal 3

    it 'should check for small primes', ->
      badparams =
        N: 250
        n: 2
        l: 6
        i_0: 2
        P: 19
        l_0: 3
      ( ->
        tmp = new pir.PirInstance badparams
      ).should.throw(/prime/)

  dbReader = new TestDbProvider(2)
  p.setDbReader dbReader
  describe 'splitDbElem', ->
    it "should split database elements correctly", ->
      expected = [bigint.FromInt(3), bigint.FromInt(7)]

      elem = p.reader.next()
      split = p.splitDbElem(elem)
      for e,i in split
        do (e,i)->
          e.eql(expected[i]).should.be.true

      expected = [bigint.FromInt(5), bigint.FromInt(2)]
      elem = p.reader.next()
      split = p.splitDbElem(elem)
      for e,i in split
        do (e,i)->
          e.eql(expected[i]).should.be.true

  describe '#constructPartVectors', ->
    it 'should multiply each db elem by query', ->

      user_query = util.decodeMatrix "3d,84,5j,2a|at,7p,5,fs"
      console.log "Decoded matrix: #{user_query}"

      expected = [bigint.ConvertArray([327, 259, 16, 222]),
                  bigint.ConvertArray([359,180,35,430])]
      result = p.constructPartVectors(0,user_query)

      for row,i in result
        for v, j in row
          v.eql(expected[i][j]).should.be.true

  describe '#calculatePartialRow', ->
    it 'should multiply each db elem by query', ->

      user_query = util.decodeMatrix "3d,84,5j,2a|at,7p,5,fs"
      console.log "Decoded matrix: #{user_query}"

      expected = [bigint.ConvertArray([327, 259, 16, 222]),
                  bigint.ConvertArray([359,180,35,430])]

      dbElem = p.reader.at(0)
      elemPieces = p.splitDbElem(dbElem)
      result = p.calculatePartialRow(user_query,elemPieces,0)

      for row,i in result
        for v, j in row
          v.eql(expected[i][j]).should.be.true

  describe 'computeResponse', ->
    user_query1 = util.decodeMatrix "3d,84,5j,2a|at,7p,5,fs"
    user_query2 = util.decodeMatrix "9j,6n,9e,cr|97,e6,92,6c"

    check = (result,expected) ->
      for row,i in result
        for elem,j in row
          elem.eql(expected[i][j]).should.be.true

    computed = null

    it 'should be correct', ->
      expected = [bigint.ConvertArray([206,338,57,510])]
      computed = p.computeResponse([user_query1,user_query2])

      check computed,expected

    it 'should encode correctly', ->
      expected = "6E,AI,1P,FU"
      should.exist computed
      encoded = pir.PirInstance.encodeResponse(computed)

      encoded.should.equal expected

    it 'should return the sames result as the old method given a small dbelem',->
      computed = p.computeResponse([user_query1,user_query2])
      computed_old = p.computeResponse_old([user_query1,user_query2])

      check computed[0],computed_old


