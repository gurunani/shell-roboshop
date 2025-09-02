#!/bin/bash

# mention instance id after sudo sh 04-roboshop-working-gpt.sh  [mongodb" "redis" "mysql" "rabbitmq" "catalogue" "user" "cart" "shipping" "payment" "dispatch" "frontend]

AMI_ID="ami-09c813fb71547fc4f"
SG_ID="sg-00dc811cc4361c4b9" 
INSTANCES=("mongodb" "redis" "mysql" "rabbitmq" "catalogue" "user" "cart" "shipping" "payment" "dispatch" "frontend")
ZONE_ID="Z032558618100M4EJX8X4"
DOMAIN_NAME="gurulabs.xyz"
KEY_NAME="redchip"

for instance in "${INSTANCES[@]}"
do
    echo "Processing instance: $instance"

    # Find existing running instance by Name tag
    INSTANCE_ID=$(aws ec2 describe-instances \
        --filters "Name=tag:Name,Values=$instance" "Name=instance-state-name,Values=running" \
        --query "Reservations[0].Instances[0].InstanceId" \
        --output text)

    if [ "$INSTANCE_ID" == "None" ] || [ -z "$INSTANCE_ID" ]; then
        echo "⚠️ No running instance found for $instance → launching a new one..."
        INSTANCE_ID=$(aws ec2 run-instances \
            --image-id $AMI_ID \
            --instance-type t3.micro \
            --security-group-ids $SG_ID \
            --key-name $KEY_NAME \
            --tag-specifications "ResourceType=instance,Tags=[{Key=Name, Value=$instance}]" \
            --query "Instances[0].InstanceId" \
            --output text)
        echo "$instance instance created with ID: $INSTANCE_ID"
        aws ec2 wait instance-running --instance-ids $INSTANCE_ID
        sleep 10
    else
        echo "✅ Found running instance: $INSTANCE_ID for $instance"
    fi

    # Fetch latest IP
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

    echo "$instance current IP: $IP"

    # Update Route53 record with TTL=1
    aws route53 change-resource-record-sets \
        --hosted-zone-id $ZONE_ID \
        --change-batch "{
            \"Comment\": \"Updating DNS for $instance\",
            \"Changes\": [{
                \"Action\": \"UPSERT\",
                \"ResourceRecordSet\": {
                    \"Name\": \"$RECORD_NAME\",
                    \"Type\": \"A\",
                    \"TTL\": 1,
                    \"ResourceRecords\": [{ \"Value\": \"$IP\" }]
                }
            }]
        }"

    echo "✅ DNS record updated: $RECORD_NAME -> $IP (TTL=1)"
    echo "--------------------------------------------------"
done
