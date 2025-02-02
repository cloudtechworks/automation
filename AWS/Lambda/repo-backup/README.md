# Introduction 
Repobackup. Back-ups for all Github and Azure DevOps repos. 

# Build and Test
Run the build pipeline and the script in backup.py will execute.
To get this to work you do have to change the in-code variables or parse them through via a variable group in Azure Devops

# Requirements
It is recommended to verify you have the required packages:
base64
boto3
botocore
requests