#!/usr/bin/env Rscript

# Read data
bnc <- read.csv("../data/BNC_WORLD_INDEX.csv", header=T);



#  Load graphing lib
source('./lib/graphs.r');


stdev = 13.16
fl_density   = density( bnc$flesch_readability, bw=stdev, na.rm=T);
fl_density_2 = density( bnc$flesch_readability, bw=stdev/2, na.rm=T);
fl_density_3 = density( bnc$flesch_readability, bw=stdev/3, na.rm=T);
fl_density_4 = density( bnc$flesch_readability, bw=stdev/4, na.rm=T);





grout("flesch_reading_ease_bnc");

plot(fl_density_4, lty=4, col=4, 
     main="Flesch Reading Ease in the BNC",
     xlab="Flesch Reading Ease",
     ylab="Density"
     );
# lines(fl_density_3, lty=3, col=3);
lines(fl_density_2, lty=1, col=1, lwd=2);
lines(fl_density, lty=2, col=2);

# vertical lines
abline(v=47, col=8);
abline(v=55, col=8);
abline(v=63, col=8);




legend(-13, 0.025,
       c('3.29', '6.58', '13.16'),
       lty=c(4, 1, 2),
       col=c(4, 1, 2),
       lwd=c(1,2,1),
       title="Bandwidth"
       );

legend(-13, 0.018,
       c('Group means'),
       lty=c(1),
       col=c(8)
       );


groff();
