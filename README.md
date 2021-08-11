# aws-ssm
This is a collection of scripts for playing with AWS System Manager

## ssm_psexec.ps1
Allow to execute an program on a remote Windows instance under a specific user. 
* Requirements
1) Attach a role with the policy AmazonSSMManagedInstanceCore.json to your instance 


Sign up here
Select Personal for account type
AWS requires a valid phone number for verification
Your credit/debit card will also be charged $1 for verification purposes, the amount will be refunded after being processed
See here for more information about the charge
Select the Free Basic Plan
This plan is free for 12 months with certain usage restrictions, set a date in your calender to cancel your plan if you don't want to be charged after one year
See more details about the free plan here
Sign in to the AWS console with your new account
It can take up to 24 hours for your account to be verified, check your email for notification
Once logged in you'll be in the AWS dashboard
Click the Cloud9 link, otherwise type cloud9 into the AWS services search bar and select Cloud9 A Cloud IDE for Writing, Running, and Debugging Code
If your account has been verified then you will be able to select Create environment
Name it wdb and click Next step
Leave default settings and click Next step again
Scroll down and click Create environment
