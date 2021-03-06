
#' K-fold cross-validation to determine optimal tuning parameter
#'
#' Given a corpus, divide into K-folds and do test-train spilts averaged over
#' the folds.
#'
#' Increments tuning parameter, performs K-fold cross-validation on each C giving a profile
#' of predictive power for different C.
#'
#' @return a dataframe containing the mean/standard error of out-of-sample predictions under K-Fold Cross-validation
#' @param corpus The text
#' @param labeling The labeling
#' @param banned The words to drop.
#' @param K Number of folds for K-fold cross-validation
#' @param length.out number of values of C to examine from 0 to max_C.
#' @param max_C upper bound for tuning parameter; if NULL, sets max_C to threshold C 
#' @param verbose Print progress
#' @param ... parameters from the original textreg() function
#' @import tm
#' @export
#' @seealso make.CV.chart
find.CV.C <-function( corpus, labeling, banned, K, length.out, max_C=NULL, verbose=FALSE, ... ) {
	
	## Cut up a sequence into random chunks for CV
	chunk <- function(x,n) split(x, factor(sample(x%%n)))
		
	# ## Converts VCorpus to list of strings
	# convert_list<-function(corpus){
	  # list<-rep(NA,length(corpus));
	  # for (i in 1:length(corpus)){
	    # list[i]<-corpus[[i]];
	  # }
	  # return(list);
	# }


	if (is.null(max_C)) {
      Cs<-find.threshold.C(corpus, labeling, banned, R=0, ... )
      max_C<-Cs[1]
    }
    C=0
    
    # ensure text is a list of strings.
    #texts<-convert_list(corpus)
    #texts = Corpus(VectorSource(texts))
    texts = corpus
    means=numeric(0)
    std_err=numeric(0)
    Cs=numeric(0)

    #Increment C until the threshold level is reached ()
    Cs = seq( 0, max_C, length.out=length.out )
    means = rep( 0, length.out )
    in.means = rep(0, length.out )
    std_err = rep( 0, length.out )

    #Divide corpus into K random chunks.  See chunk function above
    cv.chunks<-chunk(1:length(corpus),K)
     
    for ( i in 1:length(Cs) ) {
      C = Cs[i]

      loss=rep( NA, K )
      in.loss=rep( NA, K )
      foldsize=rep( NA, K )


      for (j in 1:K){
        #Create sample corpus/labels, out of sample corpus/labels
        sample_corpus<-texts[-cv.chunks[[j]]]
        sample_lbl<-labeling[-cv.chunks[[j]]]
        outofsample_corpus<-texts[cv.chunks[[j]]]
        outofsample_lbl<-labeling[cv.chunks[[j]]]

        # train
        rs <- textreg(sample_corpus, sample_lbl, C=C, ... )
		in.loss[j] = calc.loss(rs)[[2]]
		 
        # evaluate
        loss[j] <- calc.loss(rs,outofsample_corpus,outofsample_lbl)[[2]]

        #Create foldsize vector to normalize loss by size of hold-out sample
        foldsize[j] <- length(cv.chunks[[j]])
        #print(j)
      }
      in.means[i] <-  sum(in.loss) / ((K-1)*length(corpus))
      means[i] <- sum(loss)/length(corpus)
      std_err[i] <- sd(loss/foldsize)/sqrt(length(loss))
      if ( verbose ) {
      	print(C)
      }
    }
    df=data.frame(Cs,train.err=in.means,test.err=means,std_err)
    df
}

#' Plot K-fold cross validation curves
#' 
#' Plot the test error with SE bars for the cross validation.  Also calculate the spot that is 1 SE above the minimum.
#' Fits the points with loess lines so few points needed in evaluating the function.  All a bit ad hoc and worthy
#' of improvement.
#' 
#' Not particularly well implemented.
#'
#' @import tm
#' @export
#' @param tbl Table from find.CV.C
#' @param plot TRUE means plot the chart.  False means do not, but return the optimal C
#' @param ... Parameters to the plot function
#' @seealso find.CV.C
make.CV.chart = function( tbl, plot=TRUE, ... ) {

	low = loess(  test.err ~ Cs, tbl, weights=tbl$std_err )
	low
	
	f = function(x,model) {
		predict( model, data.frame(Cs=x) )
	}
	rng = c( min(tbl$Cs), max(tbl$Cs) )
	peak = optimize( f, rng, maximum=FALSE, model=low )
	
	tbl$err.up = tbl$test.err + tbl$std_err
	low.up = loess( err.up ~ Cs, tbl, weights=tbl$std_err )
	cut.line = predict( low.up, peak$minimum )
	f2 = function( x, model, cut) {
			abs( predict( model, data.frame(Cs=x) ) - cut )
	}
	rng2 = c( peak$minimum, max(tbl$Cs) )
	ct = optimize( f2, rng2,
		maximum=FALSE, model=low, cut=cut.line )

	
	if ( plot ) {
		plot( tbl$test.err ~ tbl$Cs, 
			ylim=range(tbl$test.err+tbl$std_err, 
					tbl$test.err-tbl$std_err), type="n", pch=19,
					ylab="C", xlab="train error", main="Estimated Train Error for K-Fold CV", ... )	
		arrows(tbl$Cs,tbl$test.err+tbl$std_err,
	       tbl$Cs, tbl$test.err-tbl$std_err,
	       angle=90, code=3, length=0.05, col="grey")
		#lines( low, col="red" )
		sq = seq( min(tbl$Cs), max(tbl$Cs), length.out=200 )
		pd = predict( low, sq )
		lines( sq, pd, col="red" )
		points( peak$minimum, peak$objective, pch=19, col="red" )		
		abline( h=cut.line, col="blue", lty=2 )
		lines( tbl$test.err ~ tbl$Cs, 
			ylim=range(tbl$test.err+tbl$std_err, 
					tbl$test.err-tbl$std_err), type="b", pch=19 )	
		abline( v=ct$minimum, col="blue", lty=3 )
	}
	invisible( list( minimum=ct$minimum, test.err=predict( low, ct$minimum )  ) )
}


