require 'rubygems'
require 'bundler/setup'

require 'matrix'
require_relative 'modulo'
require 'pry'



class PirMatrixState

  attr_reader :main_matrix, :params,  :permuted_M_primes, :delta

  @@DEFAULT_PARAMS = {
    #N: 64,
    #n: 10,
    #l: 512,
    #P: 16777259
  }

  def initialize(params= @@DEFAULT_PARAMS, testing_vectors = nil)
    @params = params
    @params[:l_0] = @params[:l_0] || Math.log(params[:n]*params[:N]).ceil + 1
    @params[:q] = 2 ** (2*@params[:l_0])

    @test_params = testing_vectors
    @memo = Hash.new
    #throw RuntimeError, "l/l_0 != N" if (@params[:l] / @params[:l_0]) != @params[:N]
    throw RuntimeError, "P < 2 ** 3*l_0" if (@params[:P] < (2**(3*params[:l_0])))
  end



  def test?
    !@test_params.nil?
  end

  def self.gen_random_invertible(dim,modulo)
    while true
      begin
        m = Matrix.build(dim) do
          rand(modulo)
        end
        m.invert_modulo modulo
      rescue InversionError
        redo
      else
        return m
      end
    end
  end

  def gen_random_diagonal(dim)
    Matrix.build(dim) do |r,c|
      if r != c
        0
      else
        rand(@params[:P])
      end
    end
  end

  def generateABM
    @A = test? ? @test_params[:A] : PirMatrixState.gen_random_invertible(@params[:N],
                                                                         @params[:P])
    @B = test? ? @test_params[:B] : Matrix.build(@params[:N]) do
      rand(@params[:P])
    end

    @main_matrix = Matrix.build(@params[:N],@params[:N] *2) do |row,col|
      if col < @params[:N]
        val = @A[row,col]
      else
        val = @B[row,col - @params[:N]]
      end
      val
    end
  end

  def generate_M_doubleprime_matrices(p_matrices)
    doubleprimes = Array.new
    for i in 0...@params[:n]
      m_i_doubleprime =  p_matrices[i] * main_matrix
      doubleprimes.push m_i_doubleprime.collect {|e| e % @params[:P]}
      $stderr.puts "Generated #{i+1}/#{@params[:n]} doubleprime matrices"
    end
    return doubleprimes
  end

  def delta
    if test?
      return @test_params[:delta]
    else
    @memo[:delta] ||= gen_random_diagonal(@params[:N])
    end
  end

  def generate_distortion_matrices

    if test?
      d_i = @test_params[:D]
      #d_i = @test_params[:SDM]
      #d_i.insert(@params[:i_0]-1,@test_params[:HDM])
    else
      d_i = Array.new
      choices = [-1,0,1]
      for i in 1..@params[:n]
        if i == @params[:i_0]
          d = Matrix.build(@params[:N]) do |r,c|
            if r == c
              @params[:q]
            else
              choices.sample
            end
          end
        else
          d = Matrix.build(@params[:N]) do
            choices.sample
          end
        end
        d_i.push d
      end
    end
    return d_i
  end

  def pick_permutation
    @permute = (test? && @params[:permute]) || (1..(2*@params[:N])).to_a.shuffle
  end

  # Reverse the permutation of a matrix 
  # or vector permuted by do_permute
  def reverse_permute(m)
    reversed = Array.new

    case (m)
    when Matrix
      if m.column_size() != @permute.size()
        raise RuntimeError, "# columns of permutations and matrix columns must match"
      end
      @permute.each_with_index do |shift,i|
        reversed[shift - 1] = m.column(i)
      end

      return Matrix.columns(reversed)

    when Vector
      if m.size() != @permute.size()
        raise RuntimeError, "# columns of permutation and vector elements must match"
      end
      @permute.each_with_index do |shift,i|
        reversed[shift - 1] = m[i]
      end

      return reversed

    else
      throw :UnsupportedType
    end
  end

  # Permute a matrix or vectorby the chosen permutation.
  # Always returns a matrix
  def do_permute(m)
    permuted = @permute.map do |idx| # Permutations index from 1!
      if m.kind_of? Matrix
        m.column(idx - 1)
      elsif m.kind_of? Vector
        m[idx - 1]
      else
        throw :UnsupportedType
      end
    end
    return Matrix.columns(permuted) if m.kind_of? Matrix
    return permuted
  end

  def compute_M_prime_matrices(doubleprimes, disturbed)
    m_i_primes = Array.new

    doubleprimes.each_with_index do |m_i_doubleprime,i|
      disturb = disturbed[i]
      m_i_prime = Matrix.build(@params[:N],@params[:N]*2) do |r,c|
        if c < @params[:N]
          m_i_doubleprime[r,c] % @params[:P]
        else
          (m_i_doubleprime[r,c] + disturb[r,c - @params[:N]]) % @params[:P] 
        end
      end
      m_i_primes.push m_i_prime
    end
    return m_i_primes
  end

  def extract_noise(noisy_vector)
    undisturbed = Vector.elements noisy_vector.to_a[0...@params[:N]]
    disturbed = Vector.elements noisy_vector.to_a[@params[:N]..noisy_vector.size()]


    tmp = undisturbed.covector.mod_multiply(@A.invert_modulo(@params[:P]),
                                             @params[:P])
    undisturbed_noise = tmp.mod_multiply(@B,
                                         @params[:P])

    scrambled_noise = (disturbed.covector - undisturbed_noise).map do |x|
      (x + @params[:P]) % @params[:P]
    end
    unscrambled_noise = scrambled_noise.mod_multiply(delta.invert_modulo(@params[:P]),
                                                    @params[:P])

    return unscrambled_noise.row(0)
  end

  def extract_reply(unscrambled_noise)
    q = @params[:q]
    q_invert = @params[:q] ** -1
    reply_parts = unscrambled_noise.map do |e|
      epsilon = (e % @params[:q]) < ( q/2 ) ?
                    e % q : (e % q) - q
      part = (e - epsilon) * q_invert
      part.to_i.to_s(2).rjust(@params[:l_0],"0")
    end

    return reply_parts.to_a.join("")
  end

  def decode(response,convert=nil)
    result = ""
    decoded = PirProtocol.decode_str(response)
    decoded.row_vectors.each do |vec|
      reversed = reverse_permute(vec)
      noisy = extract_noise(reversed)
      clean = extract_reply(noisy)
      result += clean
    end
    reply = []
    until result.empty?
      c = result.slice!(0,8)
      c = c.to_i(2)
      reply << c if c != 255
    end
    return reply
  end

end

class PirProtocol

  def self.encode_matrix(m1,base=32)
    row = m1.row_vectors.map do |v|
      v.map {|e| "#{e.to_s(base)}"}.to_a.join(",")
    end
    str = "#{row.join("|")}"
    str.upcase
  end

  def self.decode_str(str, base=32)
    rowarr =  str.split("|").map do |row|
      row.split(",").map do |elem|
        elem.to_i(base)
      end
    end
    Matrix.rows rowarr
  end
end
