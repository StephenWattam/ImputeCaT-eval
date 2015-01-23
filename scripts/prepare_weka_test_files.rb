#!/usr/bin/env ruby
# 
# This script reads a BNC directory of class/text files
# and composes a single ARFF file containing all of the
# text as extracted by the ARFFFactory
#

require_relative './lib/genre_classifiers/weka_bayes_multinom.rb'
require 'securerandom'


input_dir   = ARGV[0]
output_dile = STDOUT

# Print usage if no input dir exists
unless input_dir
  warn "USAGE: #$0 INPUT_DIR"
  exit(1)
end




output = ARFFFactory.new(SecureRandom.hex.to_s, 
                         ARFFFactory::CLASS_ENUM + ['W_misc', 'S_conv'])


Dir.glob(File.join(input_dir, '*')) do |dir|
  next unless File.directory?(dir)
  cls = File.basename(dir)
  next unless output.classes.include?(cls)

  # Read all files in this class and add them
  Dir.glob(File.join(dir, '*')) do |filename|
    $stderr.print "#{cls}: #{File.basename(filename)}..."
    output.add_document(cls, File.read(filename))
    $stderr.print "Done.\n"
  end
end


$stderr.print "Converting output..."
puts output.output
$stderr.print "Done.\n"
