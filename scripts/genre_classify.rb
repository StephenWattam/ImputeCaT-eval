#!/usr/bin/env ruby



require_relative './lib/genre_classifiers/bayesian_classifier.rb'
require_relative './lib/genre_classifiers/unigram_classifier.rb'
require_relative './lib/genre_classifiers/persistent_ngram_classifier.rb'
require_relative './lib/genre_classifiers/pos_trigram.rb'
require_relative './lib/genre_classifiers/weka_bayes_multinom.rb'

require 'csv'

CLASSIFIERS = {
  bayesian: BayesianGenreClassifier,
  unigram:  UnigramGenreClassifier,
  ngram:    NGramClassifier,
  pos:      POSTrigramGenreClassifier,
  weka:     WEKABayesianMultinomial,
}
CLASSIFIERS_THAT_NEED_SHUFFLED_INPUT = %w{unigram}

NGRAM_N    = [1,2]
NGRAM_STEM = false 

# Resources for training.  Basically BNC genres in various forms.
STOPLIST_FILE     = File.join(File.dirname(__FILE__), './lib/classifier_data/English.txt')  # one-word-per-line
RAW_GENRE_STR_DIR = File.join(File.dirname(__FILE__), './lib/classifier_data/bnc_genres')   # raw strings
RAW_GENRE_STR_DIR_SHUFFLED = File.join(File.dirname(__FILE__), './lib/classifier_data/bnc_genres_shuffled')   # raw strings
GENRE_FREQ_DIR    = File.join(File.dirname(__FILE__), './lib/classifier_data/genre_freqs')  # CSV
GENRE_KEYW_DIR    = File.join(File.dirname(__FILE__), './lib/classifier_data/genre_keywords') # CSV

# Training threshold
TEST_SIZE          = 5000   # Test on this many words randomly chosen from the test chunk
TEST_REPEAT        = 5     # Repeat the tests on n subsamples of the test set
TRAIN_MAX_WORDS    = 100000 # Don't use more than this number of words to train.  Used to homogenise class size
TRAIN_MIN_WORDS    = 1000   # Don't use fewer than this number of words.

if ARGV.length < 3
  warn "USAGE: #$0 train|test classifier_name FILE [> CSV]"
  exit(1)
end

# Filename to load
filename = ARGV[2]

# Load strings from the genre files, shuffled if necessary
classes, word_counts = {}, {}
raw_genre_string_files = Dir.glob(File.join(RAW_GENRE_STR_DIR, '*'))
if CLASSIFIERS_THAT_NEED_SHUFFLED_INPUT.include?($ARGV[1].downcase)
  $stderr.print " Shuffling -- this will break the ngram classifiers!"
  raw_genre_string_files = Dir.glob(File.join(RAW_GENRE_STR_DIR_SHUFFLED, '*'))
end

#  Load data into memory from the files
raw_genre_string_files.each_with_index do |f, i|
  cls = File.basename(f)
  $stderr.print "\r [read #{i}/#{raw_genre_string_files.length}] #{cls}..."
  classes[cls]      = File.read(f)
  word_counts[cls]  = classes[cls].to_s.split.length

  $stderr.print "#{word_counts[cls]} words\n"
end
$stderr.print " Done\n"

# Summarise the word counts
warn "Min word count: #{word_counts.values.min}, max = #{word_counts.values.max}"


# Train or test on request
if ARGV[0].downcase == 'train'
  warn "Training on (length - #{TEST_REPEAT * TEST_SIZE}) words of input data in #{classes.length} classes."

  # Construct the classifier requested by the user
  warn "Constructing classifier of type #{ARGV[1]}..."
  clfr = case(ARGV[1].downcase)
         when 'bayesian'
           BayesianGenreClassifier.new(STOPLIST_FILE, classes.keys)
         when 'unigram'
           freq_lists = {}
           Dir.glob(File.join(GENRE_FREQ_DIR, '*')) do |fn|
             freq_lists[File.basename(fn, '.wrd.fql.csv')] = fn
           end

           stoplist = File.read(STOPLIST_FILE).lines.map {|str| str.chomp.strip.downcase }

           UnigramGenreClassifier.new( freq_lists, stoplist )
          when 'ngram'
            stoplist = File.read(STOPLIST_FILE).lines.map {|str| str.chomp.strip.downcase }
            
            NGramClassifier.new(filename, NGRAM_N, stoplist, NGRAM_STEM)
          when 'pos'
            stoplist = File.read(STOPLIST_FILE).lines.map {|str| str.chomp.strip.downcase }
            POSTrigramGenreClassifier.new(stoplist)
          when 'weka'
            WEKABayesianMultinomial.new
         else
           warn "Invalid classifier type: #{ARGV[1]}"
           exit(1)
         end


  warn "Training classifier..."
  count = 0
  classes.each do |cls, str|
    count += 1

    # Compute training/test set
    words = str.split

    # Select word count to train with
    training_word_count = [words.length - TEST_SIZE * TEST_REPEAT, TRAIN_MAX_WORDS].min 
    training_word_count = [training_word_count, TRAIN_MIN_WORDS].max

    # Turn into a string
    train_str = words[0..training_word_count].join(' ')
    warn " [train #{count}/#{classes.length}] #{cls}: #{words.length} words..."
    clfr.train(cls, train_str)
  end

  # The ngram classifier needs 'finalising'
  $stderr.print "Finalising..."
  clfr.finalise
  $stderr.print "Done\n"

  $stderr.print "Saving to disk..."
  clfr.save_state(filename)
  $stderr.print "Done (#{filename})\n"

else
  warn "Testing on #{TEST_SIZE * TEST_REPEAT} words of input data in #{classes.length} classes."

  # Load state from disk.
  $stderr.print "Loading classifier from #{filename}..."
  cls = CLASSIFIERS[ARGV[1].downcase.to_sym]
  clfr = cls.load(filename)
  $stderr.print "Done\n"

  # Summary counts
  count, tp = 0, 0
    
  # Start CSV output
  CSV(STDOUT) do |cout|

    # Header line
    cout << %w{classifier repeat file true predicted blntrue blnpredicted}

    # For each file
    classes.each do |cls, str|
      cls = cls.gsub(/[^\w]/, '_')

      TEST_REPEAT.times do |rpt|
        count += 1
        # Compute a random N-word sample from the final 100*(1-TRAINING_THRESHOLD)% of the file.
        # test_str = str[str.length * TRAINING_THRESHOLD .. -1]
        words = str.split
        words = words[words.length - TEST_SIZE * TEST_REPEAT .. -1]
        if words.length > TEST_SIZE
          base = (rand * (words.length - TEST_SIZE)).to_i
          words = words[base .. base + TEST_SIZE - 1]
        end
        $stderr.print "\r [test #{rpt + 1}/#{TEST_REPEAT}] #{cls}: #{words.length} words..."
        test_str = words.join(' ')

        # Classify TODO
        predicted = clfr.classify(test_str).to_s
        predicted = predicted.gsub(/[^\w]/, '_')

        # Print the predicted class
        $stderr.print "#{predicted}\n"

        tp += 1 if predicted == cls

        # Write to CSV
        cout << [clfr.class.to_s, rpt, cls, 
                 cls, predicted,
                 1, (cls == predicted) ? 1 : 0]

        # Now write an 'expected false' record for all other classes,
        # in order to force the classifier to appear as binary for R
        classes.keys.each do |cls2|
          cls2 = cls2.gsub(/[^\w]/, '_')
          if cls2 != cls
            cout << [clfr.class.to_s, rpt, cls,
                     cls2, predicted,
                     0, (cls2 == predicted) ? 1 : 0]
          end
        end

      end
      
      $stderr.print "Done.\n"
    end
  end


  warn "Accuracy: #{tp.to_i} / #{count.to_i} (#{(tp.to_f / count * 100.0).round(2)}%)"

end



