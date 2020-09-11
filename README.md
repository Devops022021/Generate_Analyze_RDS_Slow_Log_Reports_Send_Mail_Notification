# Generate_Analyze_RDS_Slow_Log_Reports_Send_Mail_Notification
This shell script is belongs to Download Slow Query logs from RDS to EC2 server, Analyze Slow Query logs and generate a report and send mail notification for all RDS instances which is running in all Regions


Pre-requeste :- 

(1) Create 2 files under script folder , files name called ignore_list and Regions_Properties.txt  

cat ignore_list
db1
db4
db5

cat Regions_Properties.txt

us-east-1
us-west-2
us-west-1
us-east-2
