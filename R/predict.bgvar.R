#' @name predict.bgvar
#' @title Compute predictions
#' @description A function that computes predictions based on a object of class \code{bgvar}.
#' @param object an object of class \code{bgvar}.
#' @param ... additional arguments.
#' @param fhorz the forecast horizon.
#' @param save.store If set to \code{TRUE} the full distribution is returned. Default is set to \code{FALSE} in order to save storage.
#' @return Returns an object of class \code{bgvar.predict} with the following elements \itemize{
#' \item{\code{fcast}}{ is a K times fhorz times 5-dimensional array that contains 16\%th, 25\%th, 50\%th, 75\%th and 84\% percentiles of the posterior predictive distribution.}
#' \item{\code{xglobal}}{ is a matrix object of dimension T times N (T # of observations, K # of variables in the system).}
#' \item{\code{fhorz}}{ specified forecast horizon.}
#' \item{\code{lps.stats}}{ is an array object of dimension K times 2 times fhorz and contains the mean and standard deviation of the log-predictive scores for each variable and each forecast horizon.}
#' \item{\code{hold.out}}{ if \code{h} is not set to zero, this contains the hold-out sample.}
#' }
#' @examples 
#' \donttest{
#' set.seed(571)
#' library(BGVAR)
#' data(monthlyData)
#' monthlyData$OC <- NULL
#' OE.weights <- list(EB=EA.weights) # weights have to have the same name as the country in the data
#' model.mn <- bgvar(Data=monthlyData,W=W,plag=1,h=8,saves=100,burns=100,prior="MN",
#'                   OE.weights=OE.weights)
#' fcast <- predict(model.mn, fhorz=8)
#' }
#' @importFrom stats rnorm tsp sd
#' @author Martin Feldkircher, Florian Huber
#' @export
predict.bgvar <- function(object, ..., fhorz=8, save.store=FALSE){
  if(!inherits(object, "bgvar")) {stop("Please provide a `bgvar` object.")}
  saves      <- object$args$thinsaves
  plag       <- object$args$plag
  xglobal    <- object$xglobal
  x          <- xglobal[(plag+1):nrow(xglobal),]
  S_large    <- object$stacked.results$S_large
  A_large    <- object$stacked.results$A_large
  Ginv_large <- object$stacked.results$Ginv_large
  F.eigen    <- object$stacked.results$F.eigen
  varNames   <- colnames(xglobal)
  cN         <- unique(sapply(strsplit(varNames,".",fixed=TRUE),function(x) x[1]))
  vars       <- unique(sapply(strsplit(varNames,".",fixed=TRUE),function(x) x[2]))
  N          <- length(cN)
  Traw       <- nrow(xglobal)
  bigT       <- nrow(x)
  M          <- ncol(xglobal)
  cons       <- 1
  trend      <- ifelse(object$args$trend,1,0)
  
  varndxv <- c(M,cons+trend,plag)
  nkk     <- (plag*M)+cons+trend
  
  Yn <- xglobal
  Xn <- cbind(.mlag(Yn,plag),1)
  Xn <- Xn[(plag+1):Traw,,drop=FALSE]
  Yn <- Yn[(plag+1):Traw,,drop=FALSE]
  if(trend) Xn <- cbind(Xn,seq(1,bigT))
  
  fcst_t <- array(NA,dim=c(saves,M,fhorz))
  
  # start loop here
  pb <- txtProgressBar(min = 0, max = saves, style = 3)
  
  for(irep in 1:saves){
    #Step I: Construct a global VC matrix Omega_t
    Ginv    <- Ginv_large[irep,,]
    Sig_t   <- Ginv%*%(S_large[irep,,])%*%t(Ginv)
    Sig_t   <- as.matrix(Sig_t)
    zt      <- Xn[bigT,]
    z1      <- zt
    Mean00  <- zt
    Sigma00 <- matrix(0,nkk,nkk)
    y2      <- NULL
    
    #gets companion form
    aux   <- .get_companion(A_large[irep,,],varndxv)
    Mm    <- aux$MM
    Jm    <- aux$Jm
    Jsigt <- Jm%*%Sig_t%*%t(Jm)
    # this is the forecast loop
    for (ih in 1:fhorz){
      z1      <- Mm%*%z1
      Sigma00 <- Mm%*%Sigma00%*%t(Mm) + Jsigt
      chol_varyt <- try(t(chol(Sigma00[1:M,1:M])),silent=TRUE)
      if(is(chol_varyt,"try-error")){
        yf <- mvrnorm(1,mu=z1[1:M],Sigma00[1:M,1:M])
      }else{
        yf <- z1[1:M]+chol_varyt%*%rnorm(M,0,1)
      }
      y2 <- cbind(y2,yf)
    }
    
    fcst_t[irep,,] <- y2
    setTxtProgressBar(pb, irep)
  }
  
  imp_posterior<-array(NA,dim=c(M,fhorz,5))
  dimnames(imp_posterior)[[1]] <- varNames
  dimnames(imp_posterior)[[2]] <- 1:fhorz
  dimnames(imp_posterior)[[3]] <- c("low25","low16","median","high75","high84")
  
  imp_posterior[,,"low25"]  <- apply(fcst_t,c(2,3),quantile,0.25,na.rm=TRUE)
  imp_posterior[,,"low16"]  <- apply(fcst_t,c(2,3),quantile,0.16,na.rm=TRUE)
  imp_posterior[,,"median"] <- apply(fcst_t,c(2,3),quantile,0.50,na.rm=TRUE)
  imp_posterior[,,"high75"] <- apply(fcst_t,c(2,3),quantile,0.75,na.rm=TRUE)
  imp_posterior[,,"high84"] <- apply(fcst_t,c(2,3),quantile,0.84,na.rm=TRUE)
  
  h                        <- object$args$h
  if(h>fhorz) h            <- fhorz
  yfull                    <- object$args$yfull
  if(h>0){
    lps.stats                <- array(0,dim=c(M,2,h))
    dimnames(lps.stats)[[1]] <- colnames(xglobal)
    dimnames(lps.stats)[[2]] <- c("mean","sd")
    dimnames(lps.stats)[[3]] <- 1:h
    lps.stats[,"mean",]      <- apply(fcst_t[,,1:h],c(2:3),mean)
    lps.stats[,"sd",]        <- apply(fcst_t[,,1:h],c(2:3),sd)
    hold.out<-yfull[(nrow(yfull)+1-h):nrow(yfull),,drop=FALSE]
  }else{
    lps.stats<-NULL
    hold.out<-NULL
  }
  rownames(xglobal)<-.timelabel(object$args$time)
  
  out <- structure(list(fcast=imp_posterior,
                        xglobal=xglobal,
                        fhorz=fhorz,
                        lps.stats=lps.stats,
                        hold.out=hold.out),
                   class="bgvar.pred")
  if(save.store){
    out$pred_store = fcst_t
  }
  return(out)
}

#' @name cond.pred
#' @title Conditional Forecasts
#' @description Function that computes conditional forecasts for Bayesian Vector Autoregressions.
#' @usage cond.predict(constr, bgvar.obj, pred.obj, constr_sd=NULL)
#' @details Conditional forecasts need a fully identified system. Therefore this function utilizes short-run restrictions via the Cholesky decomposition on the global solution of the variance-covariance matrix of the Bayesian GVAR.
#' @param constr a matrix containing the conditional forecasts of size horizon times K, where horizon corresponds to the forecast horizon specified in \code{pred.obj}, while K is the number of variables in the system. The ordering of the variables have to correspond the ordering of the variables in the system. Rest is just set to NA.
#' @param bgvar.obj an item fitted by \code{bgvar}.
#' @param pred.obj an item fitted by \code{predict}. Note that \code{save.store=TRUE} is required as argument!
#' @param constr_sd a matrix containing the standard deviations around the conditional forecasts. Must have the same size as \code{constr}.
#' @author Maximilian Boeck
#' @examples 
#' \donttest{
#' set.seed(571)
#' library(BGVAR)
#' data(eerData)
#' model.ssvs.eer<-bgvar(Data=eerData,W=W.trade0012,saves=100,burns=100,plag=1,prior="SSVS",
#'                       eigen=TRUE)
#' 
#' # compute predictions
#' fcast <- predict(model.ssvs.eer,fhorz=8,save.store=TRUE)
#' 
#' # set up constraints matrix of dimension fhorz times K
#' constr <- matrix(NA,nrow=fcast$fhorz,ncol=ncol(model.ssvs.eer$xglobal))
#' colnames(constr) <- colnames(model.ssvs.eer$xglobal)
#' constr[1:5,"US.Dp"] <- model.ssvs.eer$xglobal[76,"US.Dp"]
#' 
#' # add uncertainty to conditional forecasts
#' constr_sd <- matrix(NA,nrow=fcast$fhorz,ncol=ncol(model.ssvs.eer$xglobal))
#' colnames(constr_sd) <- colnames(model.ssvs.eer$xglobal)
#' constr_sd[1:5,"US.Dp"] <- 0.001
#' 
#' cond_fcast <- cond.predict(constr, model.ssvs.eer, fcast, constr_sd)
#' plot(cond_fcast, resp="US.Dp", Cut=10)
#' }
#' @references 
#' Jarocinski, M. (2010) \emph{Conditional forecasts and uncertainty about forecasts revisions in vector autoregressions.} Economics Letters, Vol. 108(3), pp. 257-259.
#' 
#' Waggoner, D., F. and T. Zha (1999) \emph{Conditional Forecasts in Dynamic Multivariate Models.} Review of Economics and Statistics, Vol. 81(4), pp. 639-561.
#' @importFrom abind adrop
#' @importFrom stats rnorm
#' @export
cond.predict <- function(constr, bgvar.obj, pred.obj, constr_sd=NULL){
  start.cond <- Sys.time()
  if(!inherits(pred.obj, "bgvar.pred")) {stop("Please provide a `bgvar.predict` object.")}
  if(!inherits(bgvar.obj, "bgvar")) {stop("Please provide a `bgvar` object.")}
  cat("\nStart conditional forecasts of Bayesian Global Vector Autoregression.\n\n")
  #----------------get stuff-------------------------------------------------------#
  plag        <- bgvar.obj$args$plag
  xglobal     <- pred.obj$xglobal
  Traw        <- nrow(xglobal)
  bigK        <- ncol(xglobal)
  bigT        <- Traw-plag
  A_large     <- bgvar.obj$stacked.results$A_large
  F_large     <- bgvar.obj$stacked.results$F_large
  S_large     <- bgvar.obj$stacked.results$S_large
  Ginv_large  <- bgvar.obj$stacked.results$Ginv_large
  F.eigen     <- bgvar.obj$stacked.results$F.eigen
  thinsaves   <- length(F.eigen)
  x           <- xglobal[(plag+1):Traw,,drop=FALSE]
  horizon     <- pred.obj$fhorz
  varNames    <- colnames(xglobal)
  cN          <- unique(sapply(strsplit(varNames,".",fixed=TRUE),function(x)x[1]))
  var         <- unique(sapply(strsplit(varNames,".",fixed=TRUE),function(x)x[2]))
  #---------------------checks------------------------------------------------------#
  if(is.null(pred.obj$pred_store)){
    stop("Please set 'save.store=TRUE' when computing predictions.")
  }
  if(!all(dim(constr)==c(horizon,bigK))){
    stop("Please respecify dimensions of 'constr'.")
  }
  if(!is.null(constr_sd)){
    if(!all(dim(constr_sd)==c(horizon,bigK))){
      stop("Please respecify dimensions of 'constr_sd'.")
    }
    constr_sd[is.na(constr_sd)] <- 0
  }else{
    constr_sd <- matrix(0,horizon,bigK)
  }
  pred_array <- pred.obj$pred_store
  #---------------container---------------------------------------------------------#
  cond_pred <- array(NA, c(thinsaves, bigK, horizon))
  dimnames(cond_pred)[[2]] <- varNames
  #----------do conditional forecasting -------------------------------------------#
  cat("Start computing...\n")
  pb <- txtProgressBar(min = 0, max = thinsaves, style = 3)
  for(irep in 1:thinsaves){
    pred    <- pred_array[irep,,]
    Sigma_u <- Ginv_large[irep,,]%*%S_large[irep,,]%*%t(Ginv_large[irep,,])
    irf     <- .impulsdtrf(B=adrop(F_large[irep,,,,drop=FALSE],drop=1),
                           smat=t(chol(Sigma_u)),nstep=horizon)
    
    temp <- as.vector(constr) + rnorm(bigK*horizon,0,as.vector(constr_sd))
    constr_use <- matrix(temp,horizon,bigK)
    
    v <- sum(!is.na(constr))
    s <- bigK * horizon
    r <- c(rep(0, v))
    R <- matrix(0, v, s)
    pos <- 1
    for(i in 1:horizon) {
      for(j in 1:bigK) {
        if(is.na(constr_use[i, j])) {next}
        r[pos] <- constr_use[i, j] - pred[j, i]
        for(k in 1:i) {
          R[pos, ((k - 1) * bigK + 1):(k * bigK)] <- irf[j,,(i - k + 1)]
        }
        pos <- pos + 1
      }
    }
    
    R_svd <- svd(R, nu=nrow(R), nv=ncol(R))
    U     <- R_svd[["u"]]
    P_inv <- diag(1/R_svd[["d"]])
    V1    <- R_svd[["v"]][,1:v]
    V2    <- R_svd[["v"]][,(v+1):s]
    eta   <- V1 %*% P_inv %*% t(U) %*% r + V2 %*% rnorm(s-v)
    eta   <- matrix(eta, horizon, bigK, byrow=TRUE)
    
    for(h in 1:horizon) {
      temp <- matrix(0, bigK, 1)
      for(k in 1:h) {
        temp <- temp + irf[, , (h - k + 1)] %*% t(eta[k , , drop=FALSE])
      }
      cond_pred[irep,,h] <- pred[,h,drop=FALSE] + temp
    }
    setTxtProgressBar(pb, irep)
  }
  #------------compute posteriors----------------------------------------------#
  imp_posterior<-array(NA,dim=c(bigK,horizon,5))
  dimnames(imp_posterior)[[1]] <- varNames
  dimnames(imp_posterior)[[2]] <- 1:horizon
  dimnames(imp_posterior)[[3]] <- c("low25","low16","median","high75","high84")
  
  imp_posterior[,,"low25"]  <- apply(cond_pred,c(2,3),quantile,0.25,na.rm=TRUE)
  imp_posterior[,,"low16"]  <- apply(cond_pred,c(2,3),quantile,0.16,na.rm=TRUE)
  imp_posterior[,,"median"] <- apply(cond_pred,c(2,3),quantile,0.50,na.rm=TRUE)
  imp_posterior[,,"high75"] <- apply(cond_pred,c(2,3),quantile,0.75,na.rm=TRUE)
  imp_posterior[,,"high84"] <- apply(cond_pred,c(2,3),quantile,0.84,na.rm=TRUE)
  
  #----------------------------------------------------------------------------------#
  out <- structure(list(fcast=imp_posterior,
                        xglobal=xglobal,
                        fhorz=horizon),
                   class="bgvar.pred")
  cat(paste("Size of object:", format(object.size(out),unit="MB")))
  end.cond <- Sys.time()
  diff.cond <- difftime(end.cond,start.cond,units="mins")
  mins.cond <- round(diff.cond,0); secs.cond <- round((diff.cond-floor(diff.cond))*60,0)
  cat(paste("\nNeeded time for computation: ",mins.cond," ",ifelse(mins.cond==1,"min","mins")," ",secs.cond, " ",ifelse(secs.cond==1,"second.","seconds.\n"),sep=""))
  return(out)
}

#' @name plot.bgvar.pred
#' @title Plot predictions of bgvar
#' @description  Plots the predictions of an object of class \code{bgvar.predict}.
#' @param x an object of class \code{bgvar.predict}.
#' @param ... additional arguments.
#' @param resp specify a variable to plot predictions.
#' @param Cut length of series to be plotted before prediction begins.
#' @author Maximilian Boeck, Martin Feldkircher
#' @examples 
#' \donttest{
#' set.seed(571)
#' library(BGVAR)
#' data(monthlyData)
#' monthlyData$OC <- NULL
#' OE.weights <- list(EB=EA.weights) # weights have to have the same name as the country in the data
#' model.mn <- bgvar(Data=monthlyData,W=W,plag=1,saves=100,burns=100,prior="MN",
#'                     OE.weights=OE.weights)
#' fcast <- predict(model.mn)
#' plot(fcast, resp="US.p", Cut=20)
#' }
#' @importFrom graphics abline matplot polygon
#' @importFrom stats rnorm
#' @importFrom utils txtProgressBar setTxtProgressBar
#' @export
plot.bgvar.pred<-function(x, ..., resp=NULL,Cut=40){
  fcast <- x$fcast
  Xdata <- x$xglobal
  hstep <- x$fhorz
  thin<-nrow(Xdata)-hstep
  if(thin>Cut){
    Xdata<-Xdata[(nrow(Xdata)-Cut+1):nrow(Xdata),]
  }
  varNames  <- colnames(Xdata)
  varAll    <- varNames
  cN        <- unique(sapply(strsplit(varNames,".",fixed=TRUE),function(x) x[1]))
  vars      <- unique(sapply(strsplit(varNames,".",fixed=TRUE),function(x) x[2]))
  if(!is.null(resp)){
    resp.p <- strsplit(resp,".",fixed=TRUE)
    resp.c <- sapply(resp.p,function(x) x[1])
    resp.v <- sapply(resp.p,function(x) x[2])
    if(!all(unique(resp.c)%in%cN)){
      stop("Please provide country names corresponding to the ones of the 'bgvar.predict' object.")
    }
    cN       <- cN[cN%in%resp.c]
    varNames <- lapply(cN,function(x)varNames[grepl(x,varNames)])
    if(all(!is.na(resp.v))){
      if(!all(unlist(lapply(resp,function(r)r%in%varAll)))){
        stop("Please provide correct variable names corresponding to the ones in the 'bgvar.predict' object.")
      }
      varNames <- lapply(varNames,function(l)l[l%in%resp])
    }
    max.vars <- unlist(lapply(varNames,length))
  }else{
    varNames <- lapply(cN,function(cc) varAll[grepl(cc,varAll)])
  }
  for(cc in 1:length(cN)){
    rows <- max.vars[cc]/2
    if(rows<1) cols <- 1 else cols <- 2
    if(rows%%1!=0) rows <- ceiling(rows)
    if(rows%%1!=0) rows <- ceiling(rows)
    par(mfrow=c(rows,cols),mar=bgvar.env$mar)
    for(kk in 1:max.vars[cc]){
      idx  <- grep(cN[cc],varAll)
      idx <- idx[varAll[idx]%in%varNames[[cc]]][kk]
      x <- rbind(cbind(NA,Xdata[,idx],NA),fcast[idx,,c("low25","median","high75")])
      y <- rbind(cbind(NA,Xdata[,idx],NA),fcast[idx,,c("low16","median","high84")])
      b <- range(x,y, na.rm=TRUE)
      b1<-b[1];b2<-rev(b)[1]
      matplot(x,type="l",col=c("black","black","black"),xaxt="n",lwd=4,ylab="",main=varAll[idx],yaxt="n",
              cex.main=bgvar.env$plot$cex.main,cex.axis=bgvar.env$plot$cex.axis,
              cex.lab=bgvar.env$plot$cex.lab,lty=c(0,1,0),ylim=c(b1,b2))
      polygon(c(1:nrow(y),rev(1:nrow(y))),c(y[,1],rev(y[,3])),col=bgvar.env$plot$col.75,border=NA)
      polygon(c(1:nrow(x),rev(1:nrow(x))),c(x[,1],rev(x[,3])),col=bgvar.env$plot$col.68,border=NA)
      lines(c(rep(NA,Cut),x[seq(Cut+1,Cut+hstep),2]),col=bgvar.env$plot$col.50,lwd=4)
      
      axisnames <- c(rownames(Xdata),paste("t+",1:hstep,sep=""))
      axisindex <- c(round(seq(1,Cut,length.out=8)),seq(Cut+1,Cut+hstep))
      axis(side=1, at=axisindex, labels=axisnames[axisindex], cex.axis=0.6,tick=FALSE,las=2)
      axis(side=2, cex.axis=0.6)
      abline(v=axisindex,col=bgvar.env$plot$col.tick,lty=bgvar.env$plot$lty.tick)
    }
    if(cc<length(cN)) readline(prompt="Press enter for next country...")
  }
}

#' @name lps.bgvar.pred
#' @title Compute log-predictive scores
#' @description  Computes and prints log-predictive score of an object of class \code{bgvar.predict}.
#' @param object an object of class \code{bgvar.predict}.
#' @param ... additional arguments.
#' @return Returns a matrix of dimension h times K, whereas h is the forecasting horizon and K is the number of variables in the system.
#' @examples 
#' \donttest{
#' set.seed(571)
#' library(BGVAR)
#' data(monthlyData)
#' monthlyData$OC <- NULL
#' OE.weights <- list(EB=EA.weights) # weights have to have the same name as the country in the data
#' model.mn <- bgvar(Data=monthlyData,W=W,plag=1,h=8,saves=100,burns=100,prior="MN",
#'                   OE.weights=OE.weights)
#' fcast <- predict(model.mn, fhorz=8)
#' lps   <- lps(fcast)
#' }
#' @author Maximilian Boeck, Martin Feldkircher
#' @importFrom knitr kable
#' @importFrom stats dnorm
#' @export
lps <- function(object, ...){
  hold.out <- object$hold.out
  h        <- nrow(hold.out)
  K        <- ncol(hold.out)
  if(is.null(hold.out)){
    stop("Please submit a forecast object that includes a hold out sample for evaluation (set h>0 when estimating the model with bgvar)!")
  }
  lps.stats  <- object$lps.stats
  lps.scores <- matrix(NA,h,K)
  for(i in 1:K){
    lps.scores[,i]<-dnorm(hold.out[,i],mean=lps.stats[i,"mean",],sd=lps.stats[i,"sd",],log=TRUE)
  }
  colnames(lps.scores)<-dimnames(lps.stats)[[1]]
  cN   <- unique(sapply(strsplit(colnames(lps.scores),".",fixed=TRUE),function(x)x[1]))
  vars <- unique(sapply(strsplit(colnames(lps.scores),".",fixed=TRUE),function(x)x[2]))
  cntry <- round(sapply(cN,function(x)mean(lps.scores[grepl(x,colnames(lps.scores))])),2)
  K     <- ceiling(length(cntry)/10)
  mat.c <- matrix(NA,nrow=2*K,ncol=10)
  for(i in 1:K){
    if(i<K) {
      mat.c[(i-1)*2+1,] <- names(cntry)[((i-1)*10+1):(i*10)]
      mat.c[(i-1)*2+2,] <- as.numeric(cntry)[((i-1)*10+1):(i*10)]
    }else{
      mat.c[(i-1)*2+1,1:(length(cntry)-(i-1)*10)] <- names(cntry)[((i-1)*10+1):length(cntry)]
      mat.c[(i-1)*2+2,1:(length(cntry)-(i-1)*10)] <- as.numeric(cntry)[((i-1)*10+1):length(cntry)]
    }
  }
  mat.c[is.na(mat.c)] <- ""
  colnames(mat.c) <- rep("",10)
  vars  <- round(sapply(vars,function(x)mean(lps.scores[grepl(x,colnames(lps.scores))])),2)
  K     <- ceiling(length(vars)/10)
  mat.v <- matrix(NA,nrow=2*K,ncol=10)
  for(i in 1:K){
    if(i<K) {
      mat.v[(i-1)*2+1,] <- names(vars)[((i-1)*10+1):(i*10)]
      mat.v[(i-1)*2+2,] <- as.numeric(vars)[((i-1)*10+1):(i*10)]
    }else{
      mat.v[(i-1)*2+1,1:(length(vars)-(i-1)*10)] <- names(vars)[((i-1)*10+1):length(vars)]
      mat.v[(i-1)*2+2,1:(length(vars)-(i-1)*10)] <- as.numeric(vars)[((i-1)*10+1):length(vars)]
    }
  }
  mat.v[is.na(mat.v)] <- ""
  colnames(mat.v) <- rep("",10)
  K     <- ceiling(h/10)
  mat.h <- matrix(NA,nrow=2*K,ncol=10)
  for(i in 1:K){
    if(i<K) {
      mat.h[(i-1)*2+1,] <- paste("h=",seq(((i-1)*10+1),(i*10),by=1),sep="")
      mat.h[(i-1)*2+2,] <- round(rowSums(lps.scores[((i-1)*10+1):(i*10),]),2)
    }else{
      mat.h[(i-1)*2+1,1:(h-(i-1)*10)] <- paste("h=",seq(((i-1)*10+1),h,by=1),sep="")
      mat.h[(i-1)*2+2,1:(h-(i-1)*10)] <- round(rowSums(lps.scores[((i-1)*10+1):h,]),2)
    }
  }
  mat.h[is.na(mat.h)] <- ""
  colnames(mat.h) <- rep("",10)
  cat("---------------------------------------------------------------------------")
  cat("\n")
  cat("Log-predictive scores per country")
  print(kable(mat.c))
  cat("\n")
  cat("---------------------------------------------------------------------------")
  cat("\n")
  cat("Log-predictive scores per variable")
  print(kable(mat.v))
  cat("\n")
  cat("---------------------------------------------------------------------------")
  cat("\n")
  cat("Log-predictive scores per horizon")
  print(kable(mat.h))
  cat("\n")
  cat("---------------------------------------------------------------------------")
  return(lps.scores)
}

#' @name rmse.bgvar.predict
#' @title Compute root mean squared errors
#' @description  Computes and prints root mean squared errors (RMSEs) of an object of class \code{bgvar.predict}.
#' @param object an object of class \code{bgvar.predict}.
#' @param ... additional arguments.
#' @return Returns a matrix of dimension h times K, whereas h is the forecasting horizon and K is the number of variables in the system.
#' @examples
#' \donttest{
#' set.seed(571)
#' library(BGVAR)
#' data(monthlyData)
#' monthlyData$OC <- NULL
#' OE.weights <- list(EB=EA.weights) # weights have to have the same name as the country in the data
#' model.mn <- bgvar(Data=monthlyData,W=W,plag=1,h=8,saves=100,burns=100,prior="MN",
#'                   OE.weights=OE.weights)
#' fcast <- predict(model.mn, fhorz=8)
#' rmse  <- rmse(fcast)
#' }
#' @author Maximilian Boeck, Martin Feldkircher
#' @importFrom knitr kable
#' @importFrom stats dnorm
#' @export
rmse <- function(object, ...){
  hold.out <- object$hold.out
  h        <- nrow(hold.out)
  K        <- ncol(hold.out)
  if(is.null(hold.out)){
    stop("Please submit a forecast object that includes a hold out sample for evaluation (set h>0 in fcast)!")
  }
  lps.stats   <- object$lps.stats
  rmse.scores <- matrix(NA,h,K)
  for(i in 1:K){
    rmse.scores[,i]<-sqrt((hold.out[,i]-lps.stats[i,"mean",])^2)
  }
  colnames(rmse.scores)<-dimnames(lps.stats)[[1]]
  cN   <- unique(sapply(strsplit(colnames(rmse.scores),".",fixed=TRUE),function(x)x[1]))
  vars <- unique(sapply(strsplit(colnames(rmse.scores),".",fixed=TRUE),function(x)x[2]))
  cntry <- round(sapply(cN,function(x)mean(rmse.scores[,grepl(x,colnames(rmse.scores))])),2)
  K     <- ceiling(length(cntry)/10)
  mat.c <- matrix(NA,nrow=2*K,ncol=10)
  for(i in 1:K){
    if(i<K) {
      mat.c[(i-1)*2+1,] <- names(cntry)[((i-1)*10+1):(i*10)]
      mat.c[(i-1)*2+2,] <- as.numeric(cntry)[((i-1)*10+1):(i*10)]
    }else{
      mat.c[(i-1)*2+1,1:(length(cntry)-(i-1)*10)] <- names(cntry)[((i-1)*10+1):length(cntry)]
      mat.c[(i-1)*2+2,1:(length(cntry)-(i-1)*10)] <- as.numeric(cntry)[((i-1)*10+1):length(cntry)]
    }
  }
  mat.c[is.na(mat.c)] <- ""
  colnames(mat.c) <- rep("",10)
  vars  <- round(sapply(vars,function(x)mean(rmse.scores[grepl(x,colnames(rmse.scores))])),2)
  K     <- ceiling(length(vars)/10)
  mat.v <- matrix(NA,nrow=2*K,ncol=10)
  for(i in 1:K){
    if(i<K) {
      mat.v[(i-1)*2+1,] <- names(vars)[((i-1)*10+1):(i*10)]
      mat.v[(i-1)*2+2,] <- as.numeric(vars)[((i-1)*10+1):(i*10)]
    }else{
      mat.v[(i-1)*2+1,1:(length(vars)-(i-1)*10)] <- names(vars)[((i-1)*10+1):length(vars)]
      mat.v[(i-1)*2+2,1:(length(vars)-(i-1)*10)] <- as.numeric(vars)[((i-1)*10+1):length(vars)]
    }
  }
  mat.v[is.na(mat.v)] <- ""
  colnames(mat.v) <- rep("",10)
  K     <- ceiling(h/10)
  mat.h <- matrix(NA,nrow=2*K,ncol=10)
  for(i in 1:K){
    if(i<K) {
      mat.h[(i-1)*2+1,] <- paste("h=",seq(((i-1)*10+1),(i*10),by=1),sep="")
      mat.h[(i-1)*2+2,] <- round(rowSums(rmse.scores[((i-1)*10+1):(i*10),]),2)
    }else{
      mat.h[(i-1)*2+1,1:(h-(i-1)*10)] <- paste("h=",seq(((i-1)*10+1),h,by=1),sep="")
      mat.h[(i-1)*2+2,1:(h-(i-1)*10)] <- round(rowSums(rmse.scores[((i-1)*10+1):h,]),2)
    }
  }
  mat.h[is.na(mat.h)] <- ""
  colnames(mat.h) <- rep("",10)
  cat("---------------------------------------------------------------------------")
  cat("\n")
  cat("Root mean squared error per country")
  print(kable(mat.c))
  cat("\n")
  cat("---------------------------------------------------------------------------")
  cat("\n")
  cat("Root mean squared error per variable")
  print(kable(mat.v))
  cat("\n")
  cat("---------------------------------------------------------------------------")
  cat("\n")
  cat("Root mean squared error per horizon")
  print(kable(mat.h))
  cat("\n")
  cat("---------------------------------------------------------------------------")
  return(rmse.scores)
}
