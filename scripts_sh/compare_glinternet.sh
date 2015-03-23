usage() {
cat << EOF

usage: $0 options

This script compares two versions of glinternet using simulated data
to make sure the produced output is identical.

OPTIONS:
   -h  Show this message
   -r  Path of Rscript binary to use (default: Rscript)
   -s  Branch name of glinternet library 1 to use (default: 0.mint)
   -d  Branch name of glinternet library 2 to use (required)
   -c  Number of cols in design matrix (default: 1000)
   -u  Hierarchy setting of simulateion (default: strong)
   -n  Number of processors to use (default: 1)

EOF
}

function get_jobid {
    output=$($*)
    echo $output | head -n1 | cut -d'<' -f2 | cut -d'>' -f1
}

while getopts ":h:r:s:d:c:u:n:" option; do
    case "$option" in
    	   h ) usage; exit 1   ;;
         r ) RSCBIN=$OPTARG  ;;
         s ) BRNCH1=$OPTARG  ;;
         d ) BRNCH2=$OPTARG  ;;
         c ) SIZE=$OPTARG  ;;
         u ) HIER=$OPTARG  ;;
         n ) NPROC=$OPTARG  ;;
         \?) usage; exit 1   ;;
    esac
done

if [[ -z "$BRNCH1" ]]; then BRNCH1="0.mint"; fi
if [[ -z "$HIER" ]]; then HIER="strong"; fi
if [[ -z "$SIZE" ]]; then SIZE="1000"; fi
if [[ -z "$NPROC" ]]; then NPROC="1"; fi

if [[ -z "$RSCBIN" ]]; then 
  RSCBIN="Rscript"
  RVERS="x86_64"
else
  STRARR=(${RSCBIN//\// })
  RVERS=${STRARR[${#STRARR[@]}-3]}
fi

if [[ -z "$BRNCH2" ]]; then 
  echo "argument for second branch is missing"
  usage
  exit 1
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

if [ "$BRNCH1" == "8.fma" ] || [ "$BRNCH2" == "8.fma" ]; then
  BETA="-R beta"
fi

NICEBR1=$(echo "$BRNCH1" | tr '[.]' '-')
NICEBR2=$(echo "$BRNCH2" | tr '[.]' '-')
VERB="FALSE"
WRIT="TRUE"

mkdir -p $(dirname $0)/../euler/compare/${NICEBR1}_${NICEBR2}_simulated
cd $(dirname $0)/../euler/compare/${NICEBR1}_${NICEBR2}_simulated

JOBBR11=$(bsub -n $NPROC -W 00:30 $BETA -o ${RVERS}_${HIER}_${SIZE}_%J.out -J "sim11" \
  "$RSCBIN ../../../scripts_r/glinternet_simulated.R $BRNCH1 $VERB $WRIT $HIER $SIZE")
echo $JOBBR11
JOBBR11=$(get_jobid echo $JOBBR11)
JOBBR12=$(bsub -n $NPROC -W 00:30 $BETA -o ${RVERS}_${HIER}_${SIZE}_%J.out -J "sim12" \
  "$RSCBIN ../../../scripts_r/glinternet_simulated.R $BRNCH1 $VERB $WRIT $HIER $SIZE")
echo $JOBBR12
JOBBR12=$(get_jobid echo $JOBBR12)
JOBBR21=$(bsub -n $NPROC -W 00:30 $BETA -o ${RVERS}_${HIER}_${SIZE}_%J.out -J "sim21" \
  "$RSCBIN ../../../scripts_r/glinternet_simulated.R $BRNCH2 $VERB $WRIT $HIER $SIZE")
echo $JOBBR21
JOBBR21=$(get_jobid echo $JOBBR21)
JOBBR22=$(bsub -n $NPROC -W 00:30 $BETA -o ${RVERS}_${HIER}_${SIZE}_%J.out -J "sim22" \
  "$RSCBIN ../../../scripts_r/glinternet_simulated.R $BRNCH2 $VERB $WRIT $HIER $SIZE")
echo $JOBBR22
JOBBR22=$(get_jobid echo $JOBBR22)

FIT1="${RVERS}_${HIER}_${SIZE}_${JOBBR11}-fit.rds"
FIT2="${RVERS}_${HIER}_${SIZE}_${JOBBR12}-fit.rds"
FIT3="${RVERS}_${HIER}_${SIZE}_${JOBBR21}-fit.rds"
FIT4="${RVERS}_${HIER}_${SIZE}_${JOBBR22}-fit.rds"

COMPJOB=$(bsub -w "ended($JOBBR11) && ended($JOBBR12) && ended($JOBBR21) && ended($JOBBR22)" \
  -W 00:10 $BETA -o comp_${RVERS}_${HIER}_${SIZE}_%J.out -J "compare"\
  "$RSCBIN ../../../scripts_r/compare_fit.R "\
  "$FIT1 $FIT2 $FIT3 $FIT4")
echo $COMPJOB
COMPJOB=$(get_jobid echo $COMPJOB)

touch ${RVERS}_${HIER}_${SIZE}_${COMPJOB}.out

OUT1="${RVERS}_${HIER}_${SIZE}_${JOBBR11}.out"
OUT2="${RVERS}_${HIER}_${SIZE}_${JOBBR12}.out"
OUT3="${RVERS}_${HIER}_${SIZE}_${JOBBR21}.out"
OUT4="${RVERS}_${HIER}_${SIZE}_${JOBBR22}.out"

FILES="comp_${RVERS}_${HIER}_${SIZE}_${COMPJOB}.out ${OUT1} ${OUT2} ${OUT3} ${OUT4}"

bsub -w "ended($COMPJOB)" -W 00:05 -J "clean" -o /dev/null\
  "cat $FILES > ${RVERS}_${HIER}_${SIZE}_${COMPJOB}.out; rm $FILES"

cd -