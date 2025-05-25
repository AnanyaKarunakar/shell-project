#!/bin/bash

USERID=$(id -u)

R="\e[31m"
G="\e[32m"
Y="\e[33m"
N="\e[0m"

LOGS_FOLDER="/var/log/shellscript-logs"
SCRIPT_NAME=$(echo $0 | cut -d "." -f1)
LOG_FILE="$LOGS_FOLDER/SCRIPT_NAME.log"

mkdir -p $LOGS_FOLDER
echo "Script started executing at: $(date)" &>>$LOGS_FILE

if [ $USERID -ne 0 ]
then
	echo "$R ERROR:: Please run this script with root access $N" &>>$LOGS_FILE 
    exit 1 # give other than 0 upto 127
else
	echo "You are running with root access" &>>$LOGS_FILE
fi
# validate functions takes input as exit status, what command they tried to install
VALIDATE(){
	if [ $1 -eq 0 ]
	then
		echo "Installing $2 is ... $G SUCCESS $N" &>>$LOGS_FILE
	else
		echo "Installing $2 is $R FAILURE $N" &>>$LOGS_FILE
		exit 1
	fi
}

dnf list installed mysql &>>$LOGS_FILE

if [ $? -ne 0 ]
then
    echo "MySQL is not installed... going to install it now" &>>$LOGS_FILE
    dnf install mysql -y &>>$LOGS_FILE

VALIDATE $? "MySQL"
else
    echo "MySQL is $Y already installed $N... Nothing to do" &>>$LOGS_FILE
fi

dnf list installed python3 &>>$LOGS_FILE

if [ $? -ne 0 ]
then
    echo "python3 is not installed... going to install it now" &>>$LOGS_FILE
    dnf install python3 -y &>>$LOGS_FILE

VALIDATE $? "python3"
else
    echo "pyhton3 is $Y already installed $N ... Nothing to do" &>>$LOGS_FILE
fi

dnf list installed nginx &>>$LOGS_FILE

if [ $? -ne 0 ]
then
    echo "nginx is not installed... going to install it now" &>>$LOGS_FILE
    dnf install nginx -y &>>$LOGS_FILE

VALIDATE $? "nginx"
else
    echo "nginx is $Y already installed $N... Nothing to do" &>>$LOGS_FILE
fi
