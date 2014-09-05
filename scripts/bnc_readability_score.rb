#!/usr/bin/env rbx


EXTENSION='.xml'
BNC_DIR = '/home/wattams/corpora/BNC/BNC XML Edition'
#/home/wattams/corpora/BNC/BNCworld'
FILES = Dir.glob("#{BNC_DIR}/*/*/*#{EXTENSION}")

METADATA = '../data/BNC_WORLD_INDEX.csv'



#Readability ranks: 
# -  low: 664  items, mean = 62.95293871760397, sd = 14.424512199650604, var = 208.06655219786907
# -  med: 1651 items, mean = 55.44412267430666, sd = 12.76812426643693,  var = 163.02499728317557
# - high: 820  items, mean = 47.70965585209567, sd = 12.445956325065204, var = 154.90182884543054
# -  ---: 914  items, mean = 82.02288020623476, sd = 20.6424573733852,   var = 426.111046412025
AUDIENCE_LEVEL_FLEISCH_SCORES = {
  'low'  =>  62 + 14 * 0.5,
  'med'  =>  55,
  'high' =>  47 - 12 * 0.5
}

warn "If you want to use the output, redirect STDOUT only to a file:"
warn " #$0 > ../data/BNC_readabilities.csv\n\n"


require_relative './lib/flesch_kincaid'

class AudienceLevel

  # Initialise the audience level heuristic using a 
  #
  # cat => Fleisch-Kincaid reading score hash
  #
  # ** Ensure that the categories are given in-order!
  def initialize(categories, readability_scorer)
    @categories = categories

    @scorer = readability_scorer 
  end

  # value
  def classify(text)
    text = text
    score = @scorer.reading_ease(text)

    return 1 if score.nil?

    # Compute distance to each ideal
    cat_scores = {}
    @categories.each do |cat, ideal_score|
      distance = (ideal_score - score).to_f.abs
      cat_scores[cat] = distance
    end
    level = cat_scores.sort_by{|_, y| y}.first.first

    warn "[audlvl] Score for #{text.split.length} words is #{score} = #{level}"

    return level
  end

end







# Load index
require 'csv'
require 'descriptive_statistics'

warn "Loading metadata..."
audience_level = {}
CSV.foreach(METADATA, headers: true) do |line|
  audience_level[line.field('File ID')] = line.field('Aud Level')
end



require 'nokogiri'
require_relative './lib/readability'
require 'csv'


if ARGV.length < 1
  warn "USAGE: #$0 score_type"
  warn "Score types: \n  #{Readability::SUPPORTED_TYPES.join("\n  ")}"
  exit(1)
end



count = 0
fkr = Readability.new(ARGV[0])
classifier = AudienceLevel.new(AUDIENCE_LEVEL_FLEISCH_SCORES, fkr)
ranks_for_audience_level = {}
errors = {}

CSV(STDOUT) do |cout|

  cout << %w{file readability aud_level classified correct}

  FILES.each do |f|


    basename = File.basename(f, EXTENSION)
    doc = Nokogiri::XML(File.read(f))


    warn "Processing file #{basename}  (#{count+=1} / #{FILES.length})"

    aud_level = audience_level[basename]
    unless aud_level
      warn "Genre not found for text: #{basename}"
      next
    end


    str = doc.xpath('//wtext').text # Try written first
    str = doc.xpath('//stext').text if str.length == 0  # then spoken
    
    
    # Compute readability
    readability = fkr.reading_ease(str).to_f

    classified_aud_level = classifier.classify(str)
    
    errors[aud_level] ||= 0
    errors[aud_level] += 1 if classified_aud_level != aud_level

    warn " #{aud_level} / #{classified_aud_level} = #{readability}"
    cout << [basename, readability, aud_level, classified_aud_level, 
             (classified_aud_level == aud_level ? 1 : 0)]

    ranks_for_audience_level[aud_level] ||= []
    ranks_for_audience_level[aud_level] << readability

  end
end

warn "Readability ranks: "
ranks_for_audience_level.each do |rank, list|
  warn " - #{rank}: #{list.length} items, mean = #{list.mean}, sd = #{list.standard_deviation}, var = #{list.variance}"
end

warn "Classifier error: "
errors.each do |rank, error_count|
  count = (ranks_for_audience_level[rank] || []).length
  warn " - #{rank}: #{error_count} / #{count} = (#{(error_count.to_f / count.to_f) * 100.0}%"
 
end



# ------------






