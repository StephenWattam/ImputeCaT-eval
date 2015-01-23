
#!/usr/bin/env Rscript

# Read data
llbnc <- read.csv("../data/2.loglik_resampled_bnc.100k.csv", header=T);
bnc <- read.csv("../data/BNC_WORLD_INDEX.csv", header=T);

llbnc <- llbnc[seq(1, length(llbnc$n), 10), ]

#  Load graphing lib
source('./lib/graphs.r');


curve.CIs = function(llbnc, column){

    # Compute upper, lower CIs for loglik
    cis = data.frame(a=0, b=0, c=0, d=0, e=0, f=0, g=0)
    colnames(cis) <- c('n', 'mean', 'sd', 'ci95.low', 'ci95.high', 'ci90.low', 'ci90.high')

    len = length(unique(llbnc$n))
    count = 0
    for (i in unique(llbnc$n)) {

        count = count + 1
        points_at_x = llbnc[which(llbnc$n == i), column]

        m = mean(points_at_x)
        s = sd(points_at_x)

        ci.95h = m + 1.96*(s)
        ci.95l = m - 1.96*(s)
        ci.90h = m + 1.645*(s)
        ci.90l = m - 1.645*(s)

        cis[count,] = c(i, m, s, ci.95l, ci.95h, ci.90l, ci.90h)

        print(paste(count, "/", len, " (", ((count / len)*100), "%) (col: ", column, ") = ", m, " < ", ci.95h))
    }

    return(cis)
}


# Compute CIs
ci.Mode         = curve.CIs(llbnc, 3)
ci.GENRE        = curve.CIs(llbnc, 4)
ci.Word.bin     = curve.CIs(llbnc, 5)
ci.Aud.Level    = curve.CIs(llbnc, 6)

# Write to disk for simplicity
write.csv(file = '../data/ll.ci.Mode.csv', x=ci.Mode)
write.csv(file = '../data/ll.ci.GENRE.csv', x=ci.GENRE)
write.csv(file = '../data/ll.ci.Word_bin', x=ci.Word.bin)
write.csv(file = '../data/ll.ci.Aud_Level.csv', x=ci.Aud.Level)


# Count number of bins below

plot.CI.curve <- function(var, field) {

    plot(var$ci95.high ~ var$n, t='l', col=8, xaxt="n",
         main=paste(field, ""),
         xlab="Out / in corpus size",
         ylab="Log-likelihood",
         ylim=c(min(min(var$ci95.low), 0), max(var$ci95.high)))


    axis(1, at=var$n[ seq(1, max(var$n), 4055)/10 ], labels=round(var$n[ seq(1, max(var$n), 4055)/10 ]/4055, digits=2), tick=T)

    # axis(1, at=var$n, labels=round(var$n[seq(/4055, digits=2), tick=F)

    lines(var$ci95.low ~ var$n, col=8)
    lines(var$mean ~ var$n, col=2)

    # Lines at sane points
    abline(a=6.68, b=0, lty=4)
    abline(v=4055, lty=3)

    # Legend in top-right
    legend(max(var$n) * 0.7, max(var$ci95.high) * 0.96,
           col=c(2, 8, 1, 1),
           c("Mean", "90% CI", "ll = 6.68", "n = 4055"),
           lty=c(1, 1, 4, 3),
           bty='o'
    )
}


grout("4wayCI95", w=10, h=8);
par(mfrow=c(2,2))

plot.CI.curve(ci.Mode, 'Mode')
plot.CI.curve(ci.GENRE, 'Genre')
plot.CI.curve(ci.Word.bin, 'Word Count')
plot.CI.curve(ci.Aud.Level, 'Audience Level')


groff();



