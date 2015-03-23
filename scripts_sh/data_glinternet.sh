usage() {
cat << EOF

usage: $0 options

This script runs glinternet with real data.

OPTIONS:
   -h  Show this message
   -r  Path of Rscript binary to use (default: Rscript)
   -s  Branch name of glinternet library to use (default: 7.optall)
   -x  Name of design matrix to use (default: qiagen)
   -y  Name of response vector to use (default: brucella)
   -v  Run glinternet in verbose mode (default: TRUE)
   -n  Number of processors to use (default: 24)
   -t  Runtime in h (default: 120h on euler, 168h on brutus)

EOF
}

function get_jobid {
    output=$($*)
    echo $output | head -n1 | cut -d'<' -f2 | cut -d'>' -f1
}

while getopts ":h:r:s:x:y:v:n:t:" option; do
    case "$option" in
    	   h ) usage; exit 1   ;;
         r ) RSCBIN=$OPTARG  ;;
         s ) BRNCH=$OPTARG  ;;
         x ) DSGN=$OPTARG  ;;
         y ) RSPN=$OPTARG  ;;
         v ) VERB=$OPTARG  ;;
         n ) NPROC=$OPTARG  ;;
         t ) RUNTIME=$OPTARG  ;;
         \?) usage; exit 1   ;;
    esac
done

if [[ -z "$BRNCH" ]]; then BRNCH="7.optall"; fi
if [[ -z "$DSGN" ]]; then DSGN="qiagen"; fi
if [[ -z "$RSPN" ]]; then RSPN="brucella"; fi
if [[ -z "$VERB" ]]; then VERB="TRUE"; fi
if [[ -z "$NPROC" ]]; then NPROC="24"; fi

if [[ "$VERB" != "TRUE" && "$VERB" != "FALSE" ]]; then
  echo "Verbosity setting has to be TRUE/FALSE; instead it is ${VERB}"
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

NICEBR=$(echo "$BRNCH" | tr '[.]' '-')

HOSTNME=$(hostname)

if [[ $HOSTNME == "euler"* ]]; then

  if [ "$BRNCH" == "8.fma" ]; then
    BETA="-R beta"
    MEMO=$((2600*24/NPROC))
  else
    MEMO=$((5000*24/NPROC))
  fi
  
  if [ "$NPROC" -lt 1 ] || [ "$NPROC" -gt 24 ]; then
    echo "choose a number between 1 and 24 for -n opt"
    usage
    exit 1
  fi

  if [[ -z "$RUNTIME" ]]; then RUNTIME="120"; fi

  if [ "$RUNTIME" -lt 1 ] || [ "$RUNTIME" -gt 720 ]; then
    echo "choose a number between 1 and 720 for -t opt"
    usage
    exit 1
  fi
  
  mkdir -p $(dirname $0)/../euler/data/${DSGN}/${RSPN}
  cd $(dirname $0)/../euler/data/${DSGN}/${RSPN}

elif [[ $HOSTNME == "brutus"* ]]; then

  if [ "$BRNCH" == "8.fma" ]; then
    echo "no avx2 available on brutus; choose another branch"
    usage
    exit 1
  fi

  if [ "$NPROC" -lt 1 ] || [ "$NPROC" -gt 48 ]; then
    echo "choose a number between 1 and 48 for -n opt"
    usage
    exit 1
  fi

  if [[ -z "$RUNTIME" ]]; then RUNTIME="168"; fi

  if [ "$RUNTIME" -lt 1 ] || [ "$RUNTIME" -gt 168 ]; then
    echo "choose a number between 1 and 168 for -t opt"
    usage
    exit 1
  fi
  
  mkdir -p $(dirname $0)/../brutus/data/${DSGN}/${RSPN}
  cd $(dirname $0)/../brutus/data/${DSGN}/${RSPN}

else
  echo "could not determine host: "
  echo $HOSTNME
  exit 1
fi

RUNTIME=$((RUNTIME*60))

echo "nproc: $NPROC"
echo "time: $RUNTIME"
echo "memory: $MEMO"

JOBID=$(bsub -n $NPROC -W $RUNTIME -R "rusage[mem=${MEMO}]" $BETA -o ${NICEBR}_${RVERS}_%J.out -J "${DSGN}_${RSPN}" \
  "$RSCBIN ../../../../scripts_r/glinternet_data.R $BRNCH $VERB $DSGN $RSPN")
echo $JOBID

JOBID=$(get_jobid echo $JOBID)
touch ${NICEBR}_${RVERS}_${JOBID}.out

cd -