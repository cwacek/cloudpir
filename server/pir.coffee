bigint = require "bigint-node"
util = require "./util"

class PirInstance

  @magicProps =
    N: 64
    n: 10
    l: 512
    P: 16777259

  constructor: (@params)->
    @params['l_0'] = @params['l_0'] || Math.ceil(Math.log(@params.N*@params.n)) + 1


    if typeof @params.P == 'number'
      @params.P = bigint.FromInt(@params.P)
    else if @params.P instanceof String
      @params.P = bigint.parseFromString(@params.P,10)

    if bigint.FromInt(1).shiftLeft(3*@params.l_0).gt @params.P
      throw new Error "prime 'p' insufficiently large"

    @params.L = Math.ceil((@params.l / @params.l_0) / @params.N)

    util.Log("Instantiated PirInstance with l_0=#{@params.l_0} and L=#{@params.L}")

  splitDbElem: (elem)->
    splitInt = (int, masklen)=>
      bits = int.getNRightmostBits(masklen)
      int.shiftRight(masklen)
      bits

    splitFields = []
    while elem.gt bigint.Zero()
      timer = new Date().getTime()
      splitFields.push splitInt(elem, @params.l_0)
      util.Profiler.addTime 'splitInt', new Date().getTime() - timer

    fields = splitFields.reverse()
    return fields

  ###*
    * Sets the provider to use to read the database elements.
    *
    * @param {DbProvider} reader the insantiated DbProvider instance
    * @return {null}
    ###
  setDbReader: (@reader)->

  calculatePartialRow: (queryMatrix, splitElem, rowNum) ->
    start = rowNum * @params.N

    vectors = []
    for i in [start...start+@params.N] by 1
      #util.Log("Calculating partial using elem chunk #{i}")
      elem = splitElem[i]
      query_row = queryMatrix[i%@params.N]

      #util.Log("Multiplying dbElem #{elem.toStr(10)} against #{util.inspectArray(query_row)}")
      multiplied_row = util.safeVectorMultiply(query_row,
                                               elem,
                                               @params.P)

      vectors.push multiplied_row

    return vectors

  computeResponse: (queryMatrices) ->

    response = []
    # We do this for each Row of the response
    for rowNum in [0...@params.L] by 1

      response_row = (bigint.Zero() for i in [1..2*@params.N])
      for matrix,i in queryMatrices
        util.Log("Computing row #{rowNum} of response with for matrix #{i}")

        dbElem = @reader.at(i)
        elemPieces = @splitDbElem(dbElem)
        util.Log("Split dbElem into #{elemPieces.length} pieces")
        partials = @calculatePartialRow(matrix,elemPieces,rowNum)
        for partial in partials
          response_row = util.safeVectorAdd(response_row,partial,@params.P)

      response.push response_row

    return response


  constructPartVectors: (elemIdx,query) ->
    vectors = []
    elem = @reader.at(elemIdx)
    util.Log "Read element at #{elemIdx}: #{elem}"
    for chunk,j in @splitDbElem(elem)
      #Fucking matrices index from 1
      #row = query.row(j+1)

      row = query[j]
      #util.Log "Computing partial over #{util.inspectArray(row)} and #{bigChunk.toStr(10)}"
      multiplied_row = util.safeVectorMultiply(row,
                                               chunk,
                                               @params.P)

      vectors.push multiplied_row

    return vectors

  computeResponse_old: (queryMatrices) ->

    answer = ( bigint.Zero() for i in [1..2*@params.N])
    util.Log("Computing response over #{queryMatrices.length} querymatrices")
    for matrix,i in queryMatrices
      for part,j in @constructPartVectors(i,matrix)
        #util.Log "Computed partial answer #{j}/#{@params.N} for Matrix #{i}/#{@params.N}"
        answer = util.safeVectorAdd(answer,part,@params.P)

    return answer


  @encodeResponse: (responseVector) ->
    return util.encodeMatrix(responseVector)

  computeResponsePartial: (index,queryMatrix) ->
    answer = ( bigint.Zero() for i in [1..2*@params.N])
    for part in @constructPartVectors(index,queryMatrix)
      answer = util.safeVectorAdd(answer,part,@params.P)

    return answer

module.exports = {
  PirInstance: PirInstance
  }



