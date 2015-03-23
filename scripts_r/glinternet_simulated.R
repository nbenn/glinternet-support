usage <- function(){
  cat("\n\nusage: path/to/Rscript glinternet_simulated.R [branch1 hierarchy n.vars n.obs n.beta n.gamma]\n\n",
      "  branch   : name of glinternet library to use (deafult: 0.mint)\n",
      "  verbosity: run glinternet in verbose mode (default: FALSE)\n",
      "  write    : write out fit object (default: FALSE)\n",
      "  hierarchy: hierarchy of simulated data (default: strong)\n",
      "  n.vars   : number of cols in design matrix (default: 1000)\n",
      "  n.obs    : number of rows in design matrix/response vector (default: n.vars*3)\n",
      "  n.beta   : number of nonzero main effects (default: n.vars/10)\n",
      "  n.gamma  : number of nonzero interaction effects (default: n.vars/10)\n\n")
}

args <- commandArgs(trailingOnly = TRUE)
brnch <- args[1]
verbo <- args[2]
write <- args[3]
hiera <- args[4]
n.var <- args[5]
n.obs <- args[6]
n.bet <- args[7]
n.gam <- args[8]
rm(args)

if(is.na(brnch)) {
  brnch <- "0.mint"
}
if(is.na(verbo)) {
  verbo <- FALSE
} else {
  verbo <- as.logical(verbo)
}
if(is.na(write)) {
  write <- FALSE
} else {
  write <- as.logical(write)
}
if(is.na(hiera)) {
  hiera <- "strong"
}
if(is.na(n.var)) {
  n.var <- 1000
} else {
  n.var <- as.integer(n.var)
}
if(is.na(n.obs)) {
  n.obs <- ceiling(n.var*3)
} else {
  n.obs <- as.integer(n.obs)
}
if(is.na(n.bet)) {
  n.bet <- ceiling(n.var/10)
} else {
  n.bet <- as.integer(n.bet)
}
if(is.na(n.gam)) {
  n.gam <- ceiling(n.var/10)
} else {
  n.gam <- as.integer(n.gam)
}

print(paste(brnch, verbo, write, hiera, n.var, n.obs, n.bet, n.gam, sep="; "))

if(n.var < 1 | n.var > 30000) {
  usage()
  stop("please choose an appropriate number of cols; ", n.var, " doesn't work")
}

if(!any(hiera %in% c("strong", "weak", "anti", "none"))) {
  usage()
  stop("unrecognized hierarchy setting: ", hiera)
}

if(!library(paste("glinternet", brnch, sep=""), character.only = TRUE, logical.return = TRUE)) {
  usage()
  stop("unrecognized glinternet version for slot 1: ", brnch)
}
#detach(paste("package:glinternet", bra.2, sep=""), unload = TRUE, character.only = TRUE)

argv <- commandArgs(trailingOnly = FALSE)
base_dir <- dirname(substring(argv[grep("--file=", argv)], 8))
source(paste(base_dir, "simulate_data.R", sep="/"))
rm(argv)

n.cores <- as.integer(Sys.getenv("LSB_DJOB_NUMPROC"))
if(n.cores < 1 | n.cores > 48) {
  n.cores <- 1
}
Sys.setenv(OMP_NUM_THREADS=n.cores)

cat("glinternet settings:\n",
  "branch   : ", brnch, "\n",
  "verbosity: ", verbo, "\n",
  "write out: ", write, "\n",
  "n.cores  : ", n.cores, "\n")
cat("simulation setup:\n",
  "hierarchy: ", hiera, "\n",
  "n.vars   : ", n.var, "\n",
  "n.obs    : ", n.obs, "\n",
  "n.betas  : ", n.bet, "\n",
  "n.gammas : ", n.gam, "\n")

ptm <- proc.time()  
data.synthetic <- simulate(n.obs=n.obs, n.vars=n.var, n.betas=n.bet, n.gammas=n.gam,
                           seed.coef=5, seed.x=7, seed.e=9, hierarchy=hiera)
time <- proc.time() - ptm
cat("\ntime for simulation:\n")
print(time)

contVar <- rep(1, length(data.synthetic$X[1,]))

ptm <- proc.time()
cat("\ntime for glinternet", brnch, ":\n")
glint.fit <- glinternet(data.synthetic$X, data.synthetic$Y, numLevels = contVar, 
  verbose=verbo, numCores = n.cores)
time <- proc.time() - ptm
print(time)

if (write) {
  Rvers <- tail(unlist(strsplit(file.path(R.home()), "/")), n=3)[1]
  filename <- paste(Rvers, hiera, n.var, 
    Sys.getenv("LSB_JOBID"), sep="_")
  saveRDS(glint.fit, paste(filename, "-fit.rds", sep=""))
}

quit(save="no")
