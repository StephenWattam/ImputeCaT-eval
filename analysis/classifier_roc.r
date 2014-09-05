#!/usr/bin/env Rscript

# Load ROCR
library(ROCR);

source('./lib/graphs.r');

# Load genre classifications from various classifiers
bncgen.bayes = read.csv('../data/genclass_performance_bayesian.csv', header=T);
bncgen.uni   = read.csv('../data/genclass_performance_unigram.csv',  header=T);
bncgen.ngram = read.csv('../data/genclass_performance_ngram.csv',    header=T);

# build the performance thing using ROCR
bayes.pred = prediction(bncgen.bayes$blnpredicted, bncgen.bayes$blntrue);
uni.pred   = prediction(bncgen.uni$blnpredicted, bncgen.uni$blntrue);
ngram.pred = prediction(bncgen.ngram$blnpredicted, bncgen.ngram$blntrue);

# Measure performance
bayes.perf = performance(bayes.pred, 'tpr', 'fpr');
uni.perf   = performance(uni.pred,   'tpr', 'fpr');
ngram.perf = performance(ngram.pred, 'tpr', 'fpr');

# Render


grout('bayes_genre_roc');
plot(bayes.perf,
     main="Bayesian (n=2000, train=80%)"
     );
groff();
