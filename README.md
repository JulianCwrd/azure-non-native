# azure-non-native
Post-Deploy POC Development brainstorming
# Azure VM with MySQL Installation via Azure Policy

The goal of this Terraform project is to deploy an Azure VM and check if MySQL is installed using an Azure Policy

- Deploys an Azure Linux VM (Ubuntu 22.04)
- Assigns a Public IP
- Configures Network Security Rules (SSH & MySQL Access)
- Uses Azure Policy (`DeployIfNotExists`) to install MySQL if missing
