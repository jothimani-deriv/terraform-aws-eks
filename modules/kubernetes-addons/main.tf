#-----------------AWS Managed EKS Add-ons----------------------

module "aws_vpc_cni" {
  source = "./aws-vpc-cni"

  count = var.enable_amazon_eks_vpc_cni ? 1 : 0

  enable_ipv6 = var.enable_ipv6
  addon_config = merge(
    {
      kubernetes_version = local.eks_cluster_version
    },
    var.amazon_eks_vpc_cni_config,
  )

  addon_context = local.addon_context
}

module "aws_coredns" {
  source = "./aws-coredns"

  count = var.enable_amazon_eks_coredns || var.enable_self_managed_coredns ? 1 : 0

  addon_context = local.addon_context

  # Amazon EKS CoreDNS addon
  enable_amazon_eks_coredns = var.enable_amazon_eks_coredns
  addon_config = merge(
    {
      kubernetes_version = local.eks_cluster_version
    },
    var.amazon_eks_coredns_config,
  )

  # Self-managed CoreDNS addon via Helm chart
  enable_self_managed_coredns = var.enable_self_managed_coredns
  helm_config = merge(
    {
      kubernetes_version = local.eks_cluster_version
    },
    var.self_managed_coredns_helm_config,
    {
      # Putting after because we don't want users to overwrite this - internal use only
      image_registry = local.amazon_container_image_registry_uris[data.aws_region.current.name]
    }
  )

  # CoreDNS cluster proportioanl autoscaler
  enable_cluster_proportional_autoscaler      = var.enable_coredns_cluster_proportional_autoscaler
  cluster_proportional_autoscaler_helm_config = var.coredns_cluster_proportional_autoscaler_helm_config

  remove_default_coredns_deployment      = var.remove_default_coredns_deployment
  eks_cluster_certificate_authority_data = data.aws_eks_cluster.eks_cluster.certificate_authority[0].data
}

module "aws_kube_proxy" {
  source = "./aws-kube-proxy"

  count = var.enable_amazon_eks_kube_proxy ? 1 : 0

  addon_config = merge(
    {
      kubernetes_version = local.eks_cluster_version
    },
    var.amazon_eks_kube_proxy_config,
  )

  addon_context = local.addon_context
}

module "aws_ebs_csi_driver" {
  source = "./aws-ebs-csi-driver"

  count = var.enable_amazon_eks_aws_ebs_csi_driver || var.enable_self_managed_aws_ebs_csi_driver ? 1 : 0

  # Amazon EKS aws-ebs-csi-driver addon
  enable_amazon_eks_aws_ebs_csi_driver = var.enable_amazon_eks_aws_ebs_csi_driver
  addon_config = merge(
    {
      kubernetes_version = local.eks_cluster_version
    },
    var.amazon_eks_aws_ebs_csi_driver_config,
  )

  addon_context = local.addon_context

  # Self-managed aws-ebs-csi-driver addon via Helm chart
  enable_self_managed_aws_ebs_csi_driver = var.enable_self_managed_aws_ebs_csi_driver
  helm_config = merge(
    {
      kubernetes_version = local.eks_cluster_version
    },
    var.self_managed_aws_ebs_csi_driver_helm_config,
  )
}

#-----------------Kubernetes Add-ons----------------------
module "argocd" {
  count         = var.enable_argocd ? 1 : 0
  source        = "./argocd"
  helm_config   = var.argocd_helm_config
  applications  = var.argocd_applications
  addon_config  = { for k, v in local.argocd_addon_config : k => v if v != null }
  addon_context = local.addon_context
}

module "aws_cloudwatch_metrics" {
  count             = var.enable_aws_cloudwatch_metrics ? 1 : 0
  source            = "./aws-cloudwatch-metrics"
  helm_config       = var.aws_cloudwatch_metrics_helm_config
  irsa_policies     = var.aws_cloudwatch_metrics_irsa_policies
  manage_via_gitops = var.argocd_manage_add_ons
  addon_context     = local.addon_context
}

module "aws_load_balancer_controller" {
  count             = var.enable_aws_load_balancer_controller ? 1 : 0
  source            = "./aws-load-balancer-controller"
  helm_config       = var.aws_load_balancer_controller_helm_config
  manage_via_gitops = var.argocd_manage_add_ons
  addon_context     = merge(local.addon_context, { default_repository = local.amazon_container_image_registry_uris[data.aws_region.current.name] })
}

module "aws_node_termination_handler" {
  count                   = var.enable_aws_node_termination_handler && (length(var.auto_scaling_group_names) > 0 || var.enable_karpenter) ? 1 : 0
  source                  = "./aws-node-termination-handler"
  helm_config             = var.aws_node_termination_handler_helm_config
  manage_via_gitops       = var.argocd_manage_add_ons
  irsa_policies           = var.aws_node_termination_handler_irsa_policies
  autoscaling_group_names = var.auto_scaling_group_names
  addon_context           = local.addon_context
}

module "appmesh_controller" {
  count         = var.enable_appmesh_controller ? 1 : 0
  source        = "./appmesh-controller"
  helm_config   = var.appmesh_helm_config
  irsa_policies = var.appmesh_irsa_policies
  addon_context = local.addon_context
}

module "cert_manager" {
  count                             = var.enable_cert_manager ? 1 : 0
  source                            = "./cert-manager"
  helm_config                       = var.cert_manager_helm_config
  manage_via_gitops                 = var.argocd_manage_add_ons
  irsa_policies                     = var.cert_manager_irsa_policies
  addon_context                     = local.addon_context
  domain_names                      = var.cert_manager_domain_names
  install_letsencrypt_issuers       = var.cert_manager_install_letsencrypt_issuers
  letsencrypt_email                 = var.cert_manager_letsencrypt_email
  kubernetes_svc_image_pull_secrets = var.cert_manager_kubernetes_svc_image_pull_secrets
}

module "cert_manager_csi_driver" {
  count             = var.enable_cert_manager_csi_driver ? 1 : 0
  source            = "./cert-manager-csi-driver"
  helm_config       = var.cert_manager_csi_driver_helm_config
  manage_via_gitops = var.argocd_manage_add_ons
  addon_context     = local.addon_context
}

module "cert_manager_istio_csr" {
  count             = var.enable_cert_manager_istio_csr ? 1 : 0
  source            = "./cert-manager-istio-csr"
  helm_config       = var.cert_manager_istio_csr_helm_config
  manage_via_gitops = var.argocd_manage_add_ons
  addon_context     = local.addon_context
}

module "cluster_autoscaler" {
  source = "./cluster-autoscaler"

  count = var.enable_cluster_autoscaler ? 1 : 0

  eks_cluster_version = local.eks_cluster_version
  helm_config         = var.cluster_autoscaler_helm_config
  manage_via_gitops   = var.argocd_manage_add_ons
  addon_context       = local.addon_context
}

module "coredns_autoscaler" {
  count             = var.enable_amazon_eks_coredns && var.enable_coredns_autoscaler && length(var.coredns_autoscaler_helm_config) > 0 ? 1 : 0
  source            = "./cluster-proportional-autoscaler"
  helm_config       = var.coredns_autoscaler_helm_config
  manage_via_gitops = var.argocd_manage_add_ons
  addon_context     = local.addon_context
}

module "external_dns" {
  source = "./external-dns"

  count = var.enable_external_dns ? 1 : 0

  helm_config       = var.external_dns_helm_config
  manage_via_gitops = var.argocd_manage_add_ons
  irsa_policies     = var.external_dns_irsa_policies
  addon_context     = local.addon_context

  domain_name       = var.eks_cluster_domain
  private_zone      = var.external_dns_private_zone
  route53_zone_arns = var.external_dns_route53_zone_arns
}

module "ingress_nginx" {
  count             = var.enable_ingress_nginx ? 1 : 0
  source            = "./ingress-nginx"
  helm_config       = var.ingress_nginx_helm_config
  manage_via_gitops = var.argocd_manage_add_ons
  addon_context     = local.addon_context
}

module "karpenter" {
  source = "./karpenter"

  count = var.enable_karpenter ? 1 : 0

  helm_config                                 = var.karpenter_helm_config
  irsa_policies                               = var.karpenter_irsa_policies
  node_iam_instance_profile                   = var.karpenter_node_iam_instance_profile
  enable_spot_termination                     = var.karpenter_enable_spot_termination_handling
  rule_name_prefix                            = var.karpenter_event_rule_name_prefix
  manage_via_gitops                           = var.argocd_manage_add_ons
  addon_context                               = local.addon_context
  sqs_queue_managed_sse_enabled               = var.sqs_queue_managed_sse_enabled
  sqs_queue_kms_master_key_id                 = var.sqs_queue_kms_master_key_id
  sqs_queue_kms_data_key_reuse_period_seconds = var.sqs_queue_kms_data_key_reuse_period_seconds
}

module "keda" {
  count             = var.enable_keda ? 1 : 0
  source            = "./keda"
  helm_config       = var.keda_helm_config
  irsa_policies     = var.keda_irsa_policies
  manage_via_gitops = var.argocd_manage_add_ons
  addon_context     = local.addon_context
}

module "kubernetes_dashboard" {
  count             = var.enable_kubernetes_dashboard ? 1 : 0
  source            = "./kubernetes-dashboard"
  helm_config       = var.kubernetes_dashboard_helm_config
  manage_via_gitops = var.argocd_manage_add_ons
  addon_context     = local.addon_context
}

module "metrics_server" {
  count             = var.enable_metrics_server ? 1 : 0
  source            = "./metrics-server"
  helm_config       = var.metrics_server_helm_config
  manage_via_gitops = var.argocd_manage_add_ons
  addon_context     = local.addon_context
}

module "kube_state_metrics" {
  count             = var.enable_kube_state_metrics ? 1 : 0
  source            = "./kube-state-metrics"
  helm_config       = var.kube_state_metrics_helm_config
  manage_via_gitops = var.argocd_manage_add_ons
  addon_context     = local.addon_context
}

module "reloader" {
  count             = var.enable_reloader ? 1 : 0
  source            = "./reloader"
  helm_config       = var.reloader_helm_config
  manage_via_gitops = var.argocd_manage_add_ons
  addon_context     = local.addon_context
}


module "spark_k8s_operator" {
  count             = var.enable_spark_k8s_operator ? 1 : 0
  source            = "./spark-k8s-operator"
  helm_config       = var.spark_k8s_operator_helm_config
  manage_via_gitops = var.argocd_manage_add_ons
  addon_context     = local.addon_context
}

module "vpa" {
  count             = var.enable_vpa ? 1 : 0
  source            = "./vpa"
  helm_config       = var.vpa_helm_config
  manage_via_gitops = var.argocd_manage_add_ons
  addon_context     = local.addon_context
}

module "aws_privateca_issuer" {
  count                   = var.enable_aws_privateca_issuer ? 1 : 0
  source                  = "./aws-privateca-issuer"
  helm_config             = var.aws_privateca_issuer_helm_config
  manage_via_gitops       = var.argocd_manage_add_ons
  addon_context           = local.addon_context
  aws_privateca_acmca_arn = var.aws_privateca_acmca_arn
  irsa_policies           = var.aws_privateca_issuer_irsa_policies
}

module "velero" {
  count             = var.enable_velero ? 1 : 0
  source            = "./velero"
  helm_config       = var.velero_helm_config
  manage_via_gitops = var.argocd_manage_add_ons
  addon_context     = local.addon_context
  irsa_policies     = var.velero_irsa_policies
  backup_s3_bucket  = var.velero_backup_s3_bucket
}

module "external_secrets" {
  source = "./external-secrets"

  count = var.enable_external_secrets ? 1 : 0

  helm_config                           = var.external_secrets_helm_config
  manage_via_gitops                     = var.argocd_manage_add_ons
  addon_context                         = local.addon_context
  irsa_policies                         = var.external_secrets_irsa_policies
  external_secrets_ssm_parameter_arns   = var.external_secrets_ssm_parameter_arns
  external_secrets_secrets_manager_arns = var.external_secrets_secrets_manager_arns
}


module "kubecost" {
  source = "./kubecost"

  count = var.enable_kubecost ? 1 : 0

  helm_config       = var.kubecost_helm_config
  manage_via_gitops = var.argocd_manage_add_ons
  addon_context     = local.addon_context
}

module "kyverno" {
  source = "./kyverno"

  count = var.enable_kyverno ? 1 : 0

  addon_context     = local.addon_context
  manage_via_gitops = var.argocd_manage_add_ons

  kyverno_helm_config = var.kyverno_helm_config

  enable_kyverno_policies      = var.enable_kyverno_policies
  kyverno_policies_helm_config = var.kyverno_policies_helm_config

  enable_kyverno_policy_reporter      = var.enable_kyverno_policy_reporter
  kyverno_policy_reporter_helm_config = var.kyverno_policy_reporter_helm_config
}

module "local_volume_provisioner" {
  source = "./local-volume-provisioner"

  count = var.enable_local_volume_provisioner ? 1 : 0

  helm_config   = var.local_volume_provisioner_helm_config
  addon_context = local.addon_context
}