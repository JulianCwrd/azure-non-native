#!/bin/bash

# Update package lists
sudo apt-get update -y

# Install MySQL Server (without user prompt)
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y mysql-server

# Enable and start MySQL service
sudo systemctl enable mysql
sudo systemctl start mysql

# Print MySQL version to verify installation
mysql --version
