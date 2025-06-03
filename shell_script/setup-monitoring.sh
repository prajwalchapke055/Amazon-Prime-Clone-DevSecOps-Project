#!/bin/bash

set -e

# Update system and install dependencies
sudo apt-get update -y
sudo apt-get install -y unzip curl wget gnupg software-properties-common net-tools apt-transport-https

# Install AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# --- PROMETHEUS ---
sudo useradd --system --no-create-home --shell /bin/false prometheus
wget https://github.com/prometheus/prometheus/releases/download/v2.51.2/prometheus-2.51.2.linux-amd64.tar.gz
tar -xvf prometheus-2.51.2.linux-amd64.tar.gz

cd prometheus-2.51.2.linux-amd64
sudo mv prometheus promtool /usr/local/bin/
cd ..
sudo mkdir -p /etc/prometheus /data
sudo mv prometheus-2.51.2.linux-amd64/{consoles,console_libraries,prometheus.yml} /etc/prometheus/
sudo chown -R prometheus:prometheus /etc/prometheus /data

# Prometheus systemd service
sudo tee /etc/systemd/system/prometheus.service > /dev/null <<EOF
[Unit]
Description=Prometheus
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/local/bin/prometheus \\
  --config.file=/etc/prometheus/prometheus.yml \\
  --storage.tsdb.path=/data \\
  --web.console.templates=/etc/prometheus/consoles \\
  --web.console.libraries=/etc/prometheus/console_libraries \\
  --web.listen-address=0.0.0.0:9090 \\
  --web.enable-lifecycle

[Install]
WantedBy=multi-user.target
EOF

# --- NODE EXPORTER ---
sudo useradd --system --no-create-home --shell /bin/false node_exporter
wget https://github.com/prometheus/node_exporter/releases/download/v1.6.1/node_exporter-1.6.1.linux-amd64.tar.gz
tar -xvf node_exporter-1.6.1.linux-amd64.tar.gz
sudo mv node_exporter-1.6.1.linux-amd64/node_exporter /usr/local/bin/

# Node Exporter systemd service
sudo tee /etc/systemd/system/node_exporter.service > /dev/null <<EOF
[Unit]
Description=Node Exporter
After=network-online.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter --collector.logind

[Install]
WantedBy=multi-user.target
EOF

# --- BLACKBOX EXPORTER ---
sudo useradd --system --no-create-home --shell /bin/false blackbox_exporter
wget https://github.com/prometheus/blackbox_exporter/releases/download/v0.26.0/blackbox_exporter-0.26.0.linux-amd64.tar.gz
tar -xvf blackbox_exporter-0.26.0.linux-amd64.tar.gz
sudo mv blackbox_exporter-0.26.0.linux-amd64/blackbox_exporter /usr/local/bin/
sudo mkdir -p /etc/blackbox_exporter
sudo cp blackbox_exporter-0.26.0.linux-amd64/blackbox.yml /etc/blackbox_exporter/
sudo chown -R blackbox_exporter:blackbox_exporter /etc/blackbox_exporter

# Blackbox Exporter systemd service
sudo tee /etc/systemd/system/blackbox_exporter.service > /dev/null <<EOF
[Unit]
Description=Blackbox Exporter
After=network.target

[Service]
User=blackbox_exporter
Group=blackbox_exporter
ExecStart=/usr/local/bin/blackbox_exporter --config.file=/etc/blackbox_exporter/blackbox.yml

[Install]
WantedBy=multi-user.target
EOF

# --- GRAFANA ---
sudo mkdir -p /etc/apt/keyrings/
wget -q -O - https://apt.grafana.com/gpg.key | gpg --dearmor | sudo tee /etc/apt/keyrings/grafana.gpg > /dev/null
echo "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main" | sudo tee /etc/apt/sources.list.d/grafana.list

sudo apt-get update -y
sudo apt-get install grafana -y

# (Port remains 3000 — default)
# If changed before, reset:
# sudo sed -i 's/^http_port = .*/;http_port = 3000/' /etc/grafana/grafana.ini

# Reload systemd and enable all services
sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl enable --now prometheus
sudo systemctl enable --now node_exporter
sudo systemctl enable --now blackbox_exporter
sudo systemctl enable --now grafana-server

echo "✅ Monitoring stack setup complete."
echo "🌐 Prometheus: http://<your-server-ip>:9090"
echo "🌐 Node Exporter: http://<your-server-ip>:9100"
echo "🌐 Blackbox Exporter: http://<your-server-ip>:9115"
echo "🌐 Grafana: http://<your-server-ip>:3000"
