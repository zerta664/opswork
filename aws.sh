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

	/bin/rm -f /tmp/ami_id
	/bin/rm -f /tmp/snapshots.txt

for day in {7..10}
do
		DEL="$(date +%Y-%m-%d --date "$day days ago")"

		aws ec2 describe-images --owners 717986625066  --filter "Name=name,Values=*"$DEL"*" | \
		 grep "ImageId" | awk '{print $2}'|cut -d '"' -f 2 >>/tmp/ami_id

	for ami in `cat /tmp/ami_id`
	do
		aws ec2 describe-images --owners 717986625066  --image-ids $ami | \
		 grep snap | awk ' { print $2 }' >> /tmp/snapshots.txt

		aws  ec2 deregister-image --image-id $ami
		##If you want delete snapshot  for s in `cat /tmp/snapshots.txt`;do aws ec2 delete-snapshot --snapshot-id $s ; done
	done		

done


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
