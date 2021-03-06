% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/BGVAR.R
\docType{data}
\name{eerDataspf}
\alias{eerDataspf}
\alias{W.trade0012.spf}
\title{eerData extended with expectations data}
\format{The data loads two objects \code{eerData}, which is a list object of length \code{N} (i.e, the number of countries) and \code{W.trade0012}, which is an \code{N} times \code{N} weight matrix with rowsums summing up to unity and zero elements on its diagonal. The global variable, oil prices, is included in the US country model as e.g., in Dees et al. (2007). The countries are abbreviated using ISO-2 codes. The weight matrix corresponds to average annual bilateral trade flows (including services) over the period from 2000 to 2012.\code{eerData} contains the country data, for more details, see below:
\describe{
  \item{\code{W.trade0012spf}}{\code{N} times \code{N} weight matrix based on trade flows, rowsums equal unity.}
  \item{\code{eerDataspf}}{ is a list object of length \code{N} containing \itemize{
  \item{\code{y_t+4}}{ four quarter ahead expectation of Real GDP growth.}
  \item{\code{Dp_t+4}}{ four quarter ahead expectation of consumer price inflation.}
  \item{\code{stir_t+4}}{ four quarter ahead expectation of short-term interest rates.}
  \item{\code{y}}{ Real GDP growth.}
  \item{\code{Dp}}{ Consumer price inflation (period-on-period).}
  \item{\code{stir}}{ Short-term interest rate, typically 3-months money market rate.}
  \item{\code{ltir}}{ Long-term interest rates, typically 10-year government bond yields.}
  \item{\code{reer}}{ Real effective exchange rate, deflated by consumer prices.}
  \item{\code{tb}}{ Trade balance (ratio of real exports to real imports).}
  \item{\code{poil}}{ Price of oil, seasonally adjusted, in logarithms.}
  }}
}}
\usage{
eerDataspf
}
\description{
This data set contains 76 quarterly observations by country, spanning the period from 1995Q1 to 2013Q4. The country coverage is 43 countries + the euro area (EA) as a regional aggregate. Additionally, the US country dataset is extended with four quarter ahead expectation data on output, prices and short-term interest rates from the Survey of Professional Forecasters.
}
\keyword{datasets}
