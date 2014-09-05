

class GenreClassifier

  @stoplist = []

  def initialize(stoplist_filename = nil)
    load_stoplist(stoplist_filename) if stoplist_filename
  end

  def train(cls, str)
  end

  # Signal that training is ended
  def finalise
    warn "STUB: GenreClassifier#finalise"
  end

  def classify(str)
    warn "STUB: GenreClassifier#classify"
  end

  def save_state(filename)
    File.open(filename, 'w') do |fout|
      Marshal.dump(self, fout)
    end
  end

  def self.load(filename)
    obj = nil
    File.open(filename, 'r') do |fin|
      obj = Marshal.load(fin)
    end

    obj
  end

  private

  def load_stoplist(filename)
    puts "Loading stoplist from #{filename}..."
    @stoplist = File.read(filename).lines.map{|s| s.chomp.strip.downcase }
  end

  def clean_string(str)
    words = str.split.map{|w| w.gsub(/(^[^\w]+|[^\w]+$)/, '').downcase }

    if @stoplist.length > 0
      words.delete_if do |w|
        @stoplist.include?(w) 
      end
    end

    return words.join(' ')
  end

end


