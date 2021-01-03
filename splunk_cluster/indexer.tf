variable "indexer_count" {
  description = "number of index peers"
}

resource "aws_security_group" "cluster-indexer-sg" {
  vpc_id = aws_vpc.cluster-vpc.id
  name   = "cluster-indexer-sg"

  ingress {
    from_port   = 9997
    to_port     = 9997
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    self        = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "cluster-indexer-sg"
  }
}

locals {
  subnet_count = length(aws_subnet.cluster-subnet-private)
}

resource "aws_instance" "cluster-indexers" {
  count                  = var.indexer_count
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.micro"
  key_name               = var.key_pair
  vpc_security_group_ids = [aws_security_group.cluster-base-sg.id, aws_security_group.cluster-indexer-sg.id]
  subnet_id              = aws_subnet.cluster-subnet-private[data.aws_availability_zones.available.names[count.index % local.subnet_count]].id
  user_data              = <<-EOF
    #! /bin/bash
    # Set hostname
    hostnamectl set-hostname splunk-indexer-${count.index}

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

    su - splunk -c "/opt/splunk/bin/splunk start --accept-license --answer-yes --seed-passwd changeme"

    su - splunk -c "/opt/splunk/bin/splunk set default-hostname splunk-indexer-${count.index} -auth admin:changeme"
    su - splunk -c "/opt/splunk/bin/splunk set servername splunk-indexer-${count.index} -auth admin:changeme"

    # License slave
    su - splunk -c "/opt/splunk/bin/splunk edit licenser-localslave \
    -master_uri https://licensemaster.${var.domain_prefix}-splunkcluster.internal:8089 \
    -auth admin:changeme"

    # Configure replication
    rc=1
    while [ $rc != 0 ]
    do
      sleep 10
      su - splunk -c "/opt/splunk/bin/splunk edit cluster-config -mode slave \
      -master_uri https://clustermaster.${var.domain_prefix}-splunkcluster.internal:8089 \
      -replication_port 8080 \
      -secret idxcluster \
      -auth admin:changeme"; rc=$?
    done

    # Enable receiving port from forwarders
    su - splunk -c "/opt/splunk/bin/splunk enable listen 9997 -auth admin:changeme"

    # Restart Splunk
    su - splunk -c "/opt/splunk/bin/splunk restart"

    # Enable boot start
    /opt/splunk/bin/splunk enable boot-start -user splunk
  EOF

  root_block_device {
    # For reference: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ebs-volume-types.html
#    volume_type = "io1"
    volume_size = 16
#    iops        = 1600
  }

  tags = {
    Name = "cluster-indexer-${count.index}"
  }

  volume_tags = {
    Name = "cluster-indexer-${count.index}"
  }

  depends_on = [
    aws_instance.cluster-licensemaster,
    aws_instance.cluster-clustermaster,
    aws_route53_record.licensemaster,
    aws_route53_record.clustermaster
  ]
}

output "indexer-private-ip" {
  value = aws_instance.cluster-indexers.*.private_ip
}
