# Azure Overview #
in this directory you will find several azure related scripts designs and pieces of code helping you to get in control and stay in control.
These may also include snippets hence be aware that you might have to adjust code or variable inputs. Let's start up with the directories followed by the script files

## Directory Content ##
- AKS, for use of AKS related commands and scripts.
- Designs, focuses on drawings of environments, apps or tooling.
- DevOps, includes a set of scripts to help your DevOps environment get to the next level
- resourceGraphQueries, useful KQL queries to help you find what you need, when you need it
- Security, useful security-related scripts e.g. for the Microsoft Defender suite (not XDR, this goes through M365).
- Terraform, for Terraform deployments to Azure

## Script Content ##
- azurePoliciesConfigurationSample.ps1 - [Snippet] Powershell script which allows you to configure a default policy (using Azure Policy) or a custom one.
- azureRunCommandOnVm.ps1 - [Script] Powershell script which allows you to run a command on 1 or more computers based on findings of a KQL query
- azureRunKqlQuery.ps1 - [Script] Powershell script which let's you run KQL query's from your local console either by specifying a path or hardcoding the query.
- Create_Scripts - [Script] Powershell and Python scripts which allows you to provision resources via script
    - Create_Azure_PSQL.ps1 - [Database] PostgreSQL
    - Create_Azure_RG.ps1 - Resource Group
    - Create_Azure_VM.ps1 - [Compute] Virtual Machine
    - Create_Delete_Azure_Storage_Account.ps1 - Storage Account
    - Create_PSQL_Server_Azure.py - [Database] PostgreSQL
- genericLogonScript.ps1 - [Script] Powershell script which enables you to scriptmatically login using device level authentication to azaccount and az modules
- Get_AAD_Group_Owner_Compare.ps1.ps1 - [Script] Powershell script to compare ownership permissions between groups
- Get_Specific_AzResources_per_Subscription.ps1 - [Script] Powershell script which enables you to Get RG's and Storage accounts across all subscriptions (foreach).
- GetAzPolicyResources.ps1 - [Script] Powershell script that collects the state of all your resources across subscriptions by querying azure policy (each policy)
- Install_AZ_Module_and_Connect.ps1 - [Snippet] Powershell script which allows you to force install the az module and run a connect-azaccount.