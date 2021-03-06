library(shiny)
library(tidyverse)
library(forecast)
library(not)
library(rvest)


wbs.sdll.cpt <- function(x, sigma = stats::mad(diff(x)/sqrt(2)), universal = TRUE, M = NULL, th.const = NULL, th.const.min.mult = 0.3, lambda = 0.9) {

	

	n <- length(x)

    if (n <= 1) {

        no.of.cpt <- 0

        cpt <- integer(0)

    }

    else {

		if (sigma == 0) stop("Noise level estimated at zero; therefore no change-points to estimate.")

		if (universal) {

        	u <- universal.M.th.v3(n, lambda)

        	th.const <- u$th.const

        	M <- u$M

    	}

    	else if (is.null(M) || is.null(th.const)) stop("If universal is FALSE, then M and th.const must be specified.")

    	th.const.min <- th.const * th.const.min.mult

    	th <- th.const * sqrt(2 * log(n)) * sigma

    	th.min <- th.const.min * sqrt(2 * log(n)) * sigma



 		rc <- t(wbs.K.int(x, M))

 		if (max(abs(rc[,4])) < th) {

    	    no.of.cpt <- 0

        	cpt <- integer(0)



 		}

		else {

			indices <- which(abs(rc[,4]) > th.min)

			if (length(indices) == 1) {

				cpt <- rc[indices, 3]

				no.of.cpt <- 1

			}

			else {

				rc.sel <- rc[indices,,drop=F]

				ord <- order(abs(rc.sel[,4]), decreasing=T)

				z <- abs(rc.sel[ord,4])

				z.l <- length(z)

				dif <- -diff(log(z))

				dif.ord <- order(dif, decreasing=T)

				j <- 1

				while ((j < z.l) & (z[dif.ord[j]+1] > th)) j <- j+1

				if (j < z.l) no.of.cpt <- dif.ord[j] else no.of.cpt <- z.l

				cpt <- sort((rc.sel[ord,3])[1:no.of.cpt])			

			}

		} 

    }

    est <- mean.from.cpt(x, cpt)

	list(est=est, no.of.cpt=no.of.cpt, cpt=cpt)

}





wbs.sdll.cpt.rep <- function(x, sigma = stats::mad(diff(x)/sqrt(2)), universal = TRUE, M = NULL, th.const = NULL, th.const.min.mult = 0.3, lambda = 0.9, repeats = 9) {



	res <- vector("list", repeats)

	

	cpt.combined <- integer(0)

	

	nos.of.cpts <- rep(0, repeats)

	

	for (i in 1:repeats) {

		

		res[[i]] <- wbs.sdll.cpt(x, sigma, universal, M, th.const, th.const.min.mult, lambda)

		cpt.combined <- c(cpt.combined, res[[i]]$cpt)

		nos.of.cpts[i] <- res[[i]]$no.of.cpt				

		

	}



	med.no.of.cpt <- median(nos.of.cpts)

	

	med.index <- which.min(abs(nos.of.cpts - med.no.of.cpt))

	

	med.run <- res[[med.index]]

	

	list(med.run = med.run, cpt.combined = sort(cpt.combined))



}





universal.M.th.v3 <- function(n, lambda = 0.9) {

		

	mat.90 <- matrix(0, 24, 3)

	mat.90[,1] <- c(10, 50, 100, 150, 200, 300, 400, 500, 600, 700, 800, 900, 1000, 1500, 2000, 2500, 3000, 4000, 5000, 6000, 7000, 8000, 9000, 10000)

	mat.90[,2] <- c(1.420, 1.310, 1.280, 1.270, 1.250, 1.220, 1.205, 1.205, 1.200, 1.200, 1.200, 1.185, 1.185, 1.170, 1.170, 1.160, 1.150, 1.150, 1.150, 1.150, 1.145, 1.145, 1.135, 1.135)

	mat.90[,3] <- rep(100, 24)

	

	mat.95 <- matrix(0, 24, 3)

	mat.95[,1] <- c(10, 50, 100, 150, 200, 300, 400, 500, 600, 700, 800, 900, 1000, 1500, 2000, 2500, 3000, 4000, 5000, 6000, 7000, 8000, 9000, 10000)

	mat.95[,2] <- c(1.550, 1.370, 1.340, 1.320, 1.300, 1.290, 1.265, 1.265, 1.247, 1.247, 1.247, 1.225, 1.225, 1.220, 1.210, 1.190, 1.190, 1.190, 1.190, 1.190, 1.190, 1.180, 1.170, 1.170)

	mat.95[,3] <- rep(100, 24)



	if (lambda == 0.9) A <- mat.90 else A <- mat.95



	d <- dim(A)

	if (n < A[1,1]) {

		th <- A[1,2]

		M <- A[1,3]

	}

	else if (n > A[d[1],1]) {

		th <- A[d[1],2]

		M <- A[d[1],3]

	}

	else {

		ind <- order(abs(n - A[,1]))[1:2]

		s <- min(ind)

		e <- max(ind)

		th <- A[s,2] * (A[e,1] - n)/(A[e,1] - A[s,1]) + A[e,2] * (n - A[s,1])/(A[e,1] - A[s,1])

		M <- A[s,3] * (A[e,1] - n)/(A[e,1] - A[s,1]) + A[e,3] * (n - A[s,1])/(A[e,1] - A[s,1])

	}



	list(th.const=th, M=M)

}





wbs.K.int <- function(x, M) {

	

	n <- length(x)

	if (n == 1) return(matrix(NA, 4, 0))

	else {

		cpt <- t(random.cusums(x, M)$max.val)

		return(cbind(cpt, wbs.K.int(x[1:cpt[3]], M), wbs.K.int(x[(cpt[3]+1):n], M) + c(rep(cpt[3], 3), 0)            ))

	}

	

}





mean.from.cpt <- function(x, cpt) {



	n <- length(x)

	len.cpt <- length(cpt)

	if (len.cpt) cpt <- sort(cpt)

	beg <- endd <- rep(0, len.cpt+1)

	beg[1] <- 1

	endd[len.cpt+1] <- n

	if (len.cpt) {

		beg[2:(len.cpt+1)] <- cpt+1

		endd[1:len.cpt] <- cpt

	}

	means <- rep(0, len.cpt+1)

	for (i in 1:(len.cpt+1)) means[i] <- mean(x[beg[i]:endd[i]])

	rep(means, endd-beg+1)

}





random.cusums <- function(x, M) {



	y <- c(0, cumsum(x))



	n <- length(x)

	

	M <- min(M, (n-1)*n/2)

		

	res <- matrix(0, M, 4)

	

	if (n==2) ind <- matrix(c(1, 2), 2, 1)

	else if (M == (n-1)*n/2) {

		ind <- matrix(0, 2, M)

		ind[1,] <- rep(1:(n-1), (n-1):1)

		ind[2,] <- 2:(M+1) - rep(cumsum(c(0, (n-2):1)), (n-1):1)

	}

	else {

		ind <- ind2 <- matrix(floor(runif(2*M) * (n-1)), nrow=2)

		ind2[1,] <- apply(ind, 2, min)

		ind2[2,] <- apply(ind, 2, max)

		ind <- ind2 + c(1, 2)

	}



	res[,1:2] <- t(ind)

	res[,3:4] <- t(apply(ind, 2, max.cusum, y))



	max.ind <- which.max(abs(res[,4]))



	max.val <- res[max.ind,,drop=F]



	list(res=res, max.val=max.val, M.eff=M)



}





max.cusum <- function(ind, y) {

	

		z <- y[(ind[1]+1):(ind[2]+1)] - y[ind[1]]

		m <- ind[2]-ind[1]+1

		ip <- sqrt(((m-1):1) / m / (1:(m-1))) * z[1:(m-1)] - sqrt((1:(m-1)) / m / ((m-1):1)) * (z[m] - z[1:(m-1)])

		ip.max <- which.max(abs(ip))

		

		c(ip.max + ind[1] - 1, ip[ip.max])



}





clipped <- function(x, minn, maxx) {
	
	pmin(pmax(x, minn), maxx)
		
}

read_data_wiki <- function() {
	
	cv.page <- "https://en.wikipedia.org/wiki/2020_coronavirus_pandemic_in_the_United_Kingdom"

	i <- 1
	
	repeat {
		
		xp <- paste('//*[@id="mw-content-text"]/div/table[', as.character(i), ']', sep="")
		read_html(cv.page) %>% html_node(xpath=xp) %>% html_table(fill=TRUE) -> dd
		if (dim(dd)[2] >= 19) break
		i <- i+1
		
	}
	
	gsub(",", "", dd[[13]]) -> cases_str
	n <- length(cases_str)
	cases_int <- as.numeric(cases_str[2:(n-2)])

	gsub(",", "", dd[[18]]) -> tested_str
	tested_int <- c(rep(0, 6), diff(as.numeric(tested_str[7:(n-2)])))

	tested_actual <- tested_int[7:(n-3)]
	cases_actual <- cases_int[7:(n-3)]

	gsub(",", "", dd[[15]]) -> deaths_str
	deaths_actual <- as.numeric(deaths_str[15:(n-2)])
	
	deaths_actual[which(is.na(deaths_actual))] <- 0
	tested_actual <- tested_int[7:(n-3)]
	cases_actual <- cases_int[7:(n-3)]
	
	list(tested_actual=tested_actual, cases_actual=cases_actual, deaths_actual=deaths_actual)
	
}


read_data_wiki_secure <- function() {
	
		tryCatch(read_data_wiki(), error=function(c) {list(tested_actual=0, cases_actual=0, deaths_actual=0)})
	
}



read_data_emma <- function() {
	
	f <- read_csv("https://raw.githubusercontent.com/emmadoughty/Daily_COVID-19/master/Data/COVID19_by_day.csv", col_types = cols())
	cases_int <- f %>% pull(2)
	n <- length(cases_int)
	cases_actual <- cases_int[35:n]
	tested_int <- f %>% pull(4)
	tested_actual <- tested_int[35:n]
	deaths_int <- f %>% pull(6)
	deaths_actual <- deaths_int[42:n]

	list(tested_actual=tested_actual, cases_actual=cases_actual, deaths_actual=deaths_actual)
	
}

read_data_emma_secure <- function() {
	
	tryCatch(read_data_emma(), error=function(c) {list(tested_actual=0, cases_actual=0, deaths_actual=0)})
	
}



read_data_covid <- function() {
	
	d_emma <- read_data_emma_secure()
	d_wiki <- read_data_wiki_secure()
		
	if (length(d_emma$deaths_actual) > length(d_wiki$deaths_actual))
		deaths_actual <- d_emma$deaths_actual
	else deaths_actual <- d_wiki$deaths_actual	

	if (length(d_emma$cases_actual) > length(d_wiki$cases_actual))
		cases_actual <- d_emma$cases_actual
	else cases_actual <- d_wiki$cases_actual	

	if (length(d_emma$tested_actual) > length(d_wiki$tested_actual))
		tested_actual <- d_emma$tested_actual
	else tested_actual <- d_wiki$tested_actual	
	
	
	list(tested_actual=tested_actual, cases_actual=cases_actual, deaths_actual=deaths_actual)

}





ans <- function(x) {
	
	2 * sqrt(x + 3/8)
	
}

inv_ans <- function(y) {
	
	(y/2)^2 - 1/8
	
}



fcast_deaths <- function() {
	
	d <- read_data_covid()
	
	d <- d$deaths_actual

	n <- length(d)

	d_ans <- ans(d)
	d_ans_fit_pl <- predict(not(d_ans, contrast="pcwsLinContMean"))
	d_ans_fcast_pl <- clipped(2 * d_ans_fit_pl[n] - d_ans_fit_pl[n-1], 0, Inf)
	d_fit_pq <- clipped(inv_ans(d_ans_fit_pl), 0, Inf)
	d_fcast_pq <- clipped(round(inv_ans(d_ans_fcast_pl)), 0, Inf)

	d_fit_fcast_tv <- forecast(d, 1)
	d_fit_tv <- clipped(as.numeric(d_fit_fcast_tv$fitted), 0, Inf)
	d_fcast_tv <- clipped(round(as.numeric(d_fit_fcast_tv$mean)), 0, Inf)

	d_ans_fit_fcast_tv <- forecast(d_ans, 1)
	d_ans_fit_tv <- as.numeric(d_ans_fit_fcast_tv$fitted)
	d_ans_fcast_tv <- as.numeric(d_ans_fit_fcast_tv$mean)
	d_fit_tva <- clipped(inv_ans(d_ans_fit_tv), 0, Inf)
	d_fcast_tva <- clipped(round(inv_ans(d_ans_fcast_tv)), 0, Inf)
	
	
	d_fit_lc <- clipped(mean.from.cpt(d, wbs.sdll.cpt(d_ans)$cpt), 0, Inf)
	d_fcast_lc <- round(d_fit_lc[n])

	

	
	
	list(d=d, d_ans=d_ans, d_ans_fit_pl=d_ans_fit_pl, d_ans_fcast_pl=d_ans_fcast_pl, d_fit_pq=d_fit_pq, d_fcast_pq=d_fcast_pq, d_fit_tv=d_fit_tv, d_fcast_tv=d_fcast_tv, d_fit_tva=d_fit_tva, d_fcast_tva=d_fcast_tva, d_fit_lc=d_fit_lc, d_fcast_lc=d_fcast_lc)	
	
}



ui <- fluidPage(

  titlePanel("Trends and next day forecasts for the number of deaths in those hospitalised in the UK who tested positive for Covid-19"),

  sidebarLayout(

    sidebarPanel(

radioButtons("radio", h3("Trend estimates (references and methodology notes at the bottom of the page)"),
                        choices = list("piecewise quadratic" = 1, "default in R package 'forecast'" = 2, "piecewise constant" = 3),
                                       ,selected = 1)
                                     




    ),

    mainPanel(

	h3(textOutput("f_deaths")),
      plotOutput(outputId = "ts_plot"),
      			h4("black: actual figures", align="center", style = "color:black"),
			h4("brown: statistical trend estimates", align="center", style = "color:brown"),
			h6("References:"),
			h6("[piecewise quadratic trend]", tags$a(href="https://en.wikipedia.org/wiki/Anscombe_transform", "Anscombe transform"), "+", tags$a(href="https://rss.onlinelibrary.wiley.com/doi/full/10.1111/rssb.12322", "NOT with a piecewise-linear, continuous fit"), "+", tags$a(href="https://en.wikipedia.org/wiki/Anscombe_transform#Inversion", "asymptotically unbiased inverse Anscombe")),
			h6("[default in R package 'forecast'] R package ", tags$a(href="https://CRAN.R-project.org/package=forecast", "forecast")),
			h6("[piecewise constant trend]",  tags$a(href="https://en.wikipedia.org/wiki/Anscombe_transform", "Anscombe transform"), "+", tags$a(href="https://link.springer.com/article/10.1007/s42952-020-00060-x", "WBS2.SDLL"), "+ least-squares fit to the original data with the detected change-point locations"),
			h6("[data sources]", tags$a(href="https://en.wikipedia.org/wiki/2020_coronavirus_pandemic_in_the_United_Kingdom", "https://en.wikipedia.org/wiki/2020_coronavirus_pandemic_in_the_United_Kingdom"), "and", tags$a(href="https://github.com/emmadoughty/Daily_COVID-19/blob/master/Data/COVID19_by_day.csv", "https://github.com/emmadoughty/Daily_COVID-19/blob/master/Data/COVID19_by_day.csv")),
			h6("[this app]", tags$a(href="https://github.com/pfryz/covid-19-deaths", "https://github.com/pfryz/covid-19-deaths")),
			h6("[author]", tags$a(href="http://stats.lse.ac.uk/fryzlewicz/", "Piotr Fryzlewicz"))



    )
  )
)


server <- function(input, output) {

	dd <- fcast_deaths()

	
	output$f_deaths <- renderText({
		
		if (input$radio == 1) pred_deaths <- dd$d_fcast_pq else if (input$radio == 2) pred_deaths <- dd$d_fcast_tv else pred_deaths <- dd$d_fcast_lc
		
		paste("Next day's predicted number of deaths:", pred_deaths)
		
		
	})
	
	
	output$ts_plot <- renderPlot({

    		ts.plot(dd$d, main="Daily number of deaths, starting from 6th March 2020", ylab="", xlab="Day number")
   if (input$radio == 1) 		lines(dd$d_fit_pq, col="brown", lwd=2)
   if (input$radio == 2)	lines(dd$d_fit_tv, col="brown", lwd=2)
   if (input$radio == 3)	lines(dd$d_fit_lc, col="brown", lwd=2)


    })



	
}






shinyApp(ui = ui, server = server)
