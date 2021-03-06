% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/fevd.decomp.R
\name{gfevd.decomp}
\alias{gfevd.decomp}
\title{Generalized Forecast Error Variance Decomposition}
\usage{
gfevd.decomp(obj, nhor=24, running=TRUE, multithread=FALSE)
}
\arguments{
\item{obj}{an object of class \code{bgvar}.}

\item{nhor}{the forecast horizon.}

\item{running}{Default is set to \code{TRUE} and implies that only a running mean over the posterior draws is calculated. A full analysis including posterior bounds is likely to cause memory issues.}

\item{multithread}{If set to \code{TRUE} parallel computing using the packages \code{\link{foreach}} and \code{\link{doParallel}}. Number of cores is set to maximum number of cores in the computer. This option is recommended when working with sign restrictions to speed up computations. Default is set to \code{FALSE} and thus no parallelization.
#' @return Returns a list with two elements \itemize{
\item{\code{GFEVD}}{ a three or four-dimensional array, with the first dimension referring to the K time series that are decomposed into contributions of K time series (second dimension) for \code{nhor} forecast horizons. In case \code{running=TRUE} only the posterior mean else also its 16\% and 84\% credible intervals is contained in the fourth dimension.}
\item{\code{xglobal}}{ used data of the model.}
}}
}
\description{
This function calculates a complete generalized forecast error variance decomposition (GFEVDs) based on generalized impulse response functions akin to Lanne-Nyberg (2016). The Lanne-Nyberg (2016) corrected GFEVD sum up to unity.
}
\examples{
\donttest{
set.seed(571)
library(BGVAR)
data(eerData)
model.ssvs.eer<-bgvar(Data=eerData,W=W.trade0012,saves=100,burns=100,plag=1,
                      prior="SSVS",thin=1,eigen=TRUE)
                      
# Calculates running mean GFEVDs for all variables in the system 
GFEVD<-gfevd.decomp(model.ssvs.eer,nhor=24,running=TRUE)
}
}
\references{
Lanne, M. and H. Nyberg (2016) \emph{Generalized Forecast Error Variance Decomposition for Linear and Nonlinear Multivariate Models.} Oxford Bulletin of Economics and Statistics, Vol. 78(4), pp. 595-603.
}
\seealso{
\code{\link{bgvar}}.
}
\author{
Martin Feldkircher
}
