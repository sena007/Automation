#!/bin/ksh
set -x

########################################################################
#
########################################################################
print_usage()
{
   echo "Usage: devops_ci_build_2.sh -b branch_name"
   echo ""
   exit 1
}

########################################################################
#
########################################################################

set -a
repo_name=""

while getopts b:r: c;do
   case $c in
      b)
	 branch_name=$OPTARG
	 ;;

      r)
	 repo_name=`echo $OPTARG|sed 's/ /_/g'`
	 ;;

      *)
	 print_usage $0
         exit 1
	 ;;
   esac
done

if [ -z "$branch_name" ]; then
   print_usage $0
   exit 1
fi

## Read in the standard environment
tty -s
if [ $? -ne 0 ]; then
  . /etc/profile 2>/dev/null
  . ~/.profile 2>/dev/null
fi

##
# Set standard envs
##
BASEDIR=/dsks/utils/devops/build_${repo_name}_${branch_name}

# move to the base directory
echo "INFO: Zipping up the build artifacts"
cd $BASEDIR/${repo_name}
echo "INFO: Changing to `pwd`"

# Undo changes to the custom make so we do not distribute that version!
#git checkout src/hhsct_custom.mak

# Determine the list of dirs to tar up

# Extract the source files
/bin/rm -f buildartifacts.*
/bin/rm -f ../buildartifacts.tar.gz
#echo $dirlist
find * -maxdepth 1 -type d | xargs -I'{}' tar -rvf ../buildartifacts.tar '{}' >/dev/null 2>&1
tar -f ../buildartifacts.tar --delete Common/uobj Common/ubin M2_Claims/uobj M2_Claims/ubin M3_Provider/uobj M3_Provider/ubin M5_Dashboard/uobj M5_Dashboard/ubin M5_TPL/uobj M5_TPL/ubin M7_KEES/uobj M7_KEES/ubin
if [ $? -ne 0 ]; then
   echo "ERROR: could not tar/zip up the build artifacts"
   exit 1
fi

#set -A application cmnc clmc finc mbrc prvc tplc

application=("cmnc" "clmc" "finc" "mbrc" "prvc" "tplc")

for i in ${application[@]};
do
  case $i in
    cmnc) APPNAME=Common;APP_MODIFIER="-C";echo "APPNAME:$APPNAME";
          tar -rhvf ../buildartifacts.tar $APPNAME/ubin
          if [ $? -ne 0 ]; then
              echo "ERROR: could not tar ubin in $APPNAME directory"
              exit 1
          fi

          ;;
    clmc) APPNAME=M2_Claims;APP_MODIFIER="-C";echo "APPNAME:$APPNAME";
          tar -rhvf ../buildartifacts.tar $APPNAME/ubin
          if [ $? -ne 0 ]; then
              echo "ERROR: could not tar ubin in $APPNAME directory"
              exit 1
          fi
          ;;
    finc) APPNAME=M5_Dashboard;APP_MODIFIER="-C";echo "APPNAME:$APPNAME";
          tar -rhvf ../buildartifacts.tar $APPNAME/ubin
          if [ $? -ne 0 ]; then
              echo "ERROR: could not tar ubin in $APPNAME directory"
              exit 1
          fi
          ;;
    mbrc) APPNAME=M7_KEES;APP_MODIFIER="-C";echo "APPNAME:$APPNAME";
          tar -rhvf ../buildartifacts.tar $APPNAME/ubin
          if [ $? -ne 0 ]; then
              echo "ERROR: could not tar ubin in $APPNAME directory"
              exit 1
          fi
          ;;
    prvc) APPNAME=M3_Provider;APP_MODIFIER="-C";echo "APPNAME:$APPNAME";
          tar -rhvf ../buildartifacts.tar $APPNAME/ubin
          if [ $? -ne 0 ]; then
              echo "ERROR: could not tar ubin in $APPNAME directory"
              exit 1
          fi
          ;;
    tplc) APPNAME=M5_TPL;APP_MODIFIER="-C";echo "APPNAME:$APPNAME";
          tar -rhvf ../buildartifacts.tar $APPNAME/ubin
          if [ $? -ne 0 ]; then
              echo "ERROR: could not tar ubin in $APPNAME directory"
              exit 1
          fi
          ;;
    *)
        print_usage $0
        exit 1
        ;;
  esac
done

echo gzip buildartifacts.tar
gzip ../buildartifacts.tar
if [ $? -ne 0 ]; then
   echo "ERROR: could not gzip up the buildartifacts.tar"
   exit 1
fi



# move to logs and tar/zip them up
cd ../out
echo "INFO: Changing to `pwd`"
/bin/rm -f ../buildlogs.tar.gz

for i in ${application[@]};
do
  case $i in
    cmnc) APPNAME=Common;APP_MODIFIER="-C";echo "APPNAME:$APPNAME";
          tar -chvf ../buildlogs.tar $APPNAME/logs >/dev/null 2>&1 
          if [ $? -ne 0 ]; then
              echo "ERROR: could not tar logs in $APPNAME directory"
              exit 1
          fi

          ;;
    clmc) APPNAME=M2_Claims;APP_MODIFIER="-C";echo "APPNAME:$APPNAME";
          tar -rhvf ../buildlogs.tar $APPNAME/logs >/dev/null 2>&1 
          if [ $? -ne 0 ]; then
              echo "ERROR: could not tar logs in $APPNAME directory"
              exit 1
          fi
          ;;
    finc) APPNAME=M5_Dashboard;APP_MODIFIER="-C";echo "APPNAME:$APPNAME";
          tar -rhvf ../buildlogs.tar $APPNAME/logs >/dev/null 2>&1 
          if [ $? -ne 0 ]; then
              echo "ERROR: could not tar logs in $APPNAME directory"
              exit 1
          fi
          ;;
    mbrc) APPNAME=M7_KEES;APP_MODIFIER="-C";echo "APPNAME:$APPNAME";
          tar -rhvf ../buildlogs.tar $APPNAME/logs >/dev/null 2>&1 
          if [ $? -ne 0 ]; then
              echo "ERROR: could not tar logs in $APPNAME directory"
              exit 1
          fi
          ;;
    prvc) APPNAME=M3_Provider;APP_MODIFIER="-C";echo "APPNAME:$APPNAME";
          tar -rhvf ../buildlogs.tar $APPNAME/logs >/dev/null 2>&1 
          if [ $? -ne 0 ]; then
              echo "ERROR: could not tar logs in $APPNAME directory"
              exit 1
          fi
          ;;
    tplc) APPNAME=M5_TPL;APP_MODIFIER="-C";echo "APPNAME:$APPNAME";
          tar -rhvf ../buildlogs.tar $APPNAME/logs >/dev/null 2>&1
          if [ $? -ne 0 ]; then
              echo "ERROR: could not tar logs in $APPNAME directory"
              exit 1
          fi
          ;;
    *)
        print_usage $0
        exit 1
        ;;
  esac
done

echo gzip buildlogs.tar
gzip ../buildlogs.tar >/dev/null 2>&1
if [ $? -ne 0 ]; then
   echo "ERROR: could not gzip up the buildlogs.tar"
   exit 1
fi

echo "INFO: completed successfully at `date`"

exit 0

