#!/bin/bash

# Variables
USERID=$(id -u)
LOG_FILE=/var/log/rabbitmq-setup.log
SCRIPT_DIR=$PWD
R="\e[31m"
G="\e[32m"
N="\e[0m"

VALIDATE() {
  if [ $1 -eq 0 ]; then
    echo -e "$2 ... $G SUCCESS $N" | tee -a $LOG_FILE
  else
    echo -e "$2 ... $R FAILURE $N" | tee -a $LOG_FILE
    exit 1
  fi
}

# Check root access
if [ $USERID -ne 0 ]; then
  echo -e "$R ERROR: Run as root $N"
  exit 1
fi

# Copy repo file
if [ -f "$SCRIPT_DIR/rabbitmq.repo" ]; then
  cp $SCRIPT_DIR/rabbitmq.repo /etc/yum.repos.d/rabbitmq.repo &>>$LOG_FILE
  VALIDATE $? "Copying rabbitmq.repo"
else
  echo -e "$R ERROR: rabbitmq.repo not found in $SCRIPT_DIR $N" | tee -a $LOG_FILE
  exit 1
fi

# Install RabbitMQ
dnf install rabbitmq-server -y &>>$LOG_FILE
VALIDATE $? "Installing RabbitMQ"

# Start service
systemctl enable rabbitmq-server &>>$LOG_FILE
systemctl start rabbitmq-server &>>$LOG_FILE
VALIDATE $? "Starting RabbitMQ service"

# Wait for service
sleep 5

# Add application user
rabbitmqctl list_users | grep -q roboshop
if [ $? -ne 0 ]; then
  rabbitmqctl add_user roboshop roboshop123 &>>$LOG_FILE
  VALIDATE $? "Creating user roboshop"
else
  echo "User roboshop already exists, updating password" | tee -a $LOG_FILE
  rabbitmqctl change_password roboshop roboshop123 &>>$LOG_FILE
  VALIDATE $? "Updating user password"
fi

rabbitmqctl set_permissions -p / roboshop ".*" ".*" ".*" &>>$LOG_FILE
VALIDATE $? "Setting permissions for roboshop user"

echo -e "$G RabbitMQ setup completed successfully $N"
