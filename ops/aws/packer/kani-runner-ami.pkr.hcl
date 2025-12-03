packer {
  required_plugins {
    amazon = {
      source  = "github.com/hashicorp/amazon"
      version = "~> 1"
    }
  }
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "instance_type" {
  type    = string
  default = "c6i.4xlarge"
}

source "amazon-ebs" "kani-runner" {
  ami_name      = "kani-runner-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"
  instance_type = var.instance_type
  region        = var.aws_region
  source_ami_filter {
    filters = {
      name                = "ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = ["099720109477"] # Canonical
  }
  ssh_username = "ubuntu"
  tags = {
    Name        = "Kani Runner AMI"
    Purpose     = "GitHub Actions Runner for Kani Proofs"
    ManagedBy   = "Packer"
    Repository  = "BTCDecoded/blvm"
  }
}

build {
  name = "kani-runner"
  sources = ["source.amazon-ebs.kani-runner"]

  provisioner "shell" {
    inline = [
      "sudo apt-get update",
      "sudo apt-get install -y curl jq",
      "curl -fsSL https://raw.githubusercontent.com/BTCDecoded/blvm/main/tools/bootstrap_runner.sh -o /tmp/bootstrap_runner.sh",
      "sudo chmod +x /tmp/bootstrap_runner.sh",
      "sudo /tmp/bootstrap_runner.sh --rust --kani --cache-dir /tmp/runner-cache || true"
    ]
  }

  provisioner "shell" {
    inline = [
      "sudo useradd -m -s /bin/bash actions-runner || true",
      "sudo mkdir -p /opt/actions-runner",
      "cd /tmp",
      "RUNNER_VERSION=$(curl -s https://api.github.com/repos/actions/runner/releases/latest | jq -r .tag_name | sed 's/v//')",
      "curl -o actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz -L https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz",
      "sudo tar xzf actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz -C /opt/actions-runner",
      "sudo chown -R actions-runner:actions-runner /opt/actions-runner",
      "rm -f actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz"
    ]
  }

  provisioner "shell" {
    inline = [
      "sudo rm -rf /tmp/*",
      "sudo apt-get clean",
      "sudo rm -rf /var/lib/apt/lists/*",
      "sudo truncate -s 0 /var/log/*.log",
      "sudo find /var/log -type f -name '*.log' -exec truncate -s 0 {} \\;"
    ]
  }
}



