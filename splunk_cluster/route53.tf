variable "domain_prefix" {
  description = "Internal domain name prefix - ******-splunkcluster.internal"
}

resource "aws_route53_zone" "cluster-private" {
  name = "${var.domain_prefix}-splunkcluster.internal"

  vpc {
    vpc_id     = aws_vpc.cluster-vpc.id
    vpc_region = var.region
  }

  tags = {
    Name = "${var.domain_prefix}-splunkcluster.internal"
  }
}

#resource "aws_route53_record" "indexer" {
#  zone_id  = aws_route53_zone.cluster-private.zone_id
#  for_each = toset(aws_instance.cluster-indexers.*.private_ip)
#  name     = "indexer-${each.key}.${var.domain_prefix}-splunkcluster.internal"
#  type     = "A"
#  ttl      = "300"
#  records  = [each.value]
#}

resource "aws_route53_record" "indexers" {
  zone_id = aws_route53_zone.cluster-private.zone_id
  name    = "indexers.${var.domain_prefix}-splunkcluster.internal"
  type    = "A"
  ttl     = "300"
  records = tolist(aws_instance.cluster-indexers.*.private_ip)
}

resource "aws_route53_record" "searchhead" {
  zone_id = aws_route53_zone.cluster-private.zone_id
  name    = "searchhead.${var.domain_prefix}-splunkcluster.internal"
  type    = "A"
  ttl     = "300"
  records = [aws_instance.cluster-searchhead.private_ip]
}

resource "aws_route53_record" "licensemaster" {
  zone_id = aws_route53_zone.cluster-private.zone_id
  name    = "licensemaster.${var.domain_prefix}-splunkcluster.internal"
  type    = "A"
  ttl     = "300"
  records = [aws_instance.cluster-licensemaster.private_ip]
}

resource "aws_route53_record" "clustermaster" {
  zone_id = aws_route53_zone.cluster-private.zone_id
  name    = "clustermaster.${var.domain_prefix}-splunkcluster.internal"
  type    = "A"
  ttl     = "300"
  records = [aws_instance.cluster-clustermaster.private_ip]
}

resource "aws_route53_record" "deploymentserver" {
  zone_id = aws_route53_zone.cluster-private.zone_id
  name    = "deploymentserver.${var.domain_prefix}-splunkcluster.internal"
  type    = "A"
  ttl     = "300"
  records = [aws_instance.cluster-deploymentserver.private_ip]
}
