#--------------------- Bayes --------------------

require_relative '../genre_classifier.rb'

class BayesianGenreClassifier < GenreClassifier

  require 'classifier'
  require 'madeleine'

  def initialize(stoplist_filename, classes)
    super(stoplist_filename)

    @bc = Classifier::Bayes.new(*classes)
  end

  def train(clss, str)
    str = clean_string(str)
    @bc.train(clss, str)
  end

  def classify(str)
    str = clean_string(str)
    @bc.classify(str)
  end

end




# if ARGV.length != 3
#   warn "USAGE: #$0 GENRE_DIR FREQLIST STOPLIST"
#   exit(1)
# end

# puts "Finding files..."
# files = Dir.glob(File.join(ARGV[0], '*'))
# classes = files.map{|f| File.basename(f)}
# puts "Found #{files.length} files in #{ARGV[0]}"

# puts "Loading stoplist from #{ARGV[2]}..."
# stoplist = File.read(ARGV[2]).lines.map{|s| s.chomp.strip.downcase }

# require 'csv'
# freqs = {}
# CSV.foreach(ARGV[1], headers: true) do |l|
#   freqs[l[0]] = l[1].to_i
# end


#   def strip_str(str, stoplist = [], freqlist = {})
#     words = str.split.map{|w| w.gsub(/(^[^\w]+|[^\w]+$)/, '').downcase }

#     words.delete_if do |w|
#       stoplist.include?(w) || freqlist[w] == 1
#     end

#     return words.join(' ')
#   end


# bc = Classifier::Bayes.new(*classes)

# files.each do |f|

#   clss = File.basename(f)
#   puts "Training #{f} as #{clss}..."


#   # Read and remove stopwords
#   str = strip_str(File.read(f)[0..83630], stoplist)

#   bc.train(clss, str)
# end


# files.each do |f|

#   puts "Testing #{f}..."
#   test_str = File.read(f)
#   offset = rand * (f.length - 1000)
#   puts " = #{bc.classify(strip_str(test_str[offset.to_i .. -1]))}"
# end



