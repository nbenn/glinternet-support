usage() {
cat << EOF

usage: $0 options

This script compiles and installs the specified glinternet sources
to the specified R installation. ompP can be chosen to be included.

OPTIONS:
   -h  Show this message
   -r  Path of r binary to use (default: R)
   -g  Directory of glinternet source (default: ./../glinternet)
   -b  Branch of glinternet source to check out (default: 0.mint)
   -o  Directory of ompp to use (default: disabled)

EOF
}

while getopts ":r:g:b:o:" option; do
    case "$option" in
    	   h ) usage; exit 1 ;;
         r ) RBIN=$OPTARG  ;;
         g ) GLNT=$OPTARG  ;;
         b ) BRNC=$OPTARG  ;;
         o ) OMPP=$OPTARG  ;;
         \?) usage; exit 1 ;;
    esac
done

if [[ -z "$RBIN" ]]; then RBIN="R"; fi
if [[ -z "$GLNT" ]]; then GLNT="$(dirname $0)/../glinternet"; fi
if [[ -z "$BRNC" ]]; then BRNC="0.mint"; fi

# check if binary exists
if ! command -v ${RBIN} &>/dev/null ; then
	echo "no R found with path '$RBIN'"
	usage
	exit 1
fi

# check if glinternet directory exists
if [ ! -d "$GLNT" ]; then
  echo "no directory found with path '$GLNT' for glinternet"
  usage
  exit 1
fi

# check if branch exists
if [ -z "$(git --git-dir $GLNT/.git show-ref refs/heads/$BRNC)" ]; then
  echo "no branch with name '$BRNC' found in '$GLNT'"
  usage
  exit 1
fi

if [[ -z "$OMPP" ]]; then 
	ARGS="--clean"
else
	if ! command -v ${OMPP} &>/dev/null ; then
		echo "no OMPP found with path '$OMPP'"
		usage
		exit 1
	fi
	ARGS="--configure-args='--with-OMPP=$OMPP' --clean"
fi

echo "using '$RBIN' as R installation"
echo "using '$GLNT' as glinternet source"
echo "using '$BRNC' as branch"
if [[ -z "$OMPP" ]]; then 
	echo "not using OMPP"
else
	echo "using '$OMPP' as OMPP wrapper"
fi

cd $GLNT
git checkout $BRNC
RETVAL=$?
if ! test "$RETVAL" -eq 0
then
    echo >&2 "checkout failed with exit status $RETVAL"
    cd -
    exit 1
fi

sh ./cleanup
autoconf
$RBIN CMD INSTALL $ARGS $(pwd)
cd -
