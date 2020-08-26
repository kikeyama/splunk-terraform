variable "splunk_download_file" {
  default     = "splunk-8.0.5-a1a6394cc5ae-Linux-x86_64.tgz"
  description = "Splunk tgz install file name (e.g. splunk-8.0.5-a1a6394cc5ae-Linux-x86_64.tgz)"
}

variable "key_pair" {
  description = "ssh key pair name"
}

resource "random_integer" "az_index_lm" {
  min = 0
  max = length(data.aws_availability_zones.available.names) - 1
}

resource "random_integer" "az_index_cm" {
  min = 0
  max = length(data.aws_availability_zones.available.names) - 1
}

resource "random_integer" "az_index_ds" {
  min = 0
  max = length(data.aws_availability_zones.available.names) - 1
}

resource "aws_instance" "cluster-licensemaster" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.micro"
  key_name               = var.key_pair
  vpc_security_group_ids = [aws_security_group.cluster-base-sg.id]
  subnet_id              = aws_subnet.cluster-subnet-private[data.aws_availability_zones.available.names[random_integer.az_index_lm.result]].id
  user_data              = <<-EOF
    #! /bin/bash
    # Set hostname
    hostnamectl set-hostname splunk-licensemaster
    
    # Install Splunk
    #./install_splunk.sh
    SPLUNK_FILE="${var.splunk_download_file}"
    SPLUNK_VERSION=`echo $${SPLUNK_FILE} | sed 's/-/ /g' | awk '{print $2}'`

    SPLUNK_URL="https://www.splunk.com/bin/splunk/DownloadActivityServlet?architecture=x86_64&platform=linux&version=$${SPLUNK_VERSION}&product=splunk&filename=$${SPLUNK_FILE}&wget=true"

    mkdir /home/splunk
    groupadd -g 501 splunk
    useradd -u 501 -g 501 splunk -d /home/splunk -s /bin/bash
    chown splunk:splunk /home/splunk

    echo "Download Splunk from $${SPLUNK_URL}"
    wget -nv -O /opt/$${SPLUNK_FILE} $${SPLUNK_URL}

    tar zxf /opt/$${SPLUNK_FILE} -C /opt/

    chown -R splunk:splunk /opt/splunk

    sudo -u splunk /opt/splunk/bin/splunk start --accept-license --answer-yes --seed-passwd changeme

    sudo -u splunk /opt/splunk/bin/splunk set default-hostname splunk-licensemaster -auth admin:changeme
    sudo -u splunk /opt/splunk/bin/splunk set servername splunk-licensemaster -auth admin:changeme

    /opt/splunk/bin/splunk enable boot-start -user splunk

    # Set deploy poll
    sudo -u splunk /opt/splunk/bin/splunk set deploy-poll deploymentserver.${var.domain_prefix}-splunkcluster.internal:8089 \
    -auth admin:changeme

    # Restart Splunk
    sudo -u splunk /opt/splunk/bin/splunk restart
  EOF

  root_block_device {
    volume_size = 16
  }

  tags = {
    Name = "cluster-licensemaster"
  }

  volume_tags = {
    Name = "cluster-licensemaster"
  }
}

resource "aws_instance" "cluster-clustermaster" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.micro"
  key_name               = var.key_pair
  vpc_security_group_ids = [aws_security_group.cluster-base-sg.id]
  subnet_id              = aws_subnet.cluster-subnet-private[data.aws_availability_zones.available.names[random_integer.az_index_cm.result]].id
  user_data              = <<-EOF
    #! /bin/bash
    # Set hostname
    hostnamectl set-hostname splunk-clustermaster
    
    # Install Splunk
    #./install_splunk.sh
    SPLUNK_FILE="${var.splunk_download_file}"
    SPLUNK_VERSION=`echo $${SPLUNK_FILE} | sed 's/-/ /g' | awk '{print $2}'`

    SPLUNK_URL="https://www.splunk.com/bin/splunk/DownloadActivityServlet?architecture=x86_64&platform=linux&version=$${SPLUNK_VERSION}&product=splunk&filename=$${SPLUNK_FILE}&wget=true"

    mkdir /home/splunk
    groupadd -g 501 splunk
    useradd -u 501 -g 501 splunk -d /home/splunk -s /bin/bash
    chown splunk:splunk /home/splunk

    echo "Download Splunk from $${SPLUNK_URL}"
    wget -nv -O /opt/$${SPLUNK_FILE} $${SPLUNK_URL}

    tar zxf /opt/$${SPLUNK_FILE} -C /opt/

    chown -R splunk:splunk /opt/splunk

    sudo -u splunk /opt/splunk/bin/splunk start --accept-license --answer-yes --seed-passwd changeme

    sudo -u splunk /opt/splunk/bin/splunk set default-hostname splunk-clustermaster -auth admin:changeme
    sudo -u splunk /opt/splunk/bin/splunk set servername splunk-clustermaster -auth admin:changeme

    /opt/splunk/bin/splunk enable boot-start -user splunk

    # License slave
    sudo -u splunk /opt/splunk/bin/splunk edit licenser-localslave \
    -master_uri https://licensemaster.${var.domain_prefix}-splunkcluster.internal:8089 \
    -auth admin:changeme

    # Replication and search factor
    sudo -u splunk /opt/splunk/bin/splunk edit cluster-config \
    -mode master \
    -replication_factor 3 \
    -search_factor 2 \
    -secret idxcluster \
    -auth admin:changeme

    # Indexer Discovery
    echo '[indexer_discovery]
    pass4SymmKey = idxforwarders' | sudo -u splunk tee -a /opt/splunk/etc/system/local/server.conf

    # Set deploy poll
    sudo -u splunk /opt/splunk/bin/splunk set deploy-poll deploymentserver.${var.domain_prefix}-splunkcluster.internal:8089 \
    -auth admin:changeme

    # Restart Splunk
    sudo -u splunk /opt/splunk/bin/splunk restart
  EOF

  root_block_device {
    volume_size = 16
  }

  tags = {
    Name = "cluster-clustermaster"
  }

  volume_tags = {
    Name = "cluster-clustermaster"
  }

  depends_on = [
    aws_instance.cluster-licensemaster,
    aws_route53_record.licensemaster
  ]
}

resource "aws_instance" "cluster-deploymentserver" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.micro"
  key_name               = var.key_pair
  vpc_security_group_ids = [aws_security_group.cluster-base-sg.id]
  subnet_id              = aws_subnet.cluster-subnet-private[data.aws_availability_zones.available.names[random_integer.az_index_ds.result]].id
  user_data              = <<-EOF
    #! /bin/bash
    # Set hostname
    hostnamectl set-hostname splunk-deploymentserver
    
    # Install Splunk
    #./install_splunk.sh
    SPLUNK_FILE="${var.splunk_download_file}"
    SPLUNK_VERSION=`echo $${SPLUNK_FILE} | sed 's/-/ /g' | awk '{print $2}'`

    SPLUNK_URL="https://www.splunk.com/bin/splunk/DownloadActivityServlet?architecture=x86_64&platform=linux&version=$${SPLUNK_VERSION}&product=splunk&filename=$${SPLUNK_FILE}&wget=true"

    mkdir /home/splunk
    groupadd -g 501 splunk
    useradd -u 501 -g 501 splunk -d /home/splunk -s /bin/bash
    chown splunk:splunk /home/splunk

    echo "Download Splunk from $${SPLUNK_URL}"
    wget -nv -O /opt/$${SPLUNK_FILE} $${SPLUNK_URL}

    tar zxf /opt/$${SPLUNK_FILE} -C /opt/

    chown -R splunk:splunk /opt/splunk

    sudo -u splunk /opt/splunk/bin/splunk start --accept-license --answer-yes --seed-passwd changeme

    sudo -u splunk /opt/splunk/bin/splunk set default-hostname splunk-deploymentserver -auth admin:changeme
    sudo -u splunk /opt/splunk/bin/splunk set servername splunk-deploymentserver -auth admin:changeme

    /opt/splunk/bin/splunk enable boot-start -user splunk

    # License slave
    sudo -u splunk /opt/splunk/bin/splunk edit licenser-localslave \
    -master_uri https://licensemaster.${var.domain_prefix}-splunkcluster.internal:8089 \
    -auth admin:changeme

    # Edit outputs.conf to be deployed to splunk cluster components
    sudo -u splunk mkdir -p /opt/splunk/etc/deployment-apps/cluster_base/local
    echo '[indexAndForward]
    index = false

    [tcpout]
    defaultGroup = default-autolb-group
    forwardedindex.filter.disable = true
    indexAndForward = false

    [tcpout:default-autolb-group]
    indexerDiscovery = idxc1
    useACK = true

    [indexer_discovery:idxc1]
    master_uri = https://clustermaster.${var.domain_prefix}-splunkcluster.internal:8089
    pass4SymmKey = idxforwarders' | sudo -u splunk tee -a /opt/splunk/etc/deployment-apps/cluster_base/local/outputs.conf

    # Setup Deployment Server
    echo '[serverClass:cluster_base:app:cluster_base]
    restartSplunkWeb = 0
    restartSplunkd = 1
    stateOnClient = enabled

    [serverClass:cluster_base]
    whitelist.0 = splunk-*' | sudo -u splunk tee -a /opt/splunk/etc/system/local/serverclass.conf

    # Set deploy poll
    sudo -u splunk /opt/splunk/bin/splunk set deploy-poll deploymentserver.${var.domain_prefix}-splunkcluster.internal:8089 \
    -auth admin:changeme

    # Restart Splunk
    sudo -u splunk /opt/splunk/bin/splunk restart

    # Reload deploy poll
    sudo -u splunk /opt/splunk/bin/splunk reload deploy-server \
    -class cluster_base \
    -auth admin:changeme
  EOF

  root_block_device {
    volume_size = 16
  }

  tags = {
    Name = "cluster-deploymentserver"
  }

  volume_tags = {
    Name = "cluster-deploymentserver"
  }

  depends_on = [
    aws_instance.cluster-licensemaster,
    aws_route53_record.licensemaster
  ]
}

output "licensemaster-private-ip" {
  value = aws_instance.cluster-licensemaster.private_ip
}

output "clustermaster-private-ip" {
  value = aws_instance.cluster-clustermaster.private_ip
}

output "deploymentserver-private-ip" {
  value = aws_instance.cluster-deploymentserver.private_ip
}
