resource "signalfx_single_value_chart" "global_request_volume" {
  name = "Global Request Volume"
  program_text = <<-EOF
  A = data('istio_requests_total', filter=filter('reporter', 'destination'), rollup='latest').rateofchange().sum().publish(label='Total Requests')
  EOF
  viz_options {
    label        = "Total Requests"
    value_suffix = "ops"
  }
}

resource "signalfx_single_value_chart" "global_success_rate" {
  name = "Global Success Rate (non-5xx responses)"
  program_text = <<-EOF
  A = data('istio_requests_total', filter=filter('reporter', 'destination') and (not filter('response_code', '5*')), rollup='latest').rateofchange().sum().publish(label='Non 5xx Requests', enable=False)
  B = data('istio_requests_total', filter=filter('reporter', 'destination'), rollup='latest').rateofchange().sum().publish(label='Total Requests', enable=False)
  C = (A/B).scale(100).publish(label='Success Rate')
  EOF
  viz_options {
    label        = "Success Rate"
    value_suffix = "%"
  }
}

resource "signalfx_single_value_chart" "global_4xxs" {
  name = "4xxs"
  program_text = <<-EOF
  A = data('istio_requests_total', filter=filter('reporter', 'destination') and filter('response_code', '4*'), rollup='latest').rateofchange().sum().publish(label='4xx Requests')
  EOF
  viz_options {
    label        = "4xx Requests"
    value_suffix = "ops"
  }
}

resource "signalfx_single_value_chart" "global_5xxs" {
  name = "5xxs"
  program_text = <<-EOF
  A = data('istio_requests_total', filter=filter('reporter', 'destination') and filter('response_code', '5*'), rollup='latest').rateofchange().sum().publish(label='5xx Requests')
  EOF
  viz_options {
    label        = "5xx Requests"
    value_suffix = "ops"
  }
}

resource "signalfx_single_value_chart" "virtual_services" {
  name = "Virtual Services"
  program_text = <<-EOF
  A = data('galley_istio_networking_virtualservices').mean().publish(label='A')
  EOF
}

resource "signalfx_single_value_chart" "destination_rules" {
  name = "Destination Rules"
  program_text = <<-EOF
  A = data('galley_istio_networking_destinationrules').mean().publish(label='A')
  EOF
}

resource "signalfx_single_value_chart" "gateways" {
  name = "Gateways"
  program_text = <<-EOF
  A = data('galley_istio_networking_gateways').mean().publish(label='A')
  EOF
}

resource "signalfx_single_value_chart" "authentication_mesh_policies" {
  name = "Authentication Mesh Policies"
  program_text = <<-EOF
  A = data('galley_istio_authentication_meshpolicies').mean().publish(label='A')
  EOF
}

resource "signalfx_list_chart" "request_volume_by_workload" {
  name = "Request Volume by Workload"
  program_text = <<-EOF
  A = data('istio_requests_total', filter=filter('reporter', 'destination'), rollup='latest').rateofchange().sum(by=['destination_workload', 'destination_workload_namespace']).publish(label='Requests')
  EOF
  viz_options {
    label        = "Requests"
    value_suffix = "ops"
  }
  sort_by = "-value"
  color_by = "Scale"
  color_scale {
    gt = 1
    color = "green"
  }
  color_scale {
    lte = 1
    color = "red"
  }
  legend_options_fields {
    property = "sf_metric"
    enabled  = false
  }
  legend_options_fields {
    property = "sf_originatingMetric"
    enabled  = false
  }
  max_precision = 3
}

resource "signalfx_time_chart" "request_volume_by_workload" {
  name = "Request Volume by Workload"
  program_text = <<-EOF
  A = data('istio_requests_total', filter=filter('reporter', 'destination'), rollup='latest').rateofchange().sum(by=['destination_workload', 'destination_workload_namespace']).publish(label='Requests')
  EOF
  viz_options {
    label        = "Requests"
    value_suffix = "ops"
  }
}

resource "signalfx_list_chart" "p50_latency_by_workload" {
  name = "P50 Latency by Workload"
  program_text = <<-EOF
  A = data('istio_request_duration_milliseconds_bucket', rollup='average').rateofchange().sum(by=['destination_workload', 'destination_workload_namespace']).percentile(pct=50, by=['destination_workload', 'destination_workload_namespace']).publish(label='P50 Latency')
  EOF
  viz_options {
    label        = "P50 Latency"
    value_suffix = "ms"
  }
  sort_by = "-value"
  color_by = "Scale"
  color_scale {
    gt = 200
    color = "red"
  }
  color_scale {
    lte = 200
    gt = 100
    color = "yellow"
  }
  color_scale {
    lte = 100
    color = "green"
  }
  legend_options_fields {
    property = "sf_metric"
    enabled  = false
  }
  legend_options_fields {
    property = "sf_originatingMetric"
    enabled  = false
  }
  max_precision = 3
}

resource "signalfx_time_chart" "p50_latency_by_workload" {
  name = "P50 Latency by Workload"
  program_text = <<-EOF
  A = data('istio_request_duration_milliseconds_bucket', rollup='average').rateofchange().sum(by=['destination_workload', 'destination_workload_namespace']).percentile(pct=50, by=['destination_workload', 'destination_workload_namespace']).publish(label='P50 Latency')
  EOF
  viz_options {
    label        = "P50 Latency"
    value_suffix = "ms"
  }
}

resource "signalfx_list_chart" "p99_latency_by_workload" {
  name = "P99 Latency by Workload"
  program_text = <<-EOF
  A = data('istio_request_duration_milliseconds_bucket', rollup='average').rateofchange().sum(by=['destination_workload', 'destination_workload_namespace']).percentile(pct=99, by=['destination_workload', 'destination_workload_namespace']).publish(label='P99 Latency')
  EOF
  viz_options {
    label        = "P99 Latency"
    value_suffix = "ms"
  }
  sort_by = "-value"
  color_by = "Scale"
  color_scale {
    gt = 200
    color = "red"
  }
  color_scale {
    lte = 200
    gt = 100
    color = "yellow"
  }
  color_scale {
    lte = 100
    color = "green"
  }
  legend_options_fields {
    property = "sf_metric"
    enabled  = false
  }
  legend_options_fields {
    property = "sf_originatingMetric"
    enabled  = false
  }
  max_precision = 3
}

resource "signalfx_time_chart" "p99_latency_by_workload" {
  name = "P99 Latency by Workload"
  program_text = <<-EOF
  A = data('istio_request_duration_milliseconds_bucket', rollup='average').rateofchange().sum(by=['destination_workload', 'destination_workload_namespace']).percentile(pct=99, by=['destination_workload', 'destination_workload_namespace']).publish(label='P99 Latency')
  EOF
  viz_options {
    label        = "P99 Latency"
    value_suffix = "ms"
  }
}

resource "signalfx_list_chart" "success_rate_by_workload" {
  name = "Success Rate by Workload"
  program_text = <<-EOF
  A = data('istio_requests_total', filter=filter('reporter', 'destination') and (not filter('response_code', '5*')), rollup='latest').rateofchange().sum(by=['destination_workload', 'destination_workload_namespace']).publish(label='Non 5xx Requests', enable=False)
  B = data('istio_requests_total', filter=filter('reporter', 'destination'), rollup='latest').rateofchange().sum(by=['destination_workload', 'destination_workload_namespace']).publish(label='Total Requests', enable=False)
  C = (A/B).scale(100).publish(label='Success Rate')
  EOF
  viz_options {
    label        = "Success Rate"
    value_suffix = "%"
  }
  sort_by = "+value"
  color_by = "Scale"
  color_scale {
    gt = 95
    color = "green"
  }
  color_scale {
    lte = 95
    gt = 90
    color = "yellow"
  }
  color_scale {
    lte = 90
    color = "red"
  }
  legend_options_fields {
    property = "sf_metric"
    enabled  = false
  }
  legend_options_fields {
    property = "sf_originatingMetric"
    enabled  = false
  }
  max_precision = 3
}

resource "signalfx_time_chart" "success_rate_by_workload" {
  name = "Success Rate by Workload"
  program_text = <<-EOF
  A = data('istio_requests_total', filter=filter('reporter', 'destination') and (not filter('response_code', '5*')), rollup='latest').rateofchange().sum(by=['destination_workload', 'destination_workload_namespace']).publish(label='Non 5xx Requests', enable=False)
  B = data('istio_requests_total', filter=filter('reporter', 'destination'), rollup='latest').rateofchange().sum(by=['destination_workload', 'destination_workload_namespace']).publish(label='Total Requests', enable=False)
  C = (A/B).scale(100).publish(label='Success Rate')
  EOF
  viz_options {
    label        = "Success Rate"
    value_suffix = "%"
  }
}
resource "signalfx_dashboard" "istio_mesh_dashboard" {
  name = "Istio Mesh Dashboard"
  dashboard_group = signalfx_dashboard_group.istio_dashboards.id

  chart {
    chart_id = signalfx_single_value_chart.global_request_volume.id
    width = 3
    height = 1
    column = 0
    row = 0
  }
  chart {
    chart_id = signalfx_single_value_chart.global_success_rate.id
    width = 3
    height = 1
    column = 3
    row = 0
  }
  chart {
    chart_id = signalfx_single_value_chart.global_4xxs.id
    width = 3
    height = 1
    column = 6
    row = 0
  }
  chart {
    chart_id = signalfx_single_value_chart.global_5xxs.id
    width = 3
    height = 1
    column = 9
    row = 0
  }
  chart {
    chart_id = signalfx_single_value_chart.virtual_services.id
    width = 3
    height = 1
    column = 0
    row = 1
  }
  chart {
    chart_id = signalfx_single_value_chart.destination_rules.id
    width = 3
    height = 1
    column = 3
    row = 1
  }
  chart {
    chart_id = signalfx_single_value_chart.gateways.id
    width = 3
    height = 1
    column = 6
    row = 1
  }
  chart {
    chart_id = signalfx_single_value_chart.authentication_mesh_policies.id
    width = 3
    height = 1
    column = 9
    row = 1
  }
  chart {
    chart_id = signalfx_list_chart.request_volume_by_workload.id
    width = 4
    height = 1
    column = 0
    row = 2
  }
  chart {
    chart_id = signalfx_time_chart.request_volume_by_workload.id
    width = 8
    height = 1
    column = 4
    row = 2
  }
  chart {
    chart_id = signalfx_list_chart.p50_latency_by_workload.id
    width = 4
    height = 1
    column = 0
    row = 3
  }
  chart {
    chart_id = signalfx_time_chart.p50_latency_by_workload.id
    width = 8
    height = 1
    column = 4
    row = 3
  }
  chart {
    chart_id = signalfx_list_chart.p99_latency_by_workload.id
    width = 4
    height = 1
    column = 0
    row = 4
  }
  chart {
    chart_id = signalfx_time_chart.p99_latency_by_workload.id
    width = 8
    height = 1
    column = 4
    row = 4
  }
  chart {
    chart_id = signalfx_list_chart.success_rate_by_workload.id
    width = 4
    height = 1
    column = 0
    row = 5
  }
  chart {
    chart_id = signalfx_time_chart.success_rate_by_workload.id
    width = 8
    height = 1
    column = 4
    row = 5
  }
}
