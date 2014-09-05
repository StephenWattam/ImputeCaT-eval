




  class FleschKincaidRanker

    # require 'text-hyphen'
    require 'syllables'

    # In words
    MAX_SENTENCE_LENGTH = 100

    def reading_ease(str)
      
      sentence_count = 0
      syllable_count = 0
      word_count     = 0

      # Split by words
      words_in_this_sentence = 0
      str.split.each do |w|

        # Test sentence ends
        words_in_this_sentence += 1
        if words_in_this_sentence > MAX_SENTENCE_LENGTH || w =~ /[\.!?]$/
          words_in_this_sentence = 0
          sentence_count += 1
        end

        # add syllable count
        syllable_count += count_syllables(w)

        # And inc word count
        word_count += 1
      end
      return nil if word_count == 0
      sentence_count += 1

      # Compute the score
      fkscore = 206.835 - 1.015 * (word_count.to_f / sentence_count.to_f) - 84.6 * (syllable_count.to_f / word_count.to_f)
      # fkscore = 0.39 * (word_count.to_f / sentence_count.to_f) + 11.8 * (syllable_count.to_f / word_count.to_f) - 15.59

      # require 'pry'; pry binding

      return fkscore
    end

    private

    # Count syllables in a word
    def count_syllables(word)
      word_syllable_counts = Syllables.new(word).to_h
      return word_syllable_counts[word_syllable_counts.keys.first].to_i
      # @hyphenator.visualise(word).each_char.to_a.count('-') + 1
    end

  end





