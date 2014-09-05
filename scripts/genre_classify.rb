#!/usr/bin/env ruby



require_relative './lib/genre_classifiers/bayesian_classifier.rb'
require_relative './lib/genre_classifiers/unigram_classifier.rb'
require_relative './lib/genre_classifiers/persistent_ngram_classifier.rb'

require 'csv'

CLASSIFIERS = {
  bayesian: BayesianGenreClassifier,
  unigram:  UnigramGenreClassifier,
  ngram:    NGramClassifier,
}

NGRAM_N    = [1,2]
NGRAM_STEM = false 

# Resources for training.  Basically BNC genres in various forms.
STOPLIST_FILE     = File.join(File.dirname(__FILE__), './lib/classifier_data/English.txt')  # one-word-per-line
RAW_GENRE_STR_DIR = File.join(File.dirname(__FILE__), './lib/classifier_data/bnc_genres')   # raw strings
GENRE_FREQ_DIR    = File.join(File.dirname(__FILE__), './lib/classifier_data/genre_freqs')  # CSV
GENRE_KEYW_DIR    = File.join(File.dirname(__FILE__), './lib/classifier_data/genre_keywords') # CSV

# Training threshold
TRAINING_THRESHOLD = 0.8  # Train on n*TRAINING_THRESHOLD, test on n*(1-TRAINING_THRESHOLD)
TEST_SIZE          = 2000  # Test on this many words randomly chosen from the test chunk
TEST_REPEAT        = 5     # Repeat the tests on n subsamples of the test set

if ARGV.length < 3
  warn "USAGE: #$0 train|test classifier_name FILE [> CSV]"
  exit(1)
end

# Filename to load
filename = ARGV[2]

# Load strings from the genre files
classes = {}
word_counts = {}
Dir.glob(File.join(RAW_GENRE_STR_DIR, '*')) do |f|
  cls = File.basename(f)
  $stderr.print "\r Reading #{cls}..."
  classes[cls] = File.read(f)
  word_counts[cls] = classes[cls].to_s.split.length
  $stderr.print "#{word_counts[cls]} words       "
end
$stderr.print " Done\n"

# Summarise the word counts
warn "Min word count: #{word_counts.values.min}, max = #{word_counts.values.max}"


# Train or test on request
if ARGV[0].downcase == 'train'
  warn "Training on #{TRAINING_THRESHOLD * 100}% of input data in #{classes.length} classes."

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
         else
           warn "Invalid classifier type: #{ARGV[1]}"
           exit(1)
         end


  warn "Training classifier..."
  count = 0
  classes.each do |cls, str|
    count += 1

    # Compute training/test set
    train_str = str[0..str.length * TRAINING_THRESHOLD]
    warn " #{count}/#{classes.length}: #{cls} with #{(word_counts[cls] * TRAINING_THRESHOLD).round} words..."
    clfr.train(cls, train_str)
  end

  # The ngram classifier needs 'finalising'
  clfr.finalise

  $stderr.print "Saving to disk..."
  clfr.save_state(filename)
  $stderr.print "Done (#{filename})\n"

else
  warn "Testing on #{(1-TRAINING_THRESHOLD)*100}% of input data in #{classes.length} classes."

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
        test_str = str[str.length * TRAINING_THRESHOLD .. -1]
        words = test_str.split
        if words.length > TEST_SIZE
          base = (rand * (words.length - TEST_SIZE)).to_i
          words = words[base .. base + TEST_SIZE - 1]
        end
        $stderr.print "\r [#{rpt + 1}/#{TEST_REPEAT}] Testing #{cls} on #{words.length} words..."
        test_str = words.join(' ')

        # Classify TODO
        predicted = clfr.classify(test_str).to_s
        predicted = predicted.gsub(/[^\w]/, '_')

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



