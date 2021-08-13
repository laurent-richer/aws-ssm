# aws-ssm
An AWS solution for executing remote command on windows instances from an on-prem linux server. Thanks to AWS SSM Run Command, you can automate executing tasks on dozens of servers.

![alt text](https://github.com/laurent-richer/aws-ssm/blob/master/RemoteExecutionArchitecture.png)

The on-prem server use a temporary role-based authentication and authorization, therefore there is no need to create a specific user. This solution is compatible with a federated authentication. As credentials are temporary it needs to be periodically refreshed, for that purpose we implemented the ruby script 'get_sts_creds' from  https://github.com/awslabs/aws-codedeploy-samples.git
## Global requirements
1) An on-prem linux server [1] which control the execution of the remote command .
2) An EC2 instance [2] that will be used as our first credential generator. 
3) Windows target instances [3] where executable will be launched, thanks to the remote control program Psexec which allow to run any program under any users.
4) An domain controller, in this case we will use AWS Directory Service, that's allow to run command under specific user.
5) AWS SSM Parameter store used to keep your sensitive datasafe.
6) An IAM role to allow to allow interacting with SSM Run Command and SSM Parameter Store. 

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
   * Install ruby and get_sts_creds ( from https://github.com/awslabs/aws-codedeploy-samples.git) . This script will call AWS STS for you and retrieve fresh credentials.
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
* Setup on Windows Targets [3] :
   * Install the latest version psexec ( just copy psexec.exe or psexec64.exe in your executable path ) from https://docs.microsoft.com/en-us/sysinternals/downloads/psexec
   * Be sure that your Windows server is registered to your Active Directory Domain.
* Setup AWS SSM Parameter Store :
  * It's a best practice to avoid to store your password in plain text on your server, it's recommended to store them encrypted.
  * Follow the documentation to create your credentials vault : https://docs.aws.amazon.com/systems-manager/latest/userguide/param-create-cli.html 
  * In this solution I've created a Secure String Parameter with the following parameter-name "/org/user/pass"    
## Running a command from your linux on-prem server
* Check that your credential are synchronized with the assumed role EC2SSMRUnCommand using the following command :
```
aws sts get-caller-identity
```
* You are ready to launch a remote command on your target servers. Here our executable is Windows based so we will execute a PowerShell script. The PS script will ask Psexec to launch a simple notepad.exe under the specific $domain\$user authentified by his password retrieved from Parameter Store. The script available on git : sss_psexec.ps1 
```
$domain='mydomain'
$user='laurent'

$password = Get-SSMParameter "/org/user/pass/$user" -WithDecryption $true | Select-Object -ExpandProperty Value
$securePassword = ConvertTo-SecureString $password -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential $domain\$user, $securePassword

psexec \\$env:computername -accepteula -u $domain\$user -p $password -h -i notepad
```
* You can run this script through the AWS SSM Run Command Console or execute this script trough CLI ( don't forget to replace $domain and $user by you own values):
```
aws ssm send-command --document-name "AWS-RunPowerShellScript" --document-version "1" --targets '[{"Key":"InstanceIds","Values":["i-xxxxxx"]}]' --parameters '{"commands":["$domain='"'"'mdomain'"'"'","$user='"'"'laurent'"'"'","","$password = Get-SSMParameter \"/org/user/pass/$user\" -WithDecryption $true | Select-Object -ExpandProperty Value","echo $password","$securePassword = ConvertTo-SecureString $password -AsPlainText -Force","$credential = New-Object System.Management.Automation.PSCredential $domain\\$user, $securePassword","","psexec \\\\$env:computername -accepteula -u $domain\\$user -p $password -h -i notepad"],"workingDirectory":[""],"executionTimeout":["60"]}' --timeout-seconds 600 --max-concurrency "50" --max-errors "0" --region eu-west-3
```


