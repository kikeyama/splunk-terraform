# Setup Splunk Cluster on AWS

```
terraform init
```

## Variables

Variables | Required | Default | Description
----------|----------|---------|------------
`indexer_count` | required | - | number of index peers
`region` | required | - | region to deploy instances
`domain_prefix` | required | - | Internal domain name prefix - ******-splunkcluster.internal
`splunk_download_file` | optional | `splunk-8.0.5-a1a6394cc5ae-Linux-x86_64.tgz` | Splunk tgz install file name (e.g. splunk-8.0.5-a1a6394cc5ae-Linux-x86_64.tgz)

Example:

```
terraform apply -var="indexer_count=3" -var="region=us-west-2" -var="domain_prefix=terraform"
```
