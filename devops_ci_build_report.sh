#!/bin/ksh


###############################
# Get overall stats on the build process
###############################
print_overall_stats()
{
total_error=`grep ERROR: $build_log|wc -l`
total_success=`grep SUCCESS: $build_log|wc -l`
total_pgms=`cat $build_log|wc -l`

echo ""
echo "#BUILD REPORT - $account - `date`"
echo ""
echo "##Overall Build Stats"
#echo "-----
echo '```'
echo "$total_success $total_pgms" | gawk '{printf "   SUCCESS: %4d %s%%\n", $1, int(($1/$2+.005) * 100)}'
echo "$total_error $total_pgms"   | gawk '{printf "   FAILURE: %4d %s%%\n", $1, int(($1/$2+.005) * 100)}'
echo "            ----"
echo "$total_pgms" | gawk '{printf "            %4d\n", $1}'
echo '```'
}

###############################
# Print stats by owner
###############################
print_owner_stats()
{
owner=$1
prefix=$2
not=$3

total_pgms=`cat $build_log|egrep $not " $prefix"|wc -l`
total_error=`grep ERROR: $build_log|egrep $not " $prefix"|wc -l`
total_success=`grep SUCCESS: $build_log|egrep $not " $prefix"|wc -l`

echo ""
echo "**${owner}**"


if [ $total_pgms -eq 0 ]; then
   total_pgms=1
fi

echo '```'
echo "$total_success $total_pgms" | gawk '{printf "   SUCCESS: %4d %s%%\n", $1, int(($1/$2+.005) * 100)}'
echo "$total_error $total_pgms"   | gawk '{printf "   FAILURE: %4d %s%%\n", $1, int(($1/$2+.005) * 100)}'

echo "            ----"
echo "$total_pgms" | gawk '{printf "            %4d\n", $1}'
echo '```'
}

###############################
# Print stats by error
###############################
print_error_stats()
{
   # PRO*C Errors
   echo ""
   echo "**PRO*C Build Errors**"
   echo '```'
   grep -h PCC-S ${build_dir}/*.mak.* | sort | uniq -c | sort -rn
   echo '```'

   # C Compile Errors
   echo ""
   echo "**C Compiler Errors**"
   echo '```'
   egrep -h '/bin/ld: cannot|error:' ${build_dir}/*.mak.* | egrep -v 'ld returned 1' | sed 's/.*://g' | sort | uniq -c | sort -rn 
   echo '```'

}

########################################
## main
########################################


if [ $# -ne 3 ]; then
   echo "Usage: $0 repository_name branch_name account_name"
   exit 1
fi

build_dir=/dsok/utils/devops/build_${1}_${2}/out/logs
build_log=${build_dir}/build_log.out
owner_list=/dsok/utils/devops/build_${1}_${2}/${1}/linux_port_owners.txt
account=$3

if [ ! -f $owner_list ]; then
   touch $owner_list
fi

## Get the overall statistics
print_overall_stats

## Determine the list of owners
all_owners=/tmp/assigned.txt.$$

grep -v "^#" $owner_list |
awk '{print $1}' |
sort | 
uniq >$all_owners

## Print stats for each owner
echo ""
echo ""
echo "##Owner Build Stats"
for owner in `cat $all_owners`; do
   owner_prefixes=`grep -v "^#" $owner_list | grep ^$owner | awk 'BEGIN{OR=""} {printf "%s%s", OR, $2;OR="|"}'`
   print_owner_stats $owner "$owner_prefixes"
done

## Print stats for all unassigned sections
all_prefixes=`grep -v "^#" $owner_list | awk 'BEGIN{OR=""} {printf "%s%s", OR, $2;OR="|"}'`
print_owner_stats "unassigned" $all_prefixes "-v"

## Print owner assignments
echo ""
echo ""
echo "##Owner Assignment List"
echo ""
echo '```'
for owner in `cat $all_owners`; do
   owner_prefixes=`grep -v "^#" $owner_list | grep ^$owner | awk 'BEGIN{OR=""} {printf "%s%s", OR, $2;OR="|"}'`
   echo "$owner - ( $owner_prefixes )"
done

echo "unassigned - ($unassigned_prefixes)"
grep ERROR: $build_log|
awk '{print $3}'|
cut -c-3|
sort|
uniq -c |
egrep -v " $all_prefixes" |
sort -rn
echo '```'

## Print overall error stats 
echo ""
echo ""
echo "##Common Compile Messages"
print_error_stats

# Clean up
/bin/rm -f $all_owners
