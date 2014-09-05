




grout = function(filename, h=6, w=8){
    pdf(file=paste('../figures/', filename, '.pdf', sep=''), height=h, width=w)
}

groff = function(){
    dev.off();
}





