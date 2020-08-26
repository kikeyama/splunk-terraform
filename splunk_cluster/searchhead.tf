resource "aws_security_group" "cluster-searchhead-sg" {
  vpc_id = aws_vpc.cluster-vpc.id
  name   = "cluster-searchhead-sg"

  ingress {
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "cluster-searchhead-sg"
  }
}

resource "random_integer" "az_index_sh" {
  min = 0
  max = length(data.aws_availability_zones.available.names) - 1
}

resource "aws_instance" "cluster-searchhead" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.micro"
  key_name               = var.key_pair
  vpc_security_group_ids = [aws_security_group.cluster-base-sg.id, aws_security_group.cluster-searchhead-sg.id]
  subnet_id              = aws_subnet.cluster-subnet-public[data.aws_availability_zones.available.names[random_integer.az_index_sh.result]].id
  user_data              = <<-EOF
    #! /bin/bash
    # Set hostname
    hostnamectl set-hostname splunk-searchhead

    # Install Splunk
    echo "install splunk"
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

    su - splunk -c "/opt/splunk/bin/splunk start --accept-license --answer-yes --seed-passwd changeme"

    su - splunk -c "/opt/splunk/bin/splunk set default-hostname splunk-searchhead -auth admin:changeme"
    su - splunk -c "/opt/splunk/bin/splunk set servername splunk-searchhead -auth admin:changeme"

    # License slave
    echo "License slave licensemaster=${aws_instance.cluster-licensemaster.private_ip}"
    su - splunk -c "/opt/splunk/bin/splunk edit licenser-localslave \
    -master_uri https://licensemaster.${var.domain_prefix}-splunkcluster.internal:8089 \
    -auth admin:changeme"

    # Connect Cluster Master
    rc=1
    while [ $rc != 0 ]
    do
      sleep 10
      echo "Connect Cluster Master clustermaster=${aws_instance.cluster-clustermaster.private_ip}"
      su - splunk -c "/opt/splunk/bin/splunk edit cluster-config \
      -mode searchhead \
      -master_uri https://clustermaster.${var.domain_prefix}-splunkcluster.internal:8089 \
      -secret idxcluster \
      -auth admin:changeme"; rc=$?
    done

    # Set deploy poll
    echo "Set deploy poll deploymentserver=${aws_instance.cluster-deploymentserver.private_ip}"
    su - splunk -c "/opt/splunk/bin/splunk set deploy-poll deploymentserver.${var.domain_prefix}-splunkcluster.internal:8089 \
    -auth admin:changeme"

    # Restart Splunk
    echo "Restart Splunk"
    su - splunk -c "/opt/splunk/bin/splunk restart"

    # Enable boot start
    /opt/splunk/bin/splunk enable boot-start -user splunk
  EOF

  root_block_device {
    volume_size = 16
  }

  tags = {
    Name = "cluster-searchhead"
  }

  volume_tags = {
    Name = "cluster-searchhead"
  }

  depends_on = [
    aws_instance.cluster-licensemaster,
    aws_instance.cluster-clustermaster,
    aws_instance.cluster-deploymentserver,
    aws_route53_record.licensemaster,
    aws_route53_record.clustermaster,
    aws_route53_record.deploymentserver
  ]
}

output "searchhead-public-ip" {
  value = aws_instance.cluster-searchhead.public_ip
}

output "searchhead-private-ip" {
  value = aws_instance.cluster-searchhead.private_ip
}
