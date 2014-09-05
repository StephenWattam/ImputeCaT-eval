require_relative '../genre_classifier.rb'

class UnigramGenreClassifier < GenreClassifier

  require 'csv'
  require 'fast-stemmer'

  attr_reader :stoplist
  attr_accessor :threshold

  def initialize(keyword_lists = {}, stoplist = [], threshold = 5)
    @threshold  = threshold
    @stoplist   = {}
    stoplist.each { |sw| @stoplist[sw] = true }

    if keyword_lists.is_a?(String)
      load_memdump(keyword_lists)
    else
      load_keyword_lists(keyword_lists)
    end
  end

  # Save the state to a file
  def save(filename)
    hash = { threshold: @threshold,
             lists:     @lists,
             stoplist:  @stoplist
    }

    File.open(filename, 'w') do |io|
      Marshal.dump(hash, io)
    end
  end

  # Return a list of possible categories
  def categories
    @lists.keys
  end

  # Classify a string
  def classify(str)
    # require 'pry'; pry binding;
    str = clean_string(str)

    # build frequency list
    str_freqs = {}
    str.each {|w| str_freqs[w] ||= 0; str_freqs[w] += 1 }
    str_freqs = rank(str_freqs)


    scores = {}
    @lists.each do |category, wordlist|
      scores[category] = score_list(str, str_freqs, wordlist)
    end

    # Find max
    category = scores.sort_by{|c, s| s }
    # category.each do |c, score|
    #   puts " > #{c} \t #{score}"
    # end

    return category.last[0]
  end

  # Opens, reads, parses and classifies file
  def classify_file(filename)
    fail "File does not exist: #{filename}" unless File.exist?(filename)

    # Read string and pass it to classify
    return classify(File.read(filename))
  end

  # Compute class distance (0-1)
  def class_distance(cla, clb)
    fail "Class #{cla} does not exist." unless @lists[cla]
    fail "Class #{clb} does not exist." unless @lists[clb]

    corr = score_list(@lists[cla].keys, @lists[cla], @lists[clb])
    return 1.0 - corr.abs
  end

  private

  # Clean a string of punctuation and
  # stem if necessary
  def clean_string(str)
    str   = str.join(' ') if str.is_a?(Array)
    words = str.to_s.split#(/[^\w'-]+/)

    words.map! do |word|
      word.downcase!

      # Strip leading/following non-dictionary chars
      word.gsub!(/(^[^\w]+|[^\w]+$)/, '')
      word.gsub!(/'s$/, '')

      # word = word.stem if @stem
      @stoplist[word] ? nil : word
    end
   
    words.delete(nil)
    words.delete('')

    return words
  end

  # Return a mean significance for all
  # of the items in the list
  def score_list(str, str_freqs, list)

    # Frequencies in order
    freqs       = []
    list_freqs  = []

    str.each do |word|
      if list[word] && list[word] > @threshold # Don't penalise things missing from the lexicon
        freqs << (str_freqs[word] || 0)
        list_freqs << (list[word] || 0)
      end

    end

    return pearson(freqs, list_freqs)
  end

  # Load keyword lists from a type=>filename hash
  def load_keyword_lists(list_hash)
    @lists = {}

    list_hash.each do |category, filename_or_hash|

      cat_list = {}
      puts " Loading keyword list #{category}"

      CSV.foreach(filename_or_hash, headers: true) do |line|

        word = line[0]
        freq = line[1].to_f

        next if @stoplist[word]
        cat_list[word] = freq
      end

      # Compute order from frequency
      cat_list = rank(cat_list)

      @lists[category] = cat_list
    end
  end

  # Load a Marshalled dump
  def load_memdump(filename)
    hash        = Marshal.load(File.read(filename))
    @lists      = hash[:lists]
    @stoplist   = hash[:stoplist]
    @threshold  = hash[:threshold]
  end

  # Compute PMCC naively
  def pearson(x,y)
    n = [x.length, y.length].min
    return 0 if n == 0

    sumx, sumy, sumxSq, sumySq = 0, 0, 0, 0
    n.times do |i|
      sumx += x[i]
      sumy += y[i]

      sumxSq += x[i]**2
      sumySq += y[i]**2
    end

    pSum = 0
    x.each_with_index{|this_x,i| pSum += this_x * y[i] }

    # Calculate Pearson score
    num = pSum - ( sumx * sumy / n )
    den = ((sumxSq-(sumx**2)/n)*(sumySq-(sumy**2)/n))**0.5
    return 0 if den==0
    
    r = num/den
    return r
  end

  ## # Turn a key -> Num hash into a Key=>rank hash
  #def rank(hash)
  #  order = hash.sort_by{|_, v| v}.map{ |k, _| k }.reverse
  #  order.each_with_index { |k, i| hash[k] = i }
  #  return hash 
  #end

  # Turn a key -> Num hash into a Key=>rank hash,
  # breaking ties as we go
  #
  # This algorithm is big, but it's also clever. ish.
  def rank(hash)
    order = hash.sort_by{|_, v| v}.reverse

    # append this canary so we don't have to check the end
    # special case
    order << [nil, -1]

    keys_for_this_rank = []
    current_rank_value = hash[order[0]]
    current_rank       = 0
    order.each do |k, v| 

      keys_for_this_rank << k

      if v != current_rank_value 
        # puts "-> #{keys_for_this_rank.length} words with #{current_rank_value} occurrences at rank #{current_rank}, #{k} = #{v}"

        # Write keys for this rank
        keys_for_this_rank.each do |k|
          hash[k] = current_rank + (keys_for_this_rank.length + 1).to_f / 2.0
        end
        
        current_rank      += keys_for_this_rank.length
        keys_for_this_rank = []
        current_rank_value = v
      end

    end
    return hash 
  end



end



