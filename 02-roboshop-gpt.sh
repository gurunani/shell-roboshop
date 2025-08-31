#!/bin/bash

AMI_ID="ami-09c813fb71547fc4f"
SG_ID="sg-00dc811cc4361c4b9" # replace with your SG ID
INSTANCES=("mongodb" "redis" "mysql" "rabbitmq" "catalogue" "user" "cart" "shipping" "payment" "dispatch" "frontend")
ZONE_ID="Z032558618100M4EJX8X4" # replace with your ZONE ID
DOMAIN_NAME="gurulabs.xyz" # replace with your domain
KEY_NAME="your-keypair-name" # replace with your EC2 key pair name if SSH is needed

for instance in "${INSTANCES[@]}"
do
    echo "Launching instance: $instance"

    INSTANCE_ID=$(aws ec2 run-instances \
        --image-id $AMI_ID \
        --instance-type t3.micro \
        --security-group-ids $SG_ID \
        --key-name $KEY_NAME \
        --tag-specifications "ResourceType=instance,Tags=[{Key=Name, Value=$instance}]" \
        --query "Instances[0].InstanceId" \
        --output text)

    echo "$instance instance created with ID: $INSTANCE_ID"

    # Wait until the instance is running
    echo "Waiting for $instance to be in 'running' state..."
    aws ec2 wait instance-running --instance-ids $INSTANCE_ID

    # Small delay to ensure IP is assigned
    sleep 10

    if [ "$instance" != "frontend" ]; then
        IP=$(aws ec2 describe-instances \
            --instance-ids $INSTANCE_ID \
            --query "Reservations[0].Instances[0].PrivateIpAddress" \
            --output text)
        RECORD_NAME="$instance.$DOMAIN_NAME"
    else
        IP=$(aws ec2 describe-instances \
            --instance-ids $INSTANCE_ID \
            --query "Reservations[0].Instances[0].PublicIpAddress" \
            --output text)
        RECORD_NAME="$DOMAIN_NAME"
    fi

    echo "$instance IP address: $IP"

    aws route53 change-resource-record-sets \
        --hosted-zone-id $ZONE_ID \
        --change-batch "{
            \"Comment\": \"Creating or Updating a record set for $instance\",
            \"Changes\": [{
                \"Action\": \"UPSERT\",
                \"ResourceRecordSet\": {
                    \"Name\": \"$RECORD_NAME\",
                    \"Type\": \"A\",
                    \"TTL\": 60,
                    \"ResourceRecords\": [{
                        \"Value\": \"$IP\"
                    }]
                }
            }]
        }"

    echo "DNS record created/updated: $RECORD_NAME -> $IP"
    echo "--------------------------------------------------"

done
