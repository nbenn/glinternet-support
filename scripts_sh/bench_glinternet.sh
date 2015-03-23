usage() {
cat << EOF

usage: $0 options

This script benchmarks glinternet with simulated data.

OPTIONS:
   -h  Show this message
   -r  Path of Rscript binary to use (default: Rscript)
   -s  Branch name of glinternet library to use (default: 0.mint)
   -n  Number of processors to use (default: 1)

EOF
}

function get_jobid {
    output=$($*)
    echo $output | head -n1 | cut -d'<' -f2 | cut -d'>' -f1
}

while getopts ":h:r:s:n:" option; do
    case "$option" in
    	   h ) usage; exit 1   ;;
         r ) RSCBIN=$OPTARG  ;;
         s ) BRNCH=$OPTARG  ;;
         n ) NPROC=$OPTARG  ;;
         \?) usage; exit 1   ;;
    esac
done

if [[ -z "$BRNCH" ]]; then BRNCH="0.mint"; fi
if [[ -z "$NPROC" ]]; then NPROC="1"; fi

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

mkdir -p $(dirname $0)/../euler/bench/simulated/${RVERS}/${NICEBR}/proc${NPROC}
cd $(dirname $0)/../euler/bench/simulated/${RVERS}/${NICEBR}/proc${NPROC}

VERB="TRUE"
WRIT="TRUE"

MEMO=$((250*24/NPROC))

HIER="strong"
NVAR="5000"
NOBS="15000"
NBET="500"
NGAM="500"
SIZE="${NVAR} ${NOBS} ${NBET} ${NGAM}"
SIZU="${NVAR}_${NOBS}_${NBET}_${NGAM}"

for i in {1..5}; do
  JOBID=$(bsub -n $NPROC -R "rusage[mem=${MEMO}]" -W 24:00 $AVX2 -o ${HIER}_${SIZU}_%J.out -J "test_${NICEBR}" \
    "$RSCBIN ../../../../../../scripts_r/glinternet_simulated.R $BRNCH $VERB $WRIT $HIER $SIZE")
  echo $JOBID

  JOBID=$(get_jobid echo $JOBID)
  touch ${HIER}_${SIZU}_${JOBID}.out
done

NBET="1000"
NGAM="100000"
SIZE="${NVAR} ${NOBS} ${NBET} ${NGAM}"
SIZU="${NVAR}_${NOBS}_${NBET}_${NGAM}"

for i in {1..5}; do
  JOBID=$(bsub -n $NPROC -R "rusage[mem=${MEMO}]" -W 48:00 $AVX2 -o ${HIER}_${SIZU}_%J.out -J "test_${NICEBR}" \
    "$RSCBIN ../../../../../../scripts_r/glinternet_simulated.R $BRNCH $VERB $WRIT $HIER $SIZE")
  echo $JOBID

  JOBID=$(get_jobid echo $JOBID)
  touch ${HIER}_${SIZU}_${JOBID}.out
done

HIER="none"
NBET="500"
NGAM="500"
SIZE="${NVAR} ${NOBS} ${NBET} ${NGAM}"
SIZU="${NVAR}_${NOBS}_${NBET}_${NGAM}"

for i in {1..5}; do
  JOBID=$(bsub -n $NPROC -R "rusage[mem=${MEMO}]" -W 72:00 $AVX2 -o ${HIER}_${SIZU}_%J.out -J "test_${NICEBR}" \
    "$RSCBIN ../../../../../../scripts_r/glinternet_simulated.R $BRNCH $VERB $WRIT $HIER $SIZE")
  echo $JOBID

  JOBID=$(get_jobid echo $JOBID)
  touch ${HIER}_${SIZU}_${JOBID}.out
done

cd -