#!/bin/ksh 
#set -x

############################################################
# Create the initial clone if necessary
#  Before this will work you must:
#    1) setup a ssh key for use under your devops site
#    2) setup a ssh proxy if working from behind a firewall
#  Review the devops wiki for more details on how to
############################################################
create_repository()
{
    echo "INFO: Creating the initial repository from $REPURL into $REPDIR"
    /bin/mkdir -p $REPDIR
    cd $REPDIR
    subdir=`basename $REPDIR`

    cd ..
    git clone $REPURL $subdir
    if [ $? -ne 0 ]; then
       echo "ERROR: Could not clone the batch directory"
       exit 1
    fi
}

############################################################
# Make sure the repository is clean
############################################################
clean_repository()
{
repository_dir=$1
branch=$2
appname=$3

   cd $repository_dir/$appname

   # remove these links so the clean will not clear out all of 
   # the programs that have already been built!
   /bin/rm -f ubin
   /bin/rm -f uobj
   /bin/rm -f ulib

   # Save off a few key temporary files in the src dir before
   # cleaning.  This prevents some of the make files from auto
   # rebuilding
   /bin/mv src/claimList.h $WRKDIR 2>/dev/null
   /bin/mv src/npicommon.c $WRKDIR 2>/dev/null
   /bin/mv src/elg_xml_default.c $WRKDIR 2>/dev/null

   # Reset the directories to their original state
   echo "INFO: undo any changes in the current repository"
   git checkout $branch
   git reset
   git checkout .
   git clean -fdx

   # restore those files we saved off
   /bin/mv $WRKDIR/claimList.h src 2>/dev/null
   /bin/mv $WRKDIR/npicommon.c src 2>/dev/null
   /bin/mv $WRKDIR/elg_xml_default.c src 2>/dev/null
}

############################################################
# Git latest copy of code from remote
############################################################
get_latest_repository()
{
repository_dir=$1
branch=$2

   ## I probably do not really need to pull on the master
   ## branch and could just do $branch!

   echo "INFO: getting the latest code from devops site"
   cd $repository_dir
   git checkout master
   git pull
   if [ $? -ne 0 ]; then
      echo "ERROR: Could not pull latest for the master branch"
      exit 1
   fi

   git checkout $branch
   git pull
   if [ $? -ne 0 ]; then
      echo "ERROR: Could not pull latest for the $branch branch"
      exit 1
   fi
}

############################################################
# Build make file dependencies for inc members 
############################################################
build_dependencies()
{
scandir=$1
filemask=$2
incdir=$3

cd $scandir

## - get all files with #include
## - for each line
##  - clean up the line
##  - remove extra chars from #include line
##  - look at each file and make sure it exists in the inc dir
##  - print a make file line for the .h showing dependencies
#
grep \#include $filemask 2>/dev/null |
grep -v memsqlgrammar.tab.c |
grep -v memsqllexer.c |
grep -v XPathGrammer.tab.c |
grep -v xmlSQL.tab.c |
grep -v lex.yy.c |
sed 's/#include//g' |
tr "<>\":" "    " | 
( while read i ; do
   # Put the line into an array
   #set -A lne $i
   lne=($i)

   if [ -f $INCDIR/${lne[1]} ]; then
      echo $i
   fi
done ) |
awk 'BEGIN { prev="xx"; }
     { 
       if ( $1 == prev ) 
          printf " ../inc/%s", $2; 
       else {
          if ( prev != "xx" )
             printf "\n\ttouch ZZincZZ%s\n", prev
	     
          printf "\nZZincZZ%s: ../inc/%s", $1,$2; 
       }
       prev = $1 
     } 
     END { 
        printf "\n" 
        printf "\ttouch ZZincZZ%s\n", prev 
     }' |
sed "s/ZZincZZ/$incdir/g"

}

############################################################
# Update the custom.mak file to include the src file dependencies
############################################################
update_custom_mak()
{
   echo "include $WRKDIR/dep_inc.mak" >>$SRCDIR/hhsct_custom.mak
   echo "include $WRKDIR/dep_src.mak" >>$SRCDIR/hhsct_custom.mak
}

############################################################
# Build a script that will make all of the exes 
############################################################
build_make_script()
{
src=$1
repodir=$2

   cd $src
   echo "#!/bin/ksh"
   echo ""
   echo "run_make()"
   echo "{"
   echo "gmake -f \$1 ../ubin/\$2 TESTDIR=$repodir >$WRKDIR/logs/\$1.out 2>&1"
   echo "if [ \$? -ne 0 ]; then"
   echo "  echo ERROR: gmake -f \$1 ../ubin/\$2 TESTDIR=$repodir"
   echo "  echo \"       log file is at: $WRKDIR/logs/\$1.out\" "
   echo "  echo \" \""
   echo "  let total_errs=\$total_errs+1"
   echo "  echo ERROR: \$1 \$2 >>$WRKDIR/logs/build_log.out"
   echo "else"
   echo "  echo SUCCESS: gmake -f \$1 ../ubin/\$2 TESTDIR=$repodir"
   echo "  echo SUCCESS: \$1 \$2 >>$WRKDIR/logs/build_log.out"
   echo "fi"
   echo "}"
   echo "total_errs=0"
   echo "cd $src"
   echo "cat /dev/null >$WRKDIR/logs/build_log.out"
   echo ""

   # This will create dummy libraries for everything in the system.  
   # This allows everything to compile/link so we do not have to deal with
   # curcular dependencies between all the libraries in the system.
   ls -1r libcircular*.mak 2>/dev/null | 
   awk '{printf "run_make %s %s\n", $1, substr($1,1,length($1)-4)}'
   echo ""

   # Now try to build all the libraries in the system
   ls -1r lib*.mak 2>/dev/null | 
   egrep -v 'custom.mak|claimList.mak|dsspmbmeascrit.mak|tmsis_dflt.mak|dsksdflt.mak|libcircular' |
   awk '{printf "run_make %s %s\n", $1, substr($1,1,length($1)-4)}'
   echo ""

   #first run the critical library make files
   #ls -1r lib*.mak 2>/dev/null | 
   #egrep -v 'custom.mak|claimList.mak|dsspmbmeascrit.mak|tmsis_dflt.mak|dsksdflt.mak|libcircular' |
   #egrep 'libxml.so.mak|libeutil.so.mak|libgutils.so.mak|libadjcomm.so.mak|libclmwrite.so.mak|libclaims.so.mak' |
   #awk '{printf "run_make %s %s\n", $1, substr($1,1,length($1)-4)}'
   #echo ""

   #next run the remaining library make files
   #ls -1 lib*.mak 2>/dev/null | 
   #egrep -v 'custom.mak|claimList.mak|dsspmbmeascrit.mak|tmsis_dflt.mak|dsksdflt.mak|libcircular' |
   #egrep -v 'libxml.so.mak|libeutil.so.mak|libgutils.so.mak|libadjcomm.so.mak|libclmwrite.so.mak|libclaims.so.mak' |
   #awk '{printf "run_make %s %s\n", $1, substr($1,1,length($1)-4)}'
   #echo ""

   #finally run everything else
   ls -1 *.mak | 
   egrep -v 'custom.mak|claimList.mak|dsspmbmeascrit.mak|tmsis_dflt.mak|dsksdflt.mak' |
   egrep -v '^lib' |
   awk '{printf "run_make %s %s\n", $1, substr($1,1,length($1)-4)}'
   echo ""

   echo "if [ \$total_errs -ne 0 ]; then"
   echo "  echo ERROR: could not build \$total_errs programs"
   echo "  exit 1"
   echo "fi"
}


############################################################
# Run the build!
############################################################
run_build()
{
repdir=$1
srcdir=$2
appname=$3

   echo "INFO: running the build"
   cd $repdir/$appname
   if [ ! -h ubin ]; then
      ln -s $WRKDIR/ubin ubin
      ln -s $WRKDIR/uobj uobj
   fi

   mkdir -p $WRKDIR/ubin
   mkdir -p $WRKDIR/uobj
   mkdir -p $WRKDIR/logs

   #AIM_PSWD=`grep ^AIM_PSWD= $AIM_CONFIG | awk -F= '{print $2}'`

   cd $srcdir
   echo "$WRKDIR/buildall.sh"
   $WRKDIR/buildall.sh
   if [ $? -ne 0 ]; then
      echo "ERROR: build was successful -- continue anyways"
      ##exit 1
   fi
}
cp_exec()
{
  repdir=$1
  srcdir=$2
  appname=$3

  echo "INFO: copy $WRKDIR/ubin to $repdir/$appname/ubin"
  cd $repdir/$appname
  cp $WRKDIR/ubin/ ubin
  if [ $? -ne 0 ]; then
      echo "ERROR: Copy failed"
      exit 1
   fi
} 

############################################################
############################################################
print_usage()
{
   echo "Usage: devops_ci_build.sh -b branch_name"
   exit 1
}

############################################################
# 
############################################################
set -a

repo_name=""
full_branch_name=""
git_rep_url=""
first_clone="Y"

while getopts b:f:r:g: c;do
   case $c in
      b)
         branch_name=$OPTARG
         ;;

      f)
         full_branch_name=`echo $OPTARG|sed 's/refs\/heads\///g'`
         ;;

      r)
         repo_name=`echo $OPTARG|sed 's/ /_/g'`
         ;;

      g)
         git_rep_url=$OPTARG
         ;;
  
      *)
         print_usage $0
         exit 1
         ;;
   esac
done

if [ -z "$branch_name" -o -z ${git_rep_url} -o -z ${full_branch_name} -o -z ${repo_name} ]; then
   print_usage $0
   exit 1
fi



APP_MODIFIER=""

#set -a application cmnc clmc finc mbrc prvc tplc
application=("cmnc" "clmc" "finc" "mbrc" "prvc" "tplc")

for i in ${application[@]};
do
  case $i in
    cmnc) APPNAME=Common;APP_MODIFIER="-C";echo "APPNAME:$APPNAME"
          ;;
    clmc) APPNAME=M2_Claims;APP_MODIFIER="-C";echo "APPNAME:$APPNAME"
          ;;
    finc) APPNAME=M5_Dashboard;APP_MODIFIER="-C";echo "APPNAME:$APPNAME"
          ;;
    mbrc) APPNAME=M7_KEES;APP_MODIFIER="-C";echo "APPNAME:$APPNAME"
          ;;
    prvc) APPNAME=M3_Provider;APP_MODIFIER="-C";echo "APPNAME:$APPNAME"
          ;;
    tplc) APPNAME=M5_TPL;APP_MODIFIER="-C";echo "APPNAME:$APPNAME"
          ;;
    *)
        print_usage $0
        exit 1
        ;;
  esac

  set

  ## Read in the standard environment
  tty -s
  if [ $? -ne 0 ]; then
     . /etc/profile 2>/dev/null
     . ~/.profile 2>/dev/null
   fi

   # Move to the baseline build directory
   BASEDIR1=/dsks/utils/devops/build_${repo_name}_${branch_name}
   mkdir -p $BASEDIR1
   if [ $? -ne 0 ]; then
      echo "ERROR: Could not create $BASEDIR1"
      exit 1
   fi

   cd $BASEDIR1

   REPURL=${git_rep_url}
   WRKDIR=$BASEDIR1/out/$APPNAME
   mkdir -p $WRKDIR
   REPDIR=$BASEDIR1/${repo_name}
   SRCDIR=$BASEDIR1/${repo_name}/$APPNAME/src
   INCDIR=$BASEDIR1/${repo_name}/$APPNAME/inc

   if [[ ! -d $REPDIR/.git && $first_clone = "Y" ]]; then
      create_repository
      first_clone="N"
   fi

   clean_repository $REPDIR $full_branch_name $APPNAME
   if [ $first_clone = "Y" ]; then
      first_clone="N"
      get_latest_repository $REPDIR $full_branch_name
   fi

   echo "INFO: Building .h make file dependencies"
   Build_dependencies $INCDIR \*.h ..\\/inc\\/ >$WRKDIR/dep_inc.mak

   echo "INFO: Building .c make file dependencies"
   build_dependencies $SRCDIR \*.c '' >$WRKDIR/dep_src.mak

   echo "INFO: Building .sc make file dependencies"
   build_dependencies $SRCDIR \*.sc '' >>$WRKDIR/dep_src.mak

   update_custom_mak $SRCDIR
   echo "INFO: Building make file script"
   build_make_script $SRCDIR $REPDIR >$WRKDIR/buildall.sh
   chmod 755 $WRKDIR/buildall.sh

   set 

   run_build $REPDIR $SRCDIR $APPNAME
   #cp_exec $REPDIR $SRCDIR $APPNAME

   echo ""
   echo ""
   echo "-----------------------------------------------------------------"
   echo "Module $APPNAME SUCCESS!"
   echo "-----------------------------------------------------------------"
done

