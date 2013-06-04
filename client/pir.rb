require 'rubygems'
require 'bundler/setup'

require 'faraday'
require 'nokogiri'
require 'google_drive'
require 'pry'
require 'trollop'
require_relative './matrix_ops'

opts = Trollop::options do
  banner <<-EOS
Usage: ruby pir.rb -e <element number> -p <param_set> [-g | -o <query.dat>] [-v] [--dbelems <dbsize>]

Request the element at <element number> using parameters <param_set>. 
<element_number> indexes from 1.

Parameter Sets:
  There are variety of preloaded parameters sets. They're specified
  by the size of the matrix N and the bit size of the l_0 parameter.
  Note that when operating locally, its possible not all of these 
  parameters are supported by the local implementation.

  Available:
    50-8    50x50 matrix, 8 bit element chunks
    50-12
    50-16
    50-20
    50-24
    36-8
    43-8
    57-8
    64-8

Options:
  -g               Send the request to a Google Spreadsheet
  -o               Write the request into file [default: query.dat]
  --dbelems <n>    Operate against a database of size <n>
  -v               Be verbose
database.
  EOS
  opt :element, "The element number to request. (Index 1)", :type => :integer
  opt :params, "The parameter set to use", :type => :string
  opt :googlify, "Send to google rather than doing locally", :default => false
  opt :verbose , "Be Verbose", :default => false
  opt :dbelems, "The number of dbelems", :default => 10
  opt :out, "Write the query out to this file", :default => "query.dat"
end

params = case opts[:params]
  when  "50-24"
    {
      N: 50,
      n: 10,
      l: 1200,
      l_0: 24,
      P: 4722366482869645213711
    }
  when  "50-20"
    {
      N: 50,
      n: 10,
      l: 1000,
      l_0: 20,
      P: 1152921504606847009
    }
  when "50-16"
    {
      N: 50,
      n: 10,
      l: 800,
      l_0: 16,
      P: 281474976710677
    }
  when "50-12"
    {
      N: 50,
      n: 10,
      l: 600,
      l_0: 12,
      P: 68719476767
    }
  when "50-8"
    {
      N: 50,
      n: 10,
      l: 400,
      l_0: 8,
      P: 16777259
    }
  when "36-8"
    {
      N: 36,
      n: 10,
      l: 288,
      l_0: 8,
      P: 16777259
    }
  when "43-8"
    {
      N: 43,
      n: 10,
      l: 344,
      l_0: 8,
      P: 16777259
    }
  when "57-8"
    {
      N: 57,
      n: 10,
      l: 456,
      l_0: 8,
      P: 16777259
    }
  when "50-8"
    {
      N: 50,
      n: 10,
      l: 400,
      l_0: 8,
      P: 16777259
    }
  when "64-8"
    {
      N: 64,
      n: 10,
      l: 512,
      P: 16777259,
      l_0: 8
    }
  else
    $stderr.puts "TESTING"
   {
    N: 2,
    n: 2,
    l: 6,
    P: 521
  }
end

params[:n] = opts[:dbelems]

Trollop::die(:element, "must be provided and be between 0 and n") unless
             (opts[:element] and opts[:element] > 0 and opts[:element] <= params[:n])
params[:i_0] = opts[:element]


USER = "pirdbtest2@gmail.com"
PASSWORD = "3467c4cb16788a63bb1cad5b305c6ed08d6a50b0"
KEY = "0Aptc6p77KwxHdGJXSGM0RTBUWXIya0VEQ2VLV2VpSkE"

if opts[:googlify]
  session = GoogleDrive.login USER, PASSWORD
  ss = session.spreadsheet_by_key(KEY)
  ws = ss.worksheet_by_title("Request")
end

timer = Time.now.to_f

instance = PirMatrixState.new(params)
$stderr.puts "Generating query for element #{opts[:element]}"

$stderr.puts "Generating base matrix..."
instance.generateABM()
#$stderr.puts "M: #{instance.main_matrix}"

$stderr.puts "Generating #{params[:n]} random invertible matrices..."
random_invertibles = (1..params[:n]).map do |x|
  p = PirMatrixState.gen_random_invertible params[:N], params[:P]
  $stderr.puts "P#{x}: #{p if opts[:verbose]}"
  p
end

$stderr.puts "Generating #{params[:n]} doubleprime matrices..."
m_doubleprime = instance.generate_M_doubleprime_matrices random_invertibles
m_doubleprime.each_with_index do |m,i|
  $stderr.puts "M#{i}'': #{m}"
end if opts[:verbose]

$stderr.puts "Generating #{params[:n]} hard and soft noise matrices..."
d_i = instance.generate_distortion_matrices 
d_i.each_with_index do |m,i|
  $stderr.puts "D#{i}'': #{m }"
end if opts[:verbose]

delta = instance.delta
$stderr.puts "Generated delta: #{delta if opts[:verbose]}"

$stderr.puts "Generating #{params[:n]} distortion matrices..."
distortion_matrices = d_i.map do |d|
  d.mod_multiply(delta,params[:P])
end
$stderr.puts "D * delta: #{distortion_matrices if opts[:verbose]}" 


$stderr.puts "Generating #{params[:n]} query matrices..."
m_primes = instance.compute_M_prime_matrices m_doubleprime, distortion_matrices
m_primes.each_with_index do |m,i|
  $stderr.puts "M#{i}': #{m}"
end if opts[:verbose]

$stderr.puts "Choosing a permutation"
instance.pick_permutation
$stderr.puts "Permuting"
permuted = m_primes.map do |x|
  instance.do_permute x
end

$stderr.puts "Timer:Client:GenerateQuery:#{Time.now.to_f - timer}"
timer = Time.now.to_f
matrices = ""
File.open(opts[:out], 'w') do |f|
  permuted.each_with_index do |x,i|
    encoded = PirProtocol.encode_matrix(x)

    if opts[:googlify]
      encoded.split("|").each_with_index do |row,j|
        ws[i+1,j+1] = row if opts[:googlify]
        #$stderr.puts("Writing #{row.length} byte row to (#{i+1},#{j+1}): #{row}")
      end
      ws.save
    else
      f.write "#{encoded}\n"
    end
  end
end

$stderr.puts "Timer:Client:SendQuery:#{Time.now.to_f - timer}"
timer = Time.now.to_f

#$stderr.puts matrices

if opts[:googlify]
  ws[60,1] = ""
  ws[61,1] = ""
  ws[62,1] = ""
  ws.save
  ws.reload

  $stderr.puts "Sending to Google"
  ws[61,1] = %Q[Request|A1|#{params[:N]}|#{params[:n]}|#{params[:l]}|#{params[:P]}|#{ opts[:params] ? 2 : 1}]
  ws[62,1] = "Requested"
  ws.save

  ctr = 0
  while ctr < 180
    ws.reload
    status = ws[62,1]

    break if status == "Complete"
    $stderr.puts "Waiting for response [Status: #{status}]"
    Kernel.sleep 10
  end
  if ctr >= 60
    $stderr.puts "Timed out."
    exit
  end
  response = ws[63,1]

  $stderr.puts "Response: #{response}"
else
  Kernel.system("coffee ../server/local.coffee --params #{opts[:params]} --query query.dat")
  response = File.open('answer.dat','r').read()
  #$stderr.print "Enter the name of the file containing the response: "
  #begin
    #fname = STDIN.gets
    #response = File.open(fname.strip(),'r').read()
  #rescue Exception => e
    #$stderr.puts e.message
    #retry
  #end
end

$stderr.puts("Timer:Client:Receipt:#{Time.now.to_f - timer}")
timer = Time.now.to_f

$stderr.puts "Decoding '#{response}'..."
decoded = instance.decode response

$stderr.puts "Decoded Response: '#{decoded.pack("C*")}'"
$stderr.puts "Timer:Client:Decoded:#{Time.now.to_f - timer}"
if opts[:googlify]
  $stderr.puts "Timer:Server:Total:#{(ws[62,2].to_i - ws[61,2].to_i) / 1000.0}"
  $stderr.puts "Timer.Server:IterationAvg:#{(ws[65,2].to_i / params[:n]) / 1000.0}"
  $stderr.puts "Timer:Server:IterationTotal:#{ws[65,2].to_i / 1000.0}"
  times = ws[63,2].to_i / params[:n]
  $stderr.puts "Timer:Server:DatabaseReadAvg:#{times/1000.0}"
  $stderr.puts "Timer:Server:DatabaseReadTotal:#{ws[63,2].to_i / 1000.0}"
  times = ws[64,2].to_i / params[:n]
  $stderr.puts "Timer:Server:QueryReadAvg:#{times/1000.0}"
  $stderr.puts "Timer:Server:QueryReadTotal:#{ws[64,2].to_i / 1000.0}"
end
