terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.67.0"
    }
  }
}

provider "aws" {
  region = var.region_name
}

# STEP 1: SECURITY GROUP
resource "aws_security_group" "monitoring_sg" {
  name        = "MONITORING-SERVER-SG"
  description = "Allow ports for monitoring tools"

  ingress {
    description = "SSH Access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  dynamic "ingress" {
    for_each = [
      { desc = "HTTP", from = 80, to = 80 },
      { desc = "HTTPS", from = 443, to = 443 },
      { desc = "Etcd", from = 2379, to = 2380 },
      { desc = "Node Exporter", from = 9100, to = 9100 },
      { desc = "K8s API", from = 6443, to = 6443 },
      { desc = "K8s Internal", from = 10250, to = 10260 },
      { desc = "NodePort", from = 30000, to = 32767 },
      { desc = "BlackboxExporter", from = 9115, to = 9115 },
      { desc = "Jenkins", from = 8080, to = 8080 },
      { desc = "SonarQube", from = 9000, to = 9000 },
      { desc = "Prometheus", from = 9090, to = 9090 },
      { desc = "Grafana", from = 5000, to = 5000 },
    ]
    content {
      description = ingress.value.desc
      from_port   = ingress.value.from
      to_port     = ingress.value.to
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# STEP 2: EC2 INSTANCE
resource "aws_instance" "monitoring_ec2" {
  ami                    = var.ami
  instance_type          = var.instance_type
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.monitoring_sg.id]

  root_block_device {
    volume_size = var.volume_size
  }

  tags = {
    Name = var.server_name
  }

  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("./${var.key_name}.pem")
      host        = self.public_ip
    }

    inline = [
      # Update system and install dependencies
      "sudo apt-get update -y",
      "sudo apt-get install -y unzip curl wget gnupg software-properties-common net-tools apt-transport-https",

      # AWS CLI
      "curl 'https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip' -o 'awscliv2.zip'",
      "unzip awscliv2.zip",
      "sudo ./aws/install",

      # --- PROMETHEUS ---
      "sudo useradd --system --no-create-home --shell /bin/false prometheus",
      "wget https://github.com/prometheus/prometheus/releases/download/v2.51.2/prometheus-2.51.2.linux-amd64.tar.gz",
      "tar -xvf prometheus-2.51.2.linux-amd64.tar.gz",
      "cd prometheus-2.51.2.linux-amd64 && sudo mv prometheus promtool /usr/local/bin/",
      "sudo mkdir -p /etc/prometheus /data",
      "sudo mv prometheus-2.51.2.linux-amd64/{consoles,console_libraries,prometheus.yml} /etc/prometheus/",
      "sudo chown -R prometheus:prometheus /etc/prometheus /data",
      "echo '[Unit]\nDescription=Prometheus\nAfter=network-online.target\n[Service]\nUser=prometheus\nGroup=prometheus\nType=simple\nExecStart=/usr/local/bin/prometheus --config.file=/etc/prometheus/prometheus.yml --storage.tsdb.path=/data --web.console.templates=/etc/prometheus/consoles --web.console.libraries=/etc/prometheus/console_libraries --web.listen-address=0.0.0.0:9090 --web.enable-lifecycle\n[Install]\nWantedBy=multi-user.target' | sudo tee /etc/systemd/system/prometheus.service",
      "sudo systemctl daemon-reload",
      "sudo systemctl enable --now prometheus",

      # --- NODE EXPORTER ---
      "sudo useradd --system --no-create-home --shell /bin/false node_exporter",
      "wget https://github.com/prometheus/node_exporter/releases/download/v1.6.1/node_exporter-1.6.1.linux-amd64.tar.gz",
      "tar -xvf node_exporter-1.6.1.linux-amd64.tar.gz",
      "sudo mv node_exporter-1.6.1.linux-amd64/node_exporter /usr/local/bin/",
      "echo '[Unit]\nDescription=Node Exporter\nAfter=network-online.target\n[Service]\nUser=node_exporter\nGroup=node_exporter\nType=simple\nExecStart=/usr/local/bin/node_exporter --collector.logind\n[Install]\nWantedBy=multi-user.target' | sudo tee /etc/systemd/system/node_exporter.service",
      "sudo systemctl daemon-reload",
      "sudo systemctl enable --now node_exporter",

      # --- BLACKBOX EXPORTER ---
      "sudo useradd --system --no-create-home --shell /bin/false blackbox_exporter",
      "wget https://github.com/prometheus/blackbox_exporter/releases/download/v0.26.0/blackbox_exporter-0.26.0.linux-amd64.tar.gz",
      "tar -xvf blackbox_exporter-0.26.0.linux-amd64.tar.gz",
      "sudo mv blackbox_exporter-0.26.0.linux-amd64/blackbox_exporter /usr/local/bin/",
      "sudo mkdir -p /etc/blackbox_exporter",
      "sudo cp blackbox_exporter-0.26.0.linux-amd64/blackbox.yml /etc/blackbox_exporter/",
      "sudo chown -R blackbox_exporter:blackbox_exporter /etc/blackbox_exporter",
      "echo '[Unit]\nDescription=Blackbox Exporter\nAfter=network.target\n[Service]\nUser=blackbox_exporter\nExecStart=/usr/local/bin/blackbox_exporter --config.file=/etc/blackbox_exporter/blackbox.yml\n[Install]\nWantedBy=multi-user.target' | sudo tee /etc/systemd/system/blackbox_exporter.service",
      "sudo systemctl daemon-reload",
      "sudo systemctl enable --now blackbox_exporter",

      # --- GRAFANA ---
      "sudo mkdir -p /etc/apt/keyrings/",
      "wget -q -O - https://apt.grafana.com/gpg.key | gpg --dearmor | sudo tee /etc/apt/keyrings/grafana.gpg > /dev/null",
      "echo 'deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main' | sudo tee /etc/apt/sources.list.d/grafana.list",
      "sudo apt-get update -y",
      "sudo apt-get install grafana -y",
      "sudo sed -i 's/^;http_port = 3000/http_port = 5000/' /etc/grafana/grafana.ini",
      "sudo systemctl daemon-reload",
      "sudo systemctl enable --now grafana-server"
    ]
  }
}

# STEP 3: OUTPUTS
output "SERVER-SSH-ACCESS" {
  value = "ubuntu@${aws_instance.monitoring_ec2.public_ip}"
}

output "PUBLIC-IP" {
  value = aws_instance.monitoring_ec2.public_ip
}

output "PRIVATE-IP" {
  value = aws_instance.monitoring_ec2.private_ip
}
