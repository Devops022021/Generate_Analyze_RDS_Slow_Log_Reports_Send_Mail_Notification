
#!/bin/bash

##############################################################################
# The below for loop is belongs to get list of RDS instances based on the    #
# regions properties file with exclude list of RDS's which we mentioned in   #
# the below command                                                          #
##############################################################################

for region in `cat /home/rds_logs/Regions_Properties.txt`;
do
cd /home/rds_logs
/usr/local/bin/aws --region="$region" rds describe-db-instances | jq ' .DBInstances[] | select( .Engine ) | .DBInstanceIdentifier ' | awk '{ print $1, $2 }' | sed 's/\"//g' | sed 's/,/ /g' | sed 's/://g' | egrep -vf ignore_list > /home/rds_logs/list
cat /home/rds_logs/list

###########################################################################################################
#The below for loop is belongs to Dir creation as per the date folder based on the RDS's from list file   #
###########################################################################################################

DATE=$(date +'%d-%m-%Y')
LSTINST="/home/rds_logs/list"

for i in $(cat $LSTINST)
#for i in $(cat $LSTINST | tail)
do
  if [ -d /home/rds_logs/${i}/${DATE} ]
   then
    echo "Directory is already existed"
    else
    mkdir -p /home/rds_logs/${i}/${DATE}
    fi
    log_files=`/usr/local/bin/aws --region="$region" rds describe-db-log-files --db-instance-identifier  $i | grep slowquery | awk '{ print $2 }' | sed 's/\"//g' | sed 's/,//g' | sort -V | tail -1`
    log_files=`/usr/local/bin/aws --region="$region" rds describe-db-log-files --db-instance-identifier  $i | grep slowquery | awk '{ print $2 }' | sed 's/\"//g' | sed 's/,//g' | sort -V`

#################################################################################
#The below again for loop is belongs to load a mysql slow logs files based      #
#on the list and copy in to each RDS --> corrensponding Date folder             #
#################################################################################

YDATE=`date --date "-1 days" +'%d-%m-%Y'`
REPORTFOLDER='/home/rds_logs/Slow_Log_Reports/'

  for j in $log_files
  do
   k=`echo $j | cut -d/ -f2`
   /usr/local/bin/aws --region="$region" rds download-db-log-file-portion --db-instance-identifier $i --log-file-name $j --output text > /home/rds_logs/${i}/${DATE}/${k}
   echo "/home/rds_logs/${i}/${DATE}/${k}"
  done

cd /home/rds_logs/${i}/${DATE}
cat mysql-slowquery.log* > mysql-slowquery-$YDATE.txt
pt-query-digest --group-by fingerprint --order-by Query_time:sum --attribute-value-limit=4294967296 /home/rds_logs/${i}/${DATE}/mysql-slowquery-$YDATE.txt > mysql_slowquery_${i}_report_$YDATE.txt

########################################################################
#The below part belongs to after generated slow log report by using    #
#above PT command , we are going to move final report file to another  #
#new folder                                                            #
########################################################################

REPORTFOLDER='/home/rds_logs/Slow_Log_Reports/'
mv mysql_slowquery_${i}_report_$YDATE.txt $REPORTFOLDER
find /home/rds_logs/${i} -mindepth 1 -maxdepth 1 -type d -ctime +3 | xargs rm -rf
done
done

###############################################################################
#Mail Notification to attache the final report with zip and sent to the team  #
###############################################################################

DATE1=$(date +'%Y-%m-%d')

# Recipient
#CC="mailid_1 mailid_2"
#RECIP="mailid_1 mailid_2"
#echo "$DATE1" | mailx -a $DATE1.zip -s "Slow Logs Report for All Development RDS Instances" -c "$CC" $RECIP
CC="mailid_1 mailid_2"
RECIP="mailid_1 mailid_2"

cd /home/rds_logs/Slow_Log_Reports/
rm -rf slow_report_$(date +"%Y-%m-%d").log

cd /home/rds_logs/Slow_Log_Reports/
for i in $(find -type f -newermt `date +%Y-%m-%d` -name "*.txt")
do
count=`grep -i "Exec time" ${i} | wc -l`
if [ ${count} -gt 0 ]
then
echo DATABASE: >>slow_report_$(date +"%Y-%m-%d").log
echo $i |cut -d'_' -f 3 |tr [a-z] [A-Z] >>slow_report_$(date +"%Y-%m-%d").log
cat $i >>slow_report_$(date +"%Y-%m-%d").log
echo  >>slow_report_$(date +"%Y-%m-%d").log
echo  >>slow_report_$(date +"%Y-%m-%d").log
echo  >>slow_report_$(date +"%Y-%m-%d").log
fi
done

echo "Please Find Attachment for $YDATE Slow Queries Report for all Production RDS instances " | cat /home/rds_logs/Slow_Log_Reports/slow_report_$(date +"%Y-%m-%d").log |mailx -s "Slow Logs Report for All Production RDS Instances" -r "slowquery@message.gmail.com" -c "$CC" $RECIP

find /home/rds_logs/Slow_Log_Reports/mysql_slowquery* -mtime +5 -exec rm {} \;
find /home/rds_logs/Slow_Log_Reports/slow_report_* -mtime +5 -exec rm {} \;
