


class Readability

  require 'tempfile'

  SUPPORTED_TYPES = %w{flesch_kincaid_reading_ease flesch_kincaid_grade_level gunning_fog_score coleman_liau_index smog_index automated_readability_index}
  BINARY_LOCATION = File.join(File.dirname(__FILE__), 'readability', 'score.php')


  def initialize(type = SUPPORTED_TYPES.first)
    raise "Invalid type" unless SUPPORTED_TYPES.include?(type)
    @type = type
  end


  def reading_ease(string)

    # Write to temp file
    file = Tempfile.new('readability')
    file.write(string)
    file.close

    # Run the thing
    score = `php #{BINARY_LOCATION} #{@type} '#{file.path}'`

    return score.to_f
  rescue StandardError => e
    warn "*** Readability error: #{e} (returning nil)"
    return nil
  end



end



