
class NGramClassifier < GenreClassifier

  require 'fast-stemmer'
  require 'fileutils'
  require 'leveldb'

  attr_reader :stem, :categories

  def initialize(data_dir, n = [1,2], stoplist = [], stem = true)
    @data_dir = data_dir
  
    # Init DB.  These may already exist
    @all_freqs = LevelDB::DB.new(fn('all.f'))
    @cat_freqs = {}

    # Read data from meta if it exists
    @meta = LevelDB::DB.new(fn('meta'))
    if(@meta['meta'])
      load_meta
      load_existing_categories(Marshal.load(@meta['categories']) || [])
    else
      # construct a new object from scratch.
      @stem     = stem
      @stoplist = {}  # empty stoplist stops us from stopping the stoplist loaading...
      clean_string(stoplist).uniq.each { |sw| @stoplist[sw] = true }
      @n        = n.is_a?(Array) ? n : [n]
      @n.sort!
    end
  end

  # Override of GenreClassifier.load(filename)
  def self.load(filename)
    NGramClassifier.new(filename)
  end

  # List categories
  def categories
    @cat_freqs.keys
  end

  def classify(str, threshold = 0)
    unless @all_ranks && @cat_ranks
      warn "Rankings do not yet exist.  Generating now..."
      rank
    end

    # parse string into words
    words    = clean_string(str)
    str_rank = rank_hash(ngram_hash(words))

    best, corr = correlate_rank_lists(words, str_rank, threshold)
    return best
  end

  # Train a category with a string
  def train(category, string)
    category = clean_catname(category)
    words    = clean_string(string)
    
    # Wipe out rankings as they are now old
    # TODO: Close DBs
    @all_ranks = nil
    @cat_ranks = nil

    # Train for each n
    train_ngram(category, words)

    # Save metadata including list of categories
    save_meta
  end

  # Compute rankings from training data.
  def finalise 
    @all_ranks ||= LevelDB::DB.new(fn('all.r'))
    erase_leveldb(@all_ranks)
    rank_leveldb(@all_freqs, @all_ranks)

    @cat_ranks ||= {}
    @cat_freqs.each do |c, f|
      if(@cat_ranks[c])
        erase_leveldb(@cat_ranks[c])
      else
        @cat_ranks[c] = LevelDB::DB.new(fn("#{c}.r.cat"))
      end

      rank_leveldb(f, @cat_ranks[c])
    end
  end

  def close
    save_meta
    @meta.close
    @all_freqs.close
    @cat_freqs.each {|c, ldb| ldb.close}
    (@cat_ranks || {}).each {|c, ldb| ldb.close}
    @all_ranks ? @all_ranks.close : nil
  end

  # Override of GenreClassifier#save_state
  def save_state(filename)
    warn "Ignoring filename in save_state in NGramClassifier"
    close
  end

  private

  # Compute correlation for a given word list
  def correlate_rank_lists(words, rank_a, threshold)
    lists = {}
    @cat_ranks.each { |c, _| lists[c] = {:a => [], :b => []} }

    # Loop through words adding ngrams to the freq lists
    ngram = [nil] * @n.max
    count = 0
    words.each_with_index do |w, i|
      
      # Compute 'rolling ngrams' in a left-aligned way,
      # but don't bother if we haven't filled the buffer yet.
      @n.each do |n|
        # compute ngram string
        start = ngram.length - n 
        ng = ngram[start..-1].join(' ')

        # Add word rank
        ra = rank_a[ng].to_i

        # Add rank for each category
        @cat_ranks.each do |c, r|
          rb = r[ng].to_i

          if ra > threshold && rb > threshold
            lists[c][:a] << ra
            lists[c][:b] << rb
          end
        end

      end

      # Update circular buffer
      ngram.shift
      ngram << w

      $stderr.print "\r (#{(i.to_f / words.length * 100).round(2)}%)  #{i} / #{words.length}" if i % 1000 == 0 
    end


    scores = {}
    lists.each do |cat, list|
      scores[cat] = pearson(list[:a], list[:b])
    end

    # require 'pry'; pry binding;

    return scores.sort_by{|c, corr| corr }.last
  end
  

  # Clean a category name
  def clean_catname(category)
    category.to_s.gsub(/[^\w]/, '_')
  end

  # Clean a string of punctuation and
  # stem if necessary
  def clean_string(str)
    str   = str.join(' ') if str.is_a?(Array)
    words = str.to_s.split

    words.map! do |word|
      word.downcase!

      # Strip leading/following non-dictionary chars
      word.gsub!(/(^[^\w]+|[^\w]+$)/, '')
      word.gsub!(/'s$/, '')

      word = word.stem if @stem
      @stoplist[word] ? nil : word
    end
   
    words.delete(nil)
    words.delete('')

    return words
  end

  # Turn an array into a frequency hash of conformant n-grams
  def ngram_hash(words)
    # Loop through words adding ngrams to the freq lists
    ngram = [nil] * @n.max

    freq_hash = {}
    words.each do |w|
      
      # Compute 'rolling ngrams' in a left-aligned way,
      # but don't bother if we haven't filled the buffer yet.
      @n.each do |n|
        start = ngram.length - n
        ng = ngram[start .. -1].join(' ')

        freq_hash[ng] ||= 0
        freq_hash[ng]  += 1
      end

      # Update circular buffer
      ngram.shift
      ngram << w
    end

    return freq_hash
  end

  # Train for a given N
  def train_ngram(category, words)
    # puts "Generating ngrams for #{@n} for category #{category} with #{words.length} words..."
    @cat_freqs[category] = LevelDB::DB.new(fn("#{category}.f.cat")) unless @cat_freqs[category]

    # Loop through words adding ngrams to the freq lists
    ngram = [nil] * @n.max

    words.each_with_index do |w, i|
      
      # Compute 'rolling ngrams' in a left-aligned way,
      # but don't bother if we haven't filled the buffer yet.
      @n.each do |n|
        start = ngram.length - n
        add_ngram(category, ngram[start .. -1]) unless ngram[start].nil?
      end

      $stderr.print "\r train #{category}: (#{(i.to_f / words.length * 100).round(2)}%)  #{i} / #{words.length}" if i % 1000 == 0 

      # Update circular buffer
      ngram.shift
      ngram << w
    end
  end

  # Add a single ngram to the list
  def add_ngram(category, ng)
      # Add to frequency tables
      ng = ng.join(' ')

      f = @cat_freqs[category][ng]
      @cat_freqs[category][ng] = (f.to_i + 1).to_s

      f = @all_freqs[ng]
      @all_freqs[ng] = (f.to_i + 1).to_s
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

    prods = []; x.each_with_index{|this_x,i| prods << this_x*y[i]}
    pSum  = prods.inject(0){|r,i| r + i}

    # Calculate Pearson score
    num = pSum-(sumx*sumy/n)
    den = ((sumxSq-(sumx**2)/n)*(sumySq-(sumy**2)/n))**0.5
    return 0 if den==0
    
    r = num/den
    return r
  end

  # Rank a hash
  def rank_hash(hash)
    order = hash.keys.sort_by{|k| hash[k].to_i }.reverse
    order.each_with_index { |k, i| hash[k] = i }
    return hash 
  end

  def rank_leveldb(source, destination)
    order = source.keys.sort_by{|k| source[k].to_i }.reverse
    order.each_with_index { |k, i| destination[k] = i.to_s }
  end

  def erase_leveldb(ldb)
    # puts "Erasing #{ldb}"
    ldb.keys.each do |k|
      ldb.delete(k)
    end
    # puts "-"
  end

  # Filename within the data directory
  def fn(filename)
    File.join(@data_dir, filename)
  end

  # Load a bunch of levelDB instances from disk
  def load_existing_categories(categories)
    warn "Loading #{categories.length} categories from DB..."
    cat_ranks = {}

    categories.each do |c|
      # puts "Loading category DB #{c}..."
      @cat_freqs[c] = LevelDB::DB.new(fn("#{c}.f.cat"))
      cat_ranks[c] = LevelDB::DB.new(fn("#{c}.r.cat"))
    end

    # Load ranks if they look promising
    if cat_ranks.length == @cat_freqs.length
      # puts "Using ranks from disk..."
      @cat_ranks = cat_ranks
      @all_ranks = LevelDB::DB.new(fn('all.r'))
    end
  end
    

  def load_meta
    @stem       = Marshal.load(@meta['stem'])
    @stoplist   = Marshal.load(@meta['stoplist'])
    @n          = Marshal.load(@meta['n'])

    warn "Loaded classifier using n=#{@n} and #{@stoplist.length} stoplist items."
  end

  def save_meta
    # Save meta
    @meta['stem']         = Marshal.dump(@stem)
    @meta['stoplist']     = Marshal.dump(@stoplist)
    @meta['n']            = Marshal.dump(@n)
    @meta['categories']   = Marshal.dump(categories)
    @meta['meta']         = 'yes'
  end


end


