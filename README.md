# opsworks-deploy
Deploy Opsworks Apps from the cli

You will need to create an aws profile and individual cred files for the clie to run off of.
See the example api file 


## How to use

First you will need to install the aws-cli and create a profile for each IAM role that you are using.

#### Installing AWS-CLI
https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-install.html

#### Creating a Profile
https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-configure.html  
https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-profiles.html  

Example: (creating a profile with the name of "company") 
```
aws configure --profile company
```
You will then be prompted to input the follwing:  
```
AWS Access Key ID [None]: ... 
AWS Secret Access Key [None]: ... 
Default region name [None]: ... 
Default output format [None]: ... 
```

#### Creating an App Variable File
For Each App create a Variables File in the same directory as the script
Example:  
/path_to_script_folder/api
```
#!/usr/bin/env bash
TITLE="API"
STACK_ID="123123123-wert-4c41-234-2342v21v2vv"
APP_ID="a98f9asf8-2345-sdfg-sdfg-dsfg3kl423425"
REGION="us-west-1"
PROFILE="company"

```


Then Run
```
bash /path_to_script_folder/opsworks_deploy.sh api
```

Run Multiple Apps at once
```
bash /path_to_script_folder/opsworks_deploy.sh api website app app2
```

### Create an Alias
You can create an Alias in your ~/.bash_profile
```
alias deploy="bash /path_to_script_folder/opsworks_deploy.sh"
```
Then update your bash_profile
```
source ~/.bash_profile
```

Now you can run 
```
deploy api
```

Feel free to report any issues :)
