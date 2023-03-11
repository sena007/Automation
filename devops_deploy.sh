#!/bin/ksh

########################################################################
#
########################################################################
print_usage()
{
   echo "Usage: devops_deploy.sh -e env_name -b branch_name"
   echo ""
   exit 1
}
set_permission()
{
     ## Set the proper perms on the files
     echo "INFO: Set permissions on job/ubin directories from `pwd`"

     for i in job ubin ; do
        find $i -type f  -exec chmod 755 {} \;
        find $i -type d  -exec chmod 755 {} \;
     done

     echo "INFO: Set permissions on inc src jil sysin directories from `pwd`"
     for i in inc jil src sysin sql; do
        find $i -type f  -exec chmod 644 {} \;
        find $i -type d  -exec chmod 755 {} \;
     done

}

########################################################################
########################################################################

while getopts e:b:r: c;do
   case $c in
      e)
	 env_name=$OPTARG
	 ;;

      b) 
	 branch_name=$OPTARG
	 ;;

      r) 
	 repo_name=$OPTARG
	 ;;

      *)
	 print_usage $0
   esac
done

if [ -z "$env_name" -o -z "$branch_name" ]; then
   print_usage $0
   exit 1
fi

# Setup the environment
tty -s
if [ $? -ne 0 ]; then
  . /etc/profile >/dev/null 2>&1
  . ~/.profile >/dev/null 2>&1
fi

DEPLOY_DIR=/dsks/${env_name}/ado_deploy
DEVOPS_DIR=/dsks/utils/devops/deploy_${repo_name}_${branch_name}

if [ ! -d $DEPLOY_DIR ]; then
   echo "ERROR: the deployment directory does not exist: $DEPLOY_DIR"
   exit 1
fi

if [ ! -d $DEVOPS_DIR ]; then
   echo "ERROR: the devops directory does not exist: $DEVOPS_DIR"
   exit 1
fi

## Move to the working directory for the deployment
echo "INFO: Deploy into $DEPLOY_DIR"
cd $DEPLOY_DIR

## Unzip the files
echo "INFO: untar $DEVOPS_DIR/buildartifacts.tar.gz"
tar xf $DEVOPS_DIR/buildartifacts.tar.gz
if [ $? -ne 0 ]; then
  echo "ERROR: could not unzip buildartifacts.tar.gz"
  exit 1
fi

application=("cmnc" "clmc" "finc" "mbrc" "prvc" "tplc")

for i in ${application[@]};
do
    case $i in
        cmnc) APPNAME=Common;echo "APPNAME:$APPNAME";
              cd $APPNAME
              set_permission
              if [ $? -ne 0 ]; then
                  echo "ERROR: set_permission failed for $APPNAME directory"
                  exit 1
              fi

              ;;
	clmc) APPNAME=Common;echo "APPNAME:$APPNAME";
              cd $APPNAME
              set_permission
              if [ $? -ne 0 ]; then
                  echo "ERROR: set_permission failed for $APPNAME directory"
                  exit 1
              fi

              ;;
	finc) APPNAME=Common;echo "APPNAME:$APPNAME";
              cd $APPNAME
              set_permission
              if [ $? -ne 0 ]; then
                  echo "ERROR: set_permission failed for $APPNAME directory"
                  exit 1
              fi

              ;;
	mbrc) APPNAME=Common;echo "APPNAME:$APPNAME";
              cd $APPNAME
              set_permission
              if [ $? -ne 0 ]; then
                  echo "ERROR: set_permission failed for $APPNAME directory"
                  exit 1
              fi

              ;;
	prvc) APPNAME=Common;echo "APPNAME:$APPNAME";
              cd $APPNAME
              set_permission
              if [ $? -ne 0 ]; then
                  echo "ERROR: set_permission failed for $APPNAME directory"
                  exit 1
              fi

              ;;
	tplc) APPNAME=Common;echo "APPNAME:$APPNAME";
              cd $APPNAME
              set_permission
              if [ $? -ne 0 ]; then
                  echo "ERROR: set_permission failed for $APPNAME directory"
                  exit 1
              fi

              ;;
        *)
              print_usage $0
              exit 1
              ;;
    esac
done

echo "SUCCESS!"
exit 0
