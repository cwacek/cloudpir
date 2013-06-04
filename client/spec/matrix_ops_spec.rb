require 'simplecov'
SimpleCov.start
require_relative '../matrix_ops'

describe PirProtocol do
  context 'encoding ' do
    m1 = Matrix[[1,4,6],
                [250,23,112]]
    m1_hex = "#{1.to_s(32)},#{4.to_s(32)},#{6.to_s(32)}|#{250.to_s(32)},#{23.to_s(32)},#{112.to_s(32)}".upcase

    it "should convert to base32" do
      PirProtocol.encode_matrix(m1).should eql m1_hex
    end

    it "should decode from base32" do
      PirProtocol.decode_str(m1_hex).should eql m1
    end
  end
end

describe Modulo do
  context 'Matrix' do

    describe '#mod_add_row_in_place' do
      before :each do
        @m = Matrix[[1,21,14],[18,28,5],[4,17,1]]
      end

      it 'should edit in place' do
        @m.mod_add_row_in_place(0,Vector[10,10,10])
        @m.row(0).should eql Vector[11,31,24]
      end

      it 'should apply modulo' do
        @m.mod_add_row_in_place(0,Vector[10,10,10],15)
        @m.row(0).should eql Vector[11,1,9]
      end

      it 'should work with negative numbers' do 
        @m.mod_add_row_in_place(1,
                                Vector[-18,-378,-252],
                                29)

        @m.row(1).should eql Vector[0, 27, 14]
      end
    end


    describe '#mod_multiply_row' do
      before :each do
        @m = Matrix[[1,21,14],[18,28,5],[4,17,1]]
        @multiplied = @m.mod_multiply_row(0,4,29)
      end

      it 'should return a Vector' do
        @multiplied.should be_an_instance_of Vector
      end

      it 'should modulo if requested' do
        @multiplied.should eql Vector[4,26,27]
      end
    end

    describe '#mod_multiply_row_in_place' do
      before :each do
        @m = Matrix[[1,2,3],[4,5,6]]
      end

      it 'should multiply in place' do
        @m.mod_multiply_row_in_place(0,5)
        @m.should eql Matrix[[5,10,15],[4,5,6]]
      end
    end

    describe "#mod_multiply" do
      m1 = Matrix[[1,4,6]]
      m2 = Matrix[[2,3],[5,8],[7,9]]
      m3 = Matrix[[7,8,0],[2,3,4]]
      m1_m2_result = Matrix[[64,89]]

      it "should test matrix dimensions are valid" do
        lambda {
          m1.mod_multiply(m3,128)
        }.should raise_error(RuntimeError)
      end

      it "should multiply correctly" do
        t1 = m1.mod_multiply(m2,128)
        t1.should == m1_m2_result
      end

      it "should apply modulus" do
        t1 = m1.mod_multiply(m2,32)
        t1.should == Matrix[[64 % 32, 89 % 32]]
      end

      it "should handle negative numbers" do
        m1 = Matrix[[1,-1],[-1,1]]
        m2 = Matrix[[443,0],[0,503]]

        m1.mod_multiply(m2,521).should == Matrix[[443, -503],[-443,503]]
      end
    end

    describe '#invert_modulo' do
      before :all do
        @modulo = 31
        @start = PirMatrixState.gen_random_invertible(2,@modulo)
        @inverted = @start.invert_modulo  @modulo
      end

      it 'should return a Matrix of equal size' do
        @start.row_size.should equal @inverted.row_size
        @start.column_size.should equal @inverted.column_size
      end

      it 'should calculate the matrix inverse modulo' do 
        identity = @inverted.mod_multiply @start, @modulo
        identity.should eql Matrix.identity(2)
      end

      it 'should work with zeros in the diagonal' do
        start = Matrix[[0, 8], [17, 0]]
        inverse = start.invert_modulo @modulo
        identity = inverse.mod_multiply start, @modulo
        identity.should eql Matrix.identity(2)
      end

      it 'should work with N dimensions' do
        (3..10).each do |n|
          puts "Testing inverse of #{n} dimension matrix"
          start = PirMatrixState.gen_random_invertible(n,@modulo)
          inverse = start.invert_modulo @modulo
          identity = inverse.mod_multiply start, @modulo
          identity.should eql Matrix.identity(n)
        end
      end


    end

  end
end

describe PirMatrixState do

  before :all do
    @expected = Hash.new
    @expected[:A] =Matrix[[106,429],
                          [277,398]]
    @expected[:B] =  Matrix[[32,375],
                            [345,492]]
    @expected[:M] =  Matrix[[106,429,32,375],
                            [277,398,345,492]]
    @expected[:P] =  [Matrix[[469,487],
                             [312,1]],
    Matrix[[355,469],
           [398,492]]
    ]
    @expected[:delta] =  Matrix[[443,0],
                                [000,503]]
    @expected[:D] =  [Matrix[[1,-1],
                             [-1,1]],
    Matrix[[64,0],
           [-1,64]]
    ]
    @expected[:M_doubleprime] =  [
      Matrix[[179,109,152,242],
             [5,349,430,267]],
      Matrix[[302,307,193,215],
             [290,295,126,43]]
    ]
    @expected[:HDM] =  Matrix[[218,000],
                              [-443,411]]
    @expected[:SDM] =  [
      Matrix[[443,-503],
             [-443,503]]
    ]
    @expected[:M_prime] =  [
      Matrix[[179,109,74,260],
             [5,349,508,249]],
      Matrix[[302,307,411,215],
             [290,295,204,454]] # <-- This 454 is right. I know the paper says 451 but it's a typo
    ]
    @expected[:permuted_M_primes] = [
      Matrix[[109,260,179,74],
             [349,249,5,508]],
      Matrix[[307,215,302,411],
             [295,454,290,204]] # <-- This 454 is right. I know the paper says 451 but it's a typo
    ]

    @test_params = {
      N: 2,
      n: 2,
      l: 6,
      i_0: 2,
      P: 521,
      permute: [2,4,1,3]
    }
    @instance = PirMatrixState.new(@test_params,@expected)
  end

  context "instance methods" do

    context 'constructor' do 
      it 'should accept pre-initialized vectors' do
        @instance.should be_an_instance_of PirMatrixState
        @instance.params[:l_0].should eql 3
        @instance.params.each do |param,val|
          val.should eql @test_params[param]
        end
      end
    end

    context '#generate_M_doubleprime_matrices' do
      before :each do
        #Mock @main_matrix
        class PirMatrixState
          def main_matrix
            Matrix[[106,429,32,375],[277,398,345,492]] 
          end
        end
      end

      it 'should return mod_multiplied matrices' do
        random_invertibles = (1..@test_params[:n]).map do |x| 
          PirMatrixState.gen_random_invertible @test_params[:N], @test_params[:P]
        end
        @instance.generate_M_doubleprime_matrices random_invertibles
      end

    end


    context '#gen_random_diagonal' do
      before :each do
        @generated = @instance.gen_random_diagonal(@test_params[:N])
      end
      it 'should create a NxN matrix' do
        @generated.should be_an_instance_of Matrix
        @generated.row_size.should equal @test_params[:N]
        @generated.column_size.should equal @test_params[:N]
      end

      it 'should generate a random diagonal over P' do
        @generated.each do |e|
          e.should be < @test_params[:P] unless e.nil?
        end
      end
    end

    context '#generate_distortion_matrices' do
      before :each do 
        instance = PirMatrixState.new(@test_params)
        @dist = instance.generate_distortion_matrices
      end
      it 'should generate n distortion matrices' do
        @dist.length.should equal @test_params[:n]
      end

      it 'should make one of them hard' do
        @dist[@test_params[:i_0]-1].each_with_index do |e,r,c|
          e.should equal @test_params[:q] if r == c
        end
      end
    end
  end

  context 'Paper Example' do

    it 'should calculate M correctly' do
      @instance.generateABM()
      @instance.main_matrix.should == @expected[:M]
    end

    it 'should generate M_doubleprime correctly' do
      random_invertibles = (1..@test_params[:n]).map do |x| 
        PirMatrixState.gen_random_invertible @test_params[:N], @test_params[:P]
      end
      doubleprimes = @instance.generate_M_doubleprime_matrices @expected[:P]

      doubleprimes.each_with_index do |m,i|
        m.should == @expected[:M_doubleprime][i]
      end
    end

    it 'should generate SDMs and HDMS according to example' do
      noise = @instance.generate_distortion_matrices()
      delta = @instance.delta

      disturbed = noise.map do |noisy|
        noisy.mod_multiply(delta, 521)
      end

      offset = 0
      disturbed.each_with_index do |d,i|
        if i == @test_params[:i_0]-1
          d.should == @expected[:HDM]
          offset = 1
        else
          d.should == @expected[:SDM][i-offset]
        end
      end
    end

    it 'should generate M_prime correctly' do
      m_i_primes = @instance.compute_M_prime_matrices(@expected[:M_doubleprime],
                                                      @expected[:SDM]+[@expected[:HDM]])

      m_i_primes.each_with_index do |m,i|
        m.should == @expected[:M_prime][i]
      end
    end

    context 'final step' do 
      before :all do
        @instance.pick_permutation
        @permuted_M_primes = @expected[:M_prime].map do |m_prime|
          @instance.do_permute(m_prime)
        end
      end

      it 'should permute properly' do

        @permuted_M_primes.each_with_index do |m,i|
          m.should ==@expected [:permuted_M_primes][i]
          #puts "Permuted M_#{i}_prime: #{m}"
        end

        @permuted_M_primes.each_with_index do |m,i|
          reversed = @instance.reverse_permute(m)
          reversed.should == @expected[:M_prime][i]
        end
      end

      it 'should create encoded output' do
        @permuted_M_primes.each_with_index do |m,i|
          print "\"#{PirProtocol.encode_matrix(m)}\" "
        end
        puts

      end
    end

    it 'should do the whole process correctly' do
    instance = PirMatrixState.new(@test_params,@expected)
    #Generate ABM
    instance.generateABM
    #Generate Ps

    m_doubleprime = instance.generate_M_doubleprime_matrices @expected[:P]
    m_doubleprime.each_with_index {|m,i| m.should == @expected[:M_doubleprime][i]}

    noise = instance.generate_distortion_matrices
    puts "noise: #{noise}"
    noise.each_with_index {|m,i| m.should == @expected[:D][i]}

    disturbed = noise.map { |d| d.mod_multiply(instance.delta,@test_params[:P])}
    puts "disturbed: #{disturbed}"

    m_primes = instance.compute_M_prime_matrices(m_doubleprime, disturbed)
    m_primes.each_with_index {|m,i| m.should == @expected[:M_prime][i]}

    instance.pick_permutation
    permuted = m_primes.map {|m| instance.do_permute m}

    puts "Complete. Query matrices below"
    permuted.each_with_index do |m,i|
      m.should == @expected[:permuted_M_primes][i]
      print "\"#{PirProtocol.encode_matrix(m)}\" "
    end
    puts
  end
end

context 'Response Extraction' do

  before :all do
    # Monkeypatch @A_inverse and @delta_inverse
    #def @instance.invert_A
    #Matrix[[65, 214],[409,88]]
    #end
    #def @instance.invert_delta
    #Matrix[[354,0],[0,492]]
    #end
  end

  it 'should extract and unscramble noise' do
    noisy_vector = Vector[57,206,510,338]
    unscrambled_noise = @instance.extract_noise(noisy_vector)
    unscrambled_noise.should == Vector[314, 132]
  end

  it 'should extract the database reply' do
    unscrambled_noise = Vector[314, 132]
    @instance.extract_reply(unscrambled_noise).should == "101010"
  end

  it 'should decode the correct answer' do
    response = "6E,AI,1P,FU"

    answer = @instance.decode response
    answer.should eql [42]

  end
end
end

