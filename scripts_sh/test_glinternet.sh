usage() {
cat << EOF

usage: $0 options

This script tests glinternet with simulated data.

OPTIONS:
   -h  Show this message
   -r  Path of Rscript binary to use (default: Rscript)
   -s  Branch name of glinternet library to use (default: 0.mint)
   -c  Number of cols in design matrix (default: 1000)
   -u  Hierarchy setting of simulation (default: strong)
   -v  Run glinternet in verbose mode (default: FALSE)
   -w  Write fit result to file (default: FALSE)
   -n  Number of processors to use (default: 1)

EOF
}

function get_jobid {
    output=$($*)
    echo $output | head -n1 | cut -d'<' -f2 | cut -d'>' -f1
}

while getopts ":h:r:s:c:u:v:w:n:" option; do
    case "$option" in
    	   h ) usage; exit 1   ;;
         r ) RSCBIN=$OPTARG  ;;
         s ) BRNCH=$OPTARG  ;;
         c ) SIZE=$OPTARG  ;;
         u ) HIER=$OPTARG  ;;
         v ) VERB=$OPTARG  ;;
         w ) WRIT=$OPTARG  ;;
         n ) NPROC=$OPTARG  ;;
         \?) usage; exit 1   ;;
    esac
done

if [[ -z "$BRNCH" ]]; then BRNCH="0.mint"; fi
if [[ -z "$HIER" ]]; then HIER="strong"; fi
if [[ -z "$SIZE" ]]; then SIZE="1000"; fi
if [[ -z "$VERB" ]]; then VERB="FALSE"; fi
if [[ -z "$WRIT" ]]; then WRIT="FALSE"; fi
if [[ -z "$NPROC" ]]; then NPROC="1"; fi

if [[ "$VERB" != "TRUE" && "$VERB" != "FALSE" ]]; then
  echo "Verbosity setting has to be TRUE/FALSE; instead it is ${VERB}"
  usage
  exit 1
fi

if [[ "$WRIT" != "TRUE" && "$WRIT" != "FALSE" ]]; then
  echo "Write fit setting has to be TRUE/FALSE; instead it is ${WRIT}"
  usage
  exit 1
fi

if [[ -z "$RSCBIN" ]]; then 
  RSCBIN="Rscript"
  RVERS="x86_64"
else
  STRARR=(${RSCBIN//\// })
  RVERS=${STRARR[${#STRARR[@]}-3]}
fi

# check if binary exists
if ! command -v ${RSCBIN} &>/dev/null ; then
	echo "no Rscript found with path '$RSCBIN'"
	usage
	exit 1
fi

if [ "$NPROC" -lt 1 ] || [ "$NPROC" -gt 24 ]; then
  echo "choose a number between 1 and 24 for -n opt"
  usage
  exit 1
fi

if [ "$BRNCH" == "8.fma" ]; then
  AVX2="-R avx2"
fi

NICEBR=$(echo "$BRNCH" | tr '[.]' '-')

mkdir -p $(dirname $0)/../euler/test/${NICEBR}_simulated
cd $(dirname $0)/../euler/test/${NICEBR}_simulated

JOBID=$(bsub -n $NPROC -W 01:00 $AVX2 -o ${RVERS}_${HIER}_${SIZE}_%J.out -J "test_${NICEBR}" \
  "$RSCBIN ../../../scripts_r/glinternet_simulated.R $BRNCH $VERB $WRIT $HIER $SIZE")
echo $JOBID

JOBID=$(get_jobid echo $JOBID)
touch ${RVERS}_${HIER}_${SIZE}_${JOBID}.out

cd -