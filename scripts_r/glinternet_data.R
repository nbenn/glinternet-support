usage <- function(){
  cat("\nusage: path/to/Rscript runner.R branch ngenes design rspnse\n",
      "  branch    : name of glinternet library to use (deafult: 7.optall)\n",
      "  verbosity : run glinternet in verbose mode (default: FALSE)\n",
      "  design mat: name of design matrix to use (default: qiagen)\n",
      "  response  : name of response vector to use (default: brucella)\n")
}

createDense <- function(x){
  if(!is(x, "dgTMatrix")) x <- as(x, "dgTMatrix")
  n.row <- as.double(dim(x)[1])
  n.col <- dim(x)[2]
  n.elm <- length(x@x)
  result <- matrix(0, nrow=n.row, ncol=n.col)
  dimnames(result) <- dimnames(x)
  # if n.elm > 2^31=2'147'483'648, [i,j] access is not possible
  for(i in 1:n.elm) {
    result[x@j[i]*n.row+x@i[i]+1] <- x@x[i]
  }
  return(result)
}

processDsgnMat <- function(..., y){
  result.full <- rBind(...)
  if(!is(result.full, "dgCMatrix")) {
    result.full <- as(result.full, "dgCMatrix")
  }
  #find all columns that contain at least one non-zero entry
  ind <- which(diff(result.full@p)!=0)
  #drop those cols
  result.red <- result.full[,ind]
  #find all rows that are not included in response
  contained <- dimnames(result.red)[[1]] %in% y$siRNAMaterialCode
  cat(
    "Attention: dropping",
    length(dimnames(result.red)[[1]])-sum(contained),
    "rows from the design matrix: no match\n")
  result.drp <- result.red[contained,]
  #return result ordered by row names
  return(result.drp[order(rownames(result.drp)),])
}

preprocRespons <- function(y){
  #remove rows with na's from response
  if(is.null(y$dInfectionDT_eIndex_nBScore_nMAD)) {
    cat("Using dInfectionSVM_eIndex_nBScore_nMAD\n")
    ind <- which(is.na(y$dInfectionSVM_eIndex_nBScore_nMAD))
  }
  else {
    cat("Using dInfectionDT_eIndex_nBScore_nMAD\n")
    ind <- which(is.na(y$dInfectionDT_eIndex_nBScore_nMAD))
  }
  cat(
    "Attention: dropping",
    length(ind),
    "rows from the response vector: na\n")
  if(length(ind) > 0) result <- y[-ind,]
  else result <- y
  return(result)    
}

processRespons <- function(x, y){
  if(nrow(x) < 1) stop("no rows left in design matrix.\n")
  stopifnot(all(dimnames(x)[[1]] %in% y$siRNAMaterialCode))
  contained <- y$siRNAMaterialCode %in% dimnames(x)[[1]]
  drop <- y[contained,]
  #create named vector with infection index
  if(is.null(y$dInfectionDT_eIndex_nBScore_nMAD)) {
    result <- as.numeric(drop$dInfectionSVM_eIndex_nBScore_nMAD)
  }
  else {
    result <- as.numeric(drop$dInfectionDT_eIndex_nBScore_nMAD)
  }
  names(result) <- drop$siRNAMaterialCode
  #return ordered list
  result.ordered <- result[order(names(result))]
  stopifnot(all.equal(names(result.ordered), rownames(x)))
  return(result.ordered)
}

args <- commandArgs(trailingOnly = TRUE)
branch <- args[1]
verbos <- args[2]
design <- args[3]
rspnse <- args[4]
rm(args)

if(is.na(branch)) {
  branch <- "7.optall"
}
if(is.na(verbos)) {
  verbos <- FALSE
} else {
  verbos <- as.logical(verbos)
}
if(is.na(design)) {
  design <- "qiagen"
}
if(is.na(rspnse)) {
  rspnse <- "brucella"
}

library("Matrix")
if(!library(paste("glinternet", branch, sep=""), character.only = TRUE, logical.return = TRUE)) {
  usage()
  stop("unrecognized glinternet version")
}

if (design == "dharmacon") {
  desmat <- readRDS("/cluster/home/nbennett/Polybox/Shared/Semesterprojekt Nicolas/Genome/Designmatrizen/fabian_DP.rds")
} else if (design == "qiagen") {
  desmat <- readRDS("/cluster/home/nbennett/Polybox/Shared/Semesterprojekt Nicolas/Genome/Designmatrizen/fabian_QIAGEN.rds")
  rownames(desmat) <- paste0("QIAGEN_", rownames(desmat))
} else if (design == "both") {
  desmat1 <- readRDS("/cluster/home/nbennett/Polybox/Shared/Semesterprojekt Nicolas/Genome/Designmatrizen/fabian_DP.rds")
  desmat2 <- readRDS("/cluster/home/nbennett/Polybox/Shared/Semesterprojekt Nicolas/Genome/Designmatrizen/fabian_QIAGEN.rds")
  rownames(desmat2) <- paste0("QIAGEN_", rownames(desmat2))
  desmat <- rBind(desmat1, desmat2)
  rm(desmat1, desmat2)
} else {
  usage()
  stop("unrecognized design matrix setting")
}

if (rspnse == "adeno") {
  load("/cluster/home/nbennett/Polybox/Shared/Semesterprojekt Nicolas/Genome/Response/Adeno_primary_clean.rda")
} else if (rspnse == "bartonella") {
  load("/cluster/home/nbennett/Polybox/Shared/Semesterprojekt Nicolas/Genome/Response/Bartonella_primary_clean.rda")
} else if (rspnse == "brucella") {
  load("/cluster/home/nbennett/Polybox/Shared/Semesterprojekt Nicolas/Genome/Response/Brucella_primary_clean.rda")
} else if (rspnse == "listeria") {
  load("/cluster/home/nbennett/Polybox/Shared/Semesterprojekt Nicolas/Genome/Response/Listeria_primary_clean.rda")
} else if (rspnse == "rhino") {
  load("/cluster/home/nbennett/Polybox/Shared/Semesterprojekt Nicolas/Genome/Response/Rhino_primary_clean.rda")
} else if (rspnse == "salmonella") {
  load("/cluster/home/nbennett/Polybox/Shared/Semesterprojekt Nicolas/Genome/Response/Salmonella_primary_clean.rda")
} else if (rspnse == "shigella") {
  load("/cluster/home/nbennett/Polybox/Shared/Semesterprojekt Nicolas/Genome/Response/Shigella_primary_clean.rda")
} else if (rspnse == "vaccinia") {
  load("/cluster/home/nbennett/Polybox/Shared/Semesterprojekt Nicolas/Genome/Response/Vaccinia_primary_clean.rda")
} else {
  usage()
  stop("unrecognized response vector setting")
}

n.cores <- as.integer(Sys.getenv("LSB_DJOB_NUMPROC"))
if(n.cores < 1 | n.cores > 48) {
  n.cores <- 1
}
Sys.setenv(OMP_NUM_THREADS=n.cores)

cat("\nbranch:     ", branch,
    "\ndesign mat: ", design,
    "\nresp vec:   ", rspnse,
    "\nncores:     ", n.cores, "\n")

d.primary$siRNAMaterialCode <- paste(toupper(d.primary$LIBRARY), d.primary$Catalog_number, sep="_")

Y <- preprocRespons(d.primary)
X <- createDense(processDsgnMat(desmat, y=Y))
Y <- processRespons(X, Y)
#if (ngenes != "all") {
#  X <- X[,names(sort(colSums(X), decreasing=T)[1:ngenes])]
#}

str(Y)
str(X)

Rvers <- tail(unlist(strsplit(file.path(R.home()), "/")), n=3)[1]
filename <- paste(Rvers, design, rspnse, Sys.getenv("LSB_JOBID"), sep="_")

numLevels <- rep(1, ncol(X))
ptm <- proc.time()
cat("\ntime for glinternet", branch, ":\n")
fit <- glinternet(X, Y, numLevels, verbose=TRUE, numCores = n.cores, filename=filename)
time <- proc.time() - ptm
print(time)

saveRDS(fit, paste(filename, "-fit.rds", sep=""))

quit(save="no")
