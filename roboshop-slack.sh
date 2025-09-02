#!/bin/bash

AMI_ID="ami-09c813fb71547fc4f"
SECURITY_GROUP_ID="sg-0744e1600df4e870e"
HOSTED_ZONE_ID="Z07100922S6MUFRUIEXB8"
DOMAIN_NAME="pavithra.fun"
INSTANCE=("mongodb" "mysql" "redis" "rabbitMQ" "catalogue" "user" "cart" "shipping" "payment" "dispatch" "frontend")

for instance in $@
do
    INSTANCE_ID=$(aws ec2 run-instances --image-id $AMI_ID --instance-type t2.micro --security-group-ids $SECURITY_GROUP_ID --tag-specifications "ResourceType=instance,Tags=[{Key=Name, Value=$instance}]" --query "Instances[0].InstanceId" --output text)      
    if [ $instance != "frontend" ]
    then 
        IP=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID --query "Reservations[0].Instances[0].PrivateIpAddress" --output text)
        RECORD_NAME="$instance.$DOMAIN_NAME"
    else
        IP=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID --query "Reservations[0].Instances[0].PublicIpAddress" --output text)
        RECORD_NAME="$DOMAIN_NAME"
    fi
    echo "$instance IP address is: $IP"

    aws route53 change-resource-record-sets \
    --hosted-zone-id $HOSTED_ZONE_ID \
    --change-batch '
    {
        "Comment": "Creating a record set for cognito endpoint"
        ,"Changes": [{
         "Action"              : "CREATE"
        ,"ResourceRecordSet"  : {
         "Name"                 : "'$RECORD_NAME'"
         ,"Type"                : "A"
         ,"TTL"                 : 1
         ,"ResourceRecords"     : [{
            "Value"             : "'$IP'"
        }]
      }
    }]
  }'
done