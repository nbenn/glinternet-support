simulate <- function(n.obs=500, n.vars=15, n.betas=10, n.gammas=10,
                     hierarchy="strong", seed.coef=NA, seed.x=NA,
                     seed.e=NA, writeCSV = FALSE, plotCoef = FALSE) {
  
  if(n.betas > n.vars) {
    stop("n.betas cannot be larger than n.vars")
  }
  
  if(n.gammas > ((n.vars^2)/2-n.vars)) {
    stop("n.betas cannot be larger than (n.vars^2)/2-n.vars))")
  }
  
  if(!any(hierarchy %in% c("strong", "weak", "anti", "none"))) {
    stop("unrecognized hierarchy setting")
  }
  
  library("Matrix")
  
  if (!is.na(seed.coef)) {
    cat("setting seed for coeffs: ", seed.coef, "\n")
    set.seed(seed.coef) 
  } else {
    cat("using random seed for coeffs\n")
  }
  
  #alpha.min <- -1
  #alpha.max <-  1
  beta.min  <-  0
  beta.max  <-  1
  gamma.min <-  0
  gamma.max <-  1
  
  #alpha <- runif(1, min=alpha.min, max=alpha.max)
  alpha <- 0
  
  beta <- sparseMatrix(
    i = rep(1, n.betas), 
    j = sample(1:n.vars, n.betas),
    #x = rep(1, n.betas),
    x = runif(n.betas, min=beta.min, max=beta.max),
    dims = c(1, n.vars),
    giveCsparse = FALSE
  )
  
  gamma.index <- matrix(NA, nrow=2, ncol=n.gammas)
  if (hierarchy == "none") {
    # sample pairs from all pairs in 1:n.var, eg n.var=4
    # x x x x   then, given the number (c) of a picked
    # 1 x x x   pair, find the row and col indexes a and b
    # 2 3 x x   to verify: c = ((a-1)^2-(a-1))/2+b
    # 4 5 6 x
    pot.size <- (n.vars^2-n.vars)/2
    smpl <- sample(pot.size, n.gammas, replace=FALSE)
    a <- ceiling(1/2*(1+sqrt(1+8*smpl)))
    b <- a-((a^2-a)/2-smpl)-1
    gamma.index[1,] <- a
    gamma.index[2,] <- b
  } else if (hierarchy == "strong") {
    if(n.gammas > ((n.betas^2)/2-n.betas)) { 
      stop("n.gammas cannot be larger than (n.betas^2)/2-n.betas")
    }
    pot.size <- (n.betas^2-n.betas)/2
    smpl <- sample(pot.size, n.gammas, replace=FALSE)
    a <- ceiling(1/2*(1+sqrt(1+8*smpl)))
    b <- a-((a^2-a)/2-smpl)-1
    gamma.index[1,] <- beta@j[a]+1
    gamma.index[2,] <- beta@j[b]+1
  } else if (hierarchy == "weak") {
    if(n.gammas > ((n.betas^2)/2-n.betas)) { 
      stop("n.gammas cannot be larger than (n.betas^2)/2-n.betas")
    }
    # sample one index from the set of nonzero betas and one index
    # from the set of all coefficients without the nonzero betas
    # -> disjoint sets, eg. n.bet=3, n.var=8
    #  1  2  3  4  5   given the number of a picked pair, find row
    #  6  7  8  9 10   and col indexes
    # 11 12 13 14 15
    pot.a <- beta@j+1
    pot.b <- setdiff(c(1:n.vars), beta@j+1)
    pot.size <- length(pot.a) * length(pot.b)
    smpl <- sample(pot.size, n.gammas, replace=FALSE)
    a <- ceiling(smpl/length(pot.b))
    b <- smpl-(a-1)*length(pot.b)
    gamma.index[1,] <- a
    gamma.index[2,] <- b
  } else if (hierarchy == "anti") {
    if(n.gammas > (((n.vars-n.betas)^2)/2-(n.vars-n.betas))) { 
      stop("n.gammas cannot be larger than 
           ((n.vars-n.betas)^2)/2-(n.vars-n.betas))")
    }
    pot <- setdiff(c(1:n.vars), beta@j+1)
    pot.size <- (length(pot)^2-length(pot))/2
    smpl <- sample(pot.size, n.gammas, replace=FALSE)
    a <- ceiling(1/2*(1+sqrt(1+8*smpl)))
    b <- a-((a^2-a)/2-smpl)-1
    gamma.index[1,] <- pot[a]
    gamma.index[2,] <- pot[b]
  } else stop("unrecognized hierarchy setting")
  
  gamma <- sparseMatrix(
    i = gamma.index[1,], 
    j = gamma.index[2,],
    #x = rep(1, n.gammas),
    x = runif(n.gammas, min=gamma.min, max=gamma.max),
    dims = c(n.vars, n.vars),
    giveCsparse = FALSE
  )
  
  if (!is.na(seed.x)) {
    cat("setting seed for x: ", seed.x, "\n")
    set.seed(seed.x) 
  } else  if (!is.na(seed.coef)) {
    # revert to random seed for x
    cat("removing seed for coeffs and using random seed for x\n")
    rm(list=".Random.seed", envir=globalenv())
  } else {
    cat("using random seed for x\n")
  }
  
  x.min <- 0
  x.max <- 1
  e.sd  <- 0.1
  
  x <- matrix(runif(n.vars*n.obs, min=x.min, max=x.max), nrow=n.obs)
  #x <- 1-x

  if (!is.na(seed.e)) {
    cat("setting seed for e: ", seed.e, "\n")
    set.seed(seed.e) 
  } else if (!is.na(seed.coef) | !is.na(seed.x)) {
    # revert to random seed for x
    cat("removing seed for coeffs/x and using random seed for e\n")
    rm(list=".Random.seed", envir=globalenv())
  } else {
    cat("using random seed for e\n")
  }

  e <- rnorm(n.obs, mean=0, sd=e.sd)
  y <- rep(NA, n.obs)
  
  for(i in 1:n.obs) {
    mainEffect <- 0
    for (j in 1:n.betas) {
      mainEffect <- mainEffect + beta@x[j]*(x[beta@j[j]*n.obs+i])
    }
    interaction <- 0
    for (j in 1:n.gammas) {
      interaction <- interaction + gamma@x[j]*((x[gamma@i[j]*n.obs+i]*x[gamma@j[j]*n.obs+i]))
    }

    y[i] <- alpha + mainEffect + interaction + e[i]
  }
  
  if(plotCoef) {
    plotCoefficients(beta, gamma, TRUE)
  }
  
  if(writeCSV) {
    write.table(x=x, file="data/x.csv", row.names = FALSE, col.names = FALSE,
                sep=',')
    write.table(x=y, file="data/y.csv", row.names = FALSE, col.names = FALSE,
                sep=',')
    write.table(x=alpha, file="data/alpha.csv", row.names = FALSE,
                col.names = FALSE, sep=',')
    write.table(x=as(beta, "matrix"), file="data/beta.csv", row.names = FALSE,
                col.names = FALSE, sep=',')
    write.table(x=as(gamma, "matrix"), file="data/gamma.csv", row.names = FALSE,
                col.names = FALSE, sep=',')
    write.table(x=e, file="data/epsilon.csv", row.names = FALSE, col.names = FALSE,
                sep=',')
  }
  
  return(list("X" = x, "Y" = y, "n.interactions" = n.gammas,
              "intercept" = alpha, "mainEffects" = beta,
              "interactions" = gamma, "errors" = e, "n.obs"=n.obs, 
              "n.vars"=n.vars, "n.betas"=n.betas, "n.gammas"=n.gammas,
              "hierarchy"=hierarchy))
}