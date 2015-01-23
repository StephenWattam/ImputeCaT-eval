#!/usr/bin/env ruby

#
# Evaluation script for testing
# the resampler.
#
# Reads a distribution from a file produced
# by `cpr` in ImputeCaT, then continually resamples
# it, testing each dimension's conformance to the
# input distribution
#

# How often to print the progress during import.
# Prime numbers make the output look fancier.
UI_UPDATE_INTERVAL = 521



ic_dir     = ARGV.shift
cpr_file   = ARGV.shift
prof_name  = ARGV.shift
# n          = ARGV.shift.to_f
max        = (ARGV.shift || 1000).to_i
iterations = (ARGV.shift || 1).to_i

unless ic_dir && cpr_file && prof_name && ARGV.empty? && iterations
  warn "Resamples a corpus file, testing for"
  warn "convergeance using log likelihood"
  warn ""
  warn "USAGE: $0 IMPUTECAT_DIR CPR_FILE PROFILE_NAME N MAX [ITER]"
  warn ""
  warn " IMPUTECAT_DIR : / of ImputeCaT repository"
  warn " CPR_FILE: Corpus description as output by CPR"
  warn " PROFILE_NAME: The name of a corpus profile from ImputeCaT/profiles"
  # warn " N: The Log likelihood value to report"
  warn " MAX: How many times to sample a document on each iteration"
  warn " ITER: How many times to iterate each run"
  warn ""
  exit(1)
end

require 'csv'
require File.join(ic_dir, 'lib/impute')

# Directory to find profile files in.
warn "Loading profile..."
old_pwd = Dir.pwd
Dir.chdir(ic_dir)
PROFILE = eval(File.read(File.join(ic_dir, 'profiles', prof_name)))
Dir.chdir(old_pwd)


# Edit profile to force use of discrete distributions.
warn "Forcing use of discrete distributions for all fields."
PROFILE[:fields].keys.each do |name|
  warn " - #{name}"
  PROFILE[:fields][name] = Impute::DiscreteDistribution.new()
end



# --------------------------------
# Load corpus from disk
warn "Loading corpus from #{cpr_file}..."
corpus = Impute::Corpus.read(cpr_file)


# --------------------------------
warn "Building sampler for corpus #{corpus}..."

# FIXME: some way of selecting the other samplers
# sampler = Impute::Sample::MarginalSampler.new(corpus)
# sampler = Impute::Sample::RandomConditionalSampler.new(corpus, 1, 10)

warn "Using full conditional sampling with Z = #{PROFILE[:resampling_params][:z]}, sd = #{PROFILE[:resampling_params][:sd]}"
sampler = Impute::Sample::FullConditionalSampler.new(corpus, PROFILE[:resampling_params][:sd].to_f * PROFILE[:resampling_params][:z].to_f, true)




# -----------------------------------
# Create output corpus
PROFILE[:fields].each do |name, dist_type|
  warn "  - #{name} of type #{dist_type.to_s}"
end

# -----------------------------------
warn "Plotting convergeance over #{max}, repeating #{iterations} times."
count = 0
CSV(STDOUT) do |cout|

  cout << ['n', 'iter'] + PROFILE[:fields].keys

  iterations.times do |iteration|

    warn "iteration #{iteration} / #{iterations}"

    # Create output corpus
    warn "Creating (virtual) output corpus..."
    output = Impute::Corpus.new(Hash[PROFILE[:fields].map{|dim, dist| [dim, dist.dup]}])
    warn "Corpus created using #{PROFILE[:fields].length} dimensions of metadata:"

    max.times do

      doc = nil
      while(doc == nil)
        doc = sampler.get
      end
      count += 1

      # warn "[#{count}] #{doc}"

      output.add(doc)
      # warn "output: #{output.size}"


      ll = corpus.compare_to(output)
      # print " #{output.size}\t #{ll.values.map { |x| x.round(2) }.join("\t")}\r   "
      cout << [output.size, iteration] + ll.values
      # ll.each do |dim, ll|
      #   warn " - #{dim} #{ll.round(3)}"
      # end

    end
  end
end
print "\n"

# require 'pry'
# pry binding;
