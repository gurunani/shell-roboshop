#!/bin/bash

#------------------------#
# Variables
#------------------------#
USERID=$(id -u)
R="\e[31m"
G="\e[32m"
Y="\e[33m"
N="\e[0m"
LOGS_FOLDER="/var/log/roboshop-logs"
SCRIPT_NAME=$(echo $0 | cut -d "." -f1)
LOG_FILE="$LOGS_FOLDER/$SCRIPT_NAME.log"
SCRIPT_DIR=$PWD
APP_DIR="/app"
MONGO_HOST="mongodb.gurulabs.xyz"   # MongoDB host
NODE_VERSION="20"

#------------------------#
# Create Logs Folder
#------------------------#
mkdir -p $LOGS_FOLDER
echo "Script started at: $(date)" | tee -a $LOG_FILE

#------------------------#
# Root Check
#------------------------#
if [ $USERID -ne 0 ]; then
    echo -e "$R ERROR: Run as root $N" | tee -a $LOG_FILE
    exit 1
fi

#------------------------#
# Validate Function
#------------------------#
VALIDATE(){
    if [ $1 -eq 0 ]; then
        echo -e "$2 ... $G SUCCESS $N" | tee -a $LOG_FILE
    else
        echo -e "$2 ... $R FAILURE $N" | tee -a $LOG_FILE
        exit 1
    fi
}

#------------------------#
# Install Required Tools
#------------------------#
dnf install curl unzip -y &>>$LOG_FILE
VALIDATE $? "Installing curl and unzip"

#------------------------#
# Install NodeJS
#------------------------#
dnf module disable nodejs -y &>>$LOG_FILE
VALIDATE $? "Disabling default NodeJS"

dnf module enable nodejs:$NODE_VERSION -y &>>$LOG_FILE
VALIDATE $? "Enabling NodeJS $NODE_VERSION"

dnf install nodejs -y &>>$LOG_FILE
VALIDATE $? "Installing NodeJS $NODE_VERSION"

#------------------------#
# Application User
#------------------------#
id roboshop &>>$LOG_FILE
if [ $? -ne 0 ]; then
    useradd --system --home $APP_DIR --shell /sbin/nologin --comment "roboshop system user" roboshop &>>$LOG_FILE
    VALIDATE $? "Creating roboshop user"
else
    echo -e "roboshop user exists ... $Y SKIPPING $N"
fi

#------------------------#
# App Directory
#------------------------#
mkdir -p $APP_DIR
VALIDATE $? "Creating app directory"

#------------------------#
# Download & Setup App
#------------------------#
curl -o /tmp/catalogue.zip https://roboshop-artifacts.s3.amazonaws.com/catalogue-v3.zip &>>$LOG_FILE
VALIDATE $? "Downloading Catalogue"

rm -rf $APP_DIR/*
cd $APP_DIR
unzip /tmp/catalogue.zip &>>$LOG_FILE
VALIDATE $? "Unzipping Catalogue"

chown -R roboshop:roboshop $APP_DIR
VALIDATE $? "Setting ownership of /app"

#------------------------#
# Install Dependencies (as roboshop user)
#------------------------#
su -s /bin/bash roboshop -c "cd /app && npm install" &>>$LOG_FILE
VALIDATE $? "Installing NodeJS dependencies"

#------------------------#
# Setup Systemd Service
#------------------------#
cp $SCRIPT_DIR/catalogue.service /etc/systemd/system/catalogue.service
VALIDATE $? "Copying catalogue.service"

systemctl daemon-reload &>>$LOG_FILE
systemctl enable catalogue &>>$LOG_FILE
systemctl restart catalogue &>>$LOG_FILE
VALIDATE $? "Starting Catalogue service"

#------------------------#
# Install MongoDB Client
#------------------------#
cp $SCRIPT_DIR/mongo.repo /etc/yum.repos.d/mongo.repo
dnf install mongodb-mongosh -y &>>$LOG_FILE
VALIDATE $? "Installing MongoDB Client"

#------------------------#
# Load Master Data
#------------------------#
STATUS=$(mongosh --host $MONGO_HOST --quiet --eval 'db.getSiblingDB("catalogue").getCollectionNames().length')
if [ "$STATUS" -eq 0 ]; then
    mongosh --host $MONGO_HOST </app/db/master-data.js &>>$LOG_FILE
    VALIDATE $? "Loading master data into MongoDB"
else
    echo -e "Master data exists ... $Y SKIPPING $N"
fi

echo "Script completed at: $(date)" | tee -a $LOG_FILE
