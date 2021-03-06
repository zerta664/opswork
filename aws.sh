#!/bin/bash

#############################################
## The file /root/instname contains subdomains
##Determine IP addresses, status of instanses 
##and ID of stopped EC2 instances
############################################

for i in `cat /root/instname`
do
	echo -e "DNS name: $i\n"

	address=`/usr/bin/nslookup $i | grep Address| grep -v "#53" |awk '{print $2}'`

	echo -e  "PublicIP: $address\n"

	#aws ec2 describe-instances  --filter "Name=ip-address,Values=$address" \
	# --query "Reservations[].Instances[][PublicIpAddress, State.Name, InstanceId]" 
	echo -e "State:"

	aws ec2 describe-instances  --filter "Name=ip-address,Values=$address" \
	 --query "Reservations[].Instances[][State.Name]" | grep '[a-zA-Z]'

	/usr/bin/nc -w 2 -v $i  22 </dev/null; echo $?

	HTTP_STATUS="$(curl -IL --silent $i | grep HTTP )";
	echo "${HTTP_STATUS}";

	stop_id=`aws ec2 describe-instances  --filter "Name=ip-address,Values=$address" "Name=instance-state-code,Values=80" --query "Reservations[].Instances[][InstanceId]" | grep '[a-zA-Z]' |cut -d '"' -f 2`

	stop_name=`aws ec2 describe-instances  --filter "Name=ip-address,Values=$address" "Name=instance-state-code,Values=80" --query "Reservations[].Instances[][Tags[?Key=='Name'].Value]" | grep '[a-zA-Z]' |cut -d '"' -f 2`

done

	echo -e "ID of the stopped instance: $stop_id \n"

	echo -e "Name of the stopped instance: $stop_name \n"

	aws ec2 create-image --instance-id $stop_id --name "$stop_name-`date '+%Y-%m-%d'`"


################################
##Delete old images
#######################################

	cat /dev/null > /tmp/snapshots.txt


	aws ec2 describe-images --owners 717986625066  --query 'Images[*].[CreationDate]' --output text > /tmp/time

	cat /root/time | rev | cut -c 6- | rev > /tmp/time2
	
	ago=$(date '+%Y-%m-%dT%H:%M:%S' --date "7 days ago")
for ts  in `cat /tmp/time2`
do
    if [[ "$ago" > "$ts" ]] ;

    then

	aws ec2 describe-images --owners 717986625066  --query 'Images[*].[ImageId,CreationDate]' --output text | `
        ` grep "$ts" | awk '{print $1}' | xargs aws ec2 describe-images  --image-ids | \
	grep snap | awk ' { print $2 }' >> /tmp/snapshots.txt

	aws ec2 describe-images --owners 717986625066  --query 'Images[*].[ImageId,CreationDate]' --output text | `
        ` grep "$ts" | awk '{print $1}' | xargs aws ec2 deregister-image   --image-id


   fi

done
	##If you want delete snapshot  for s in `cat /tmp/snapshots.txt`;do aws ec2 delete-snapshot --snapshot-id $s ; done
	
#####################Terminate stopped instance###########################

	aws ec2 terminate-instances --instance-ids $stop_id

###########################################################################

        HL=`tput smso`
        G=`tput setaf 2`
	K=`tput setaf 1`
	R=`tput sgr0`

for i in `cat /root/instname`
do
	address=`/usr/bin/nslookup $i | grep Address| grep -v "#53" |awk '{print $2}'`

	aws ec2 describe-instances  --filter "Name=ip-address,Values=$address" --query "Reservations[].Instances[][Tags[?Key=='Name'].Value, PublicIpAddress, InstanceId]" | grep -v "\[" | grep -v "\]"

	echo -e "$HL $G `aws ec2 describe-instances  --filter "Name=ip-address,Values=$address"  --query "Reservations[].Instances[][State.Name]" | grep '[a-zA-Z]'` $R \n ================== \n"
done


	echo -e " $stop_name \n $stop_id \n"
	echo $HL $K `aws ec2 describe-instances  --instance-id $stop_id  --query "Reservations[].Instances[][State.Name]" |grep '[a-zA-Z]'` $R
