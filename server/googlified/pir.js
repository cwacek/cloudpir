// Generated by CoffeeScript 1.4.0
var pir = (function() {
  var PirInstance;

  PirInstance = (function() {

    PirInstance.magicProps = {
      N: 64,
      n: 10,
      l: 512,
      P: 16777259
    };

    function PirInstance(params) {
      this.params = params;
      this.params['l_0'] = this.params['l_0'] || Math.ceil(Math.log(this.params.N * this.params.n)) + 1;
      if (typeof this.params.P === 'number') {
        this.params.P = bigint.FromInt(this.params.P);
      } else if (this.params.P instanceof String) {
        this.params.P = bigint.parseFromString(this.params.P, 10);
      }
      if (bigint.FromInt(1).shiftLeft(3 * this.params.l_0).gt(this.params.P)) {
        throw new Error("prime 'p' insufficiently large");
      }
      this.params.L = Math.ceil((this.params.l / this.params.l_0) / this.params.N);
      util.Log("Instantiated PirInstance with l_0=" + this.params.l_0 + " and L=" + this.params.L);
    }

    PirInstance.prototype.splitDbElem = function(elem) {
      var fields, splitFields, splitInt, timer,
        _this = this;
      splitInt = function(int, masklen) {
        var bits;
        bits = int.getNRightmostBits(masklen);
        int.shiftRight(masklen);
        return bits;
      };
      splitFields = [];
      while (elem.gt(bigint.Zero())) {
        timer = new Date().getTime();
        splitFields.push(splitInt(elem, this.params.l_0));
        util.Profiler.addTime('splitInt', new Date().getTime() - timer);
      }
      fields = splitFields.reverse();
      return fields;
    };

    /**
      * Sets the provider to use to read the database elements.
      *
      * @param {DbProvider} reader the insantiated DbProvider instance
      * @return {null}
    */


    PirInstance.prototype.setDbReader = function(reader) {
      this.reader = reader;
    };

    PirInstance.prototype.calculatePartialRow = function(queryMatrix, splitElem, rowNum) {
      var elem, i, multiplied_row, query_row, start, vectors, _i, _ref;
      start = rowNum * this.params.N;
      vectors = [];
      for (i = _i = start, _ref = start + this.params.N; _i < _ref; i = _i += 1) {
        elem = splitElem[i];
        query_row = queryMatrix[i % this.params.N];
        multiplied_row = util.safeVectorMultiply(query_row, elem, this.params.P);
        vectors.push(multiplied_row);
      }
      return vectors;
    };

    PirInstance.prototype.computeResponse = function(queryMatrices) {
      var dbElem, elemPieces, i, matrix, partial, partials, response, response_row, rowNum, _i, _j, _k, _len, _len1, _ref;
      response = [];
      for (rowNum = _i = 0, _ref = this.params.L; _i < _ref; rowNum = _i += 1) {
        response_row = (function() {
          var _j, _ref1, _results;
          _results = [];
          for (i = _j = 1, _ref1 = 2 * this.params.N; 1 <= _ref1 ? _j <= _ref1 : _j >= _ref1; i = 1 <= _ref1 ? ++_j : --_j) {
            _results.push(bigint.Zero());
          }
          return _results;
        }).call(this);
        for (i = _j = 0, _len = queryMatrices.length; _j < _len; i = ++_j) {
          matrix = queryMatrices[i];
          util.Log("Computing row " + rowNum + " of response with for matrix " + i);
          dbElem = this.reader.at(i);
          elemPieces = this.splitDbElem(dbElem);
          util.Log("Split dbElem into " + elemPieces.length + " pieces");
          partials = this.calculatePartialRow(matrix, elemPieces, rowNum);
          for (_k = 0, _len1 = partials.length; _k < _len1; _k++) {
            partial = partials[_k];
            response_row = util.safeVectorAdd(response_row, partial, this.params.P);
          }
        }
        response.push(response_row);
      }
      return response;
    };

    PirInstance.prototype.constructPartVectors = function(elemIdx, query) {
      var chunk, elem, j, multiplied_row, row, vectors, _i, _len, _ref;
      vectors = [];
      elem = this.reader.at(elemIdx);
      util.Log("Read element at " + elemIdx + ": " + elem);
      _ref = this.splitDbElem(elem);
      for (j = _i = 0, _len = _ref.length; _i < _len; j = ++_i) {
        chunk = _ref[j];
        row = query[j];
        multiplied_row = util.safeVectorMultiply(row, chunk, this.params.P);
        vectors.push(multiplied_row);
      }
      return vectors;
    };

    PirInstance.prototype.computeResponse_old = function(queryMatrices) {
      var answer, i, j, matrix, part, _i, _j, _len, _len1, _ref;
      answer = (function() {
        var _i, _ref, _results;
        _results = [];
        for (i = _i = 1, _ref = 2 * this.params.N; 1 <= _ref ? _i <= _ref : _i >= _ref; i = 1 <= _ref ? ++_i : --_i) {
          _results.push(bigint.Zero());
        }
        return _results;
      }).call(this);
      util.Log("Computing response over " + queryMatrices.length + " querymatrices");
      for (i = _i = 0, _len = queryMatrices.length; _i < _len; i = ++_i) {
        matrix = queryMatrices[i];
        _ref = this.constructPartVectors(i, matrix);
        for (j = _j = 0, _len1 = _ref.length; _j < _len1; j = ++_j) {
          part = _ref[j];
          answer = util.safeVectorAdd(answer, part, this.params.P);
        }
      }
      return answer;
    };

    PirInstance.encodeResponse = function(responseVector) {
      return util.encodeMatrix(responseVector);
    };

    PirInstance.prototype.computeResponsePartial = function(index, queryMatrix) {
      var answer, i, part, _i, _len, _ref;
      answer = (function() {
        var _i, _ref, _results;
        _results = [];
        for (i = _i = 1, _ref = 2 * this.params.N; 1 <= _ref ? _i <= _ref : _i >= _ref; i = 1 <= _ref ? ++_i : --_i) {
          _results.push(bigint.Zero());
        }
        return _results;
      }).call(this);
      _ref = this.constructPartVectors(index, queryMatrix);
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        part = _ref[_i];
        answer = util.safeVectorAdd(answer, part, this.params.P);
      }
      return answer;
    };

    return PirInstance;

  })();

  return {
    PirInstance: PirInstance
  };

}).call(this);