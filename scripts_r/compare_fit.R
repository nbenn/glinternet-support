usage <- function(){
  cat("\nusage: path/to/Rscript compare_fit.R file1 file2 ... fileN\n",
      "  files: list of files containing fit objects from glinternet\n")
}

args <- unlist(strsplit(commandArgs(trailingOnly = TRUE), " "))

if(!any(file.exists(args))) {
  usage()
  print(args)
  stop("one or more of the specified files does not exist")
}

fitted <- lapply(args, readRDS)

if(length(args) != length(fitted)) {
  usage()
  print(args)
  stop("not all files were read correctly")
}

for (i in 1:length(fitted)) {
  for (j in (i+1):length(fitted)) {
    if(j>i & j<=length(fitted)) {
      cat("\ncomparing",
        tail(unlist(strsplit(args[i], "/")), n=1),
        "against",
        tail(unlist(strsplit(args[j], "/")), n=1),
        "\n")
      print(all.equal(fitted[[i]], fitted[[j]]))
    }
  }
}

cat("\n")

unlink(args)

quit(save="no")
