# aws-ssm
An AWS solution for executing remote command to windows instances hosted on AWS from an on-prem linux server. 

![alt text](https://github.com/laurent-richer/aws-ssm/blob/8c9458e9e2b6e81cb74ee1ef2de7a872f27a9a3e/RemoteExecutionArchitecture.png)

The on-prem server use a temporary role-based authentication and authorization, therefore there is no need to create a specific user. As credentials are temporary it needs to be periodically refreshed, for that purpose we implemented the ruby script 'get_sts_creds' from  https://github.com/awslabs/aws-codedeploy-samples.git
## Global requirements
1) An on-prem linux server which control when remote command will be executed [1]
2) An EC2 instance [2] that will be used a our first credential generator 
3) An Windows Manager isntance [3] attached to the same domain as target windows instances.
4) Windos target instances [4] where executable will be launched under a specific user
5) S3 bucket to store the executable ( this part is not detailed in this solution)
6) A domain controller, in this case we use AWS Directory Service
7) AWS SSM Parameter store used to store sensitive data like password.
8) An IAM role to allow ec2 instance to call SSM to run a PowerShell script execution. 

## How to proceed  
* Create a role with the following policies :
   *   Select the AWS Managed policy : AmazonSSMManagedInstanceCore
   *   Create a new policy, for example "EC2SSMRunCommand"  with the following permissions ( ssm:SendCommand for executing AWS-RunPowerShellScript on Windows Manager Instance ) :
   ```json
   {
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "VisualEditor0",
            "Effect": "Allow",
            "Action": "ssm:SendCommand",
            "Resource": [
                "arn:aws:ec2:<region>:<account>:instance/i-<idinstance[2]>",
                "arn:aws:ssm:<region>::document/AWS-RunPowerShellScript"
            ]
        }
      ]
    } 
   ```
   * Edit the trust relationship and add the following trusted entities ( on-prem linux and Widnows Manager) to assume this role :
     ```json
     "Principal": {
        "Service": "ec2.amazonaws.com",
        "AWS": [
          "arn:aws:sts::<account>:assumed-role/EC2SSMRunCommand/onprem-linux",
          "arn:aws:sts::<account>:assumed-role/EC2SSMRunCommand/i-<idinstance[2]>"
        ]
     ```
    * Attach the role to instances [2] and [3]
* Setup on instance [2]
  * Retrieve temporary AWS_ACCESS_KEY_ID , AWS_SECRET_ACCESS_KEY and AWS_SESSION_TOKEN
  ```
  aws sts assume-role --role-arn arn:aws:iam::<account>:role/EC2SSMRunCommand --role-session-name onprem-linux --region <region>
  ```   
* On instance [1] , your linux on-prem server, do the following :
   * Install ruby and get_sts_creds. This script will call AWS STS for you and retrieve fresh credentials.
   * Fill the file ~/.aws/.credentials with the temporary AWS_ACCESS_KEY_ID , AWS_SECRET_ACCESS_KEY and AWS_SESSION_TOKEN
   ```
   aws_access_key_id = ASI******
   aws_secret_access_key = WA7p*******
   aws_session_token =  QoJb3JpZ2luX2VjENv//////////wEaCWV1LXdlc3QtMyJIMEYC*******
   ```
   * Test the credentials refresh :
   ```
   utilities/aws-codedeploy-session-helper/bin/get_sts_creds --role-arn arn:aws:iam::<account>:role/EC2SSMRunCommand --file ~/.aws/credentials --session-   name-override onprem-linux --region eu-west-3
   ```
   * Then edit the user's crontab in order to setup the credential refresh frequency to 15 minutes
   ```
   crontab -e
   0,15,30,45 * * * * utilities/aws-codedeploy-session-helper/bin/get_sts_creds --role-arn arn:aws:iam::<account>:role/EC2SSMRunCommand --file ~/.aws/credentials --session-name-override onprem-linux --region eu-west-3
   ```
* Setup on instance Windows Manager [3] :
   * Install the latest version psexec ( just copy the executable psexec.exe in your executable path ) from https://docs.microsoft.com/en-us/sysinternals/downloads/psexec
   * Be sure that your Windows server is registered to your Active Directory Domain.
* Setup on Windows Target [4] :
  * Nothing specific to do just join your target to your AD domain.
* Setup AWS SSM Parameter Store :
  * It's a best practice to avoid to store your user's credentials in plain text on your server, it's recommended to store them encrypted.
  * Follow the documentation to create your credentials vault : https://docs.aws.amazon.com/systems-manager/latest/userguide/param-create-cli.html 
  * In this solution I've created a Secure String Parameter with the following parameter-name "/org/user/pass"    
## Running a command from your linux on-prem server
* Check that you are synchronized with the assumed role EC2SSMRUnCommand using the following command :
```
aws sts get-caller-identity
```
* Then you are ready to launch a remote command on your target server, in this example we will launch a simple notepad from PowerShell script ssm_psexc.ps1.
```
$domain='mydomain'
$user='laurent'

$password = Get-SSMParameter "/org/user/pass/$user" -WithDecryption $true | Select-Object -ExpandProperty Value
$securePassword = ConvertTo-SecureString $password -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential $domain\$user, $securePassword

psexec \\$env:computername -accepteula -u $domain\$user -p $password -h -i notepad
```
* You can run this script through the AWS SSM Run Command Console or execute this script trough CLI ( don't forget to replace $domain and $user by you own values):
* 
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
