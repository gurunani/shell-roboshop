#!/bin/bash

# AWS Variables
AMI_ID="ami-09c813fb71547fc4f"
SG_ID="sg-00dc811cc4361c4b9"        # replace with your SG ID
ZONE_ID="Z032558618100M4EJX8X4"    # replace with your Zone ID
DOMAIN_NAME="gurulabs.xyz"          # replace with your domain

# Instances to create
INSTANCES=("mongodb" "redis" "mysql" "rabbitmq" "catalogue" "user" "cart" "shipping" "payment" "dispatch" "frontend")

# Loop through each instance
for instance in "${INSTANCES[@]}"
do
    echo "Launching instance: $instance"

    # Run instance
    INSTANCE_ID=$(aws ec2 run-instances \
        --image-id $AMI_ID \
        --instance-type t3.micro \
        --security-group-ids $SG_ID \
        --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$instance}]" \
        --query "Instances[0].InstanceId" \
        --output text)

    echo "Instance $instance launched with ID: $INSTANCE_ID"

    # Wait for instance to be running
    aws ec2 wait instance-running --instance-ids $INSTANCE_ID
    echo "Instance $instance is running."

    # Get IP address
    if [ "$instance" != "frontend" ]; then
        IP=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID \
            --query "Reservations[0].Instances[0].PrivateIpAddress" --output text)
        RECORD_NAME="$instance.$DOMAIN_NAME"
    else
        IP=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID \
            --query "Reservations[0].Instances[0].PublicIpAddress" --output text)
        RECORD_NAME="$DOMAIN_NAME"
    fi

    echo "$instance IP address: $IP"

    # Update Route 53 record
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
                    \"ResourceRecords\": [{\"Value\": \"$IP\"}]
                }
            }]
        }"

    echo "Route 53 record updated for $RECORD_NAME -> $IP"
    echo "-----------------------------------------------"
done

echo "All instances launched and DNS records updated successfully!"
