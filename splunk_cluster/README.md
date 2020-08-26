# Setup Splunk Cluster on AWS

Deploy Splunk cluster to AWS  
To import providers, execute `init` as following.

```
terraform init
```

## Resources

- VPC
- Subunet (private/public) with multi AZ's
- Internet Gateway
- Elastic IP
- NAT Gateway
- Route Table
- Security Group
- EC2 Instance
- Route53 (private) zone and records

## Variables

Variables | Required | Default | Description
----------|----------|---------|------------
`indexer_count` | required | - | number of index peers
`region` | required | - | region to deploy instances
`key_pair` | required | - | ssh key pair name
`domain_prefix` | required | - | Internal domain name prefix - ******-splunkcluster.internal
`splunk_download_file` | optional | `splunk-8.0.5-a1a6394cc5ae-Linux-x86_64.tgz` | Splunk tgz install file name (e.g. splunk-8.0.5-a1a6394cc5ae-Linux-x86_64.tgz)

Example:

```
terraform apply -var="indexer_count=3" -var="region=us-west-2" -var="key_pair=my_keypair" -var="domain_prefix=terraform"
```
