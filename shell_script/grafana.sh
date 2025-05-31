#!/bin/bash
# Script to install Grafana on a Linux instance and run it on port 5000

# Update package list and install dependencies
sudo apt-get install -y apt-transport-https software-properties-common wget

# Create a directory for Grafana's GPG key
sudo mkdir -p /etc/apt/keyrings/

# Add Grafana's GPG key
wget -q -O - https://apt.grafana.com/gpg.key | gpg --dearmor | sudo tee /etc/apt/keyrings/grafana.gpg > /dev/null

# Add Grafana's repository to the sources list
echo "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main" | sudo tee -a /etc/apt/sources.list.d/grafana.list

# Update package lists
sudo apt-get update -y

# Install the latest OSS release of Grafana
sudo apt-get install grafana -y

# Change Grafana port to 5000 in the config file
sudo sed -i 's/^;http_port = 3000/http_port = 5000/' /etc/grafana/grafana.ini

# Open firewall (if needed, you’ve already added in Terraform SG)
# sudo ufw allow 5000/tcp

# Start and enable Grafana service
sudo systemctl daemon-reexec
sudo systemctl restart grafana-server
sudo systemctl enable grafana-server

# Output info
ip=$(curl -s ifconfig.me)
echo "Grafana is running at: http://$ip:5000"
echo "Default login: admin / admin"
