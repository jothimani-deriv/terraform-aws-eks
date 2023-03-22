# Frequently Asked Questions
## Provider Authentication

With that said, the examples here are combining the providers and users can sometimes encounter various issues with the provider authentication methods. There are primarily two methods for authenticating the Kubernetes, Helm, and Kubectl providers to the EKS cluster created:

1. Using a static token which has a lifetime of 15 minutes per the EKS service documentation.
2. Using the `exec()` method which will fetch a token at the time of Terraform invocation.

The Kubernetes and Helm providers [recommend the `exec()` method](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs#exec-plugins), however this has the caveat that it requires the awscli to be installed on the machine running Terraform *AND* of at least a minimum version to support the API spec used by the provider (i.e. - `"client.authentication.k8s.io/v1alpha1"`, `"client.authentication.k8s.io/v1beta1"`, etc.). Selecting the appropriate provider authentication method is left up to users, and the examples used in this project will default to using the static token method for ease of use.

Users of the static token method should be aware that if they receive a `401 Unauthorized` message, they might have a token that has expired and will need to run `terraform refresh` to get a new token.
Users of the `exec()` method should be aware that the `exec()` method is reliant on the awscli and the associated authentication API version; the awscli version may need to be updated to support a later API version required by the Kubernetes version in use.

The following examples demonstrate either method that users can utilize - please refer to the associated provider's documentation for further details on configuration.

### Static Token Example

```hcl
provider "kubernetes" {
  host                   = module.eks_blueprints.eks_cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks_blueprints.eks_cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.this.token
}

provider "helm" {
  kubernetes {
    host                   = module.eks_blueprints.eks_cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks_blueprints.eks_cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}

provider "kubectl" {
  apply_retry_count      = 10
  host                   = module.eks_blueprints.eks_cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks_blueprints.eks_cluster_certificate_authority_data)
  load_config_file       = false
  token                  = data.aws_eks_cluster_auth.this.token
}

data "aws_eks_cluster_auth" "this" {
  name = module.eks_blueprints.eks_cluster_id
}
```

### `exec()` Example

Usage of exec plugin for AWS credentials

Links to References related to this issue

- https://github.com/hashicorp/terraform/issues/29182
- https://github.com/aws/aws-cli/pull/6476

```hcl
provider "kubernetes" {
  host                   = module.eks_blueprints.eks_cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks_blueprints.eks_cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = ["eks", "get-token", "--cluster-name", module.eks_blueprints.eks_cluster_id]
  }
}

provider "helm" {
  kubernetes {
    host                   = module.eks_blueprints.eks_cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks_blueprints.eks_cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args = ["eks", "get-token", "--cluster-name", module.eks_blueprints.eks_cluster_id]
    }
  }
}

provider "kubectl" {
  apply_retry_count      = 10
  host                   = module.eks_blueprints.eks_cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks_blueprints.eks_cluster_certificate_authority_data)
  load_config_file       = false

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = ["eks", "get-token", "--cluster-name", module.eks_blueprints.eks_cluster_id]
  }
}
```

### How to use IRSA module

Sample code snippet for using IRSA module directly

```hcl
module "irsa" {
    source = "github.com/aws-ia/terraform-aws-eks-blueprints//modules/irsa"
    kubernetes_namespace       = "<ENTER_NAMESPACE>"
    kubernetes_service_account = "<ENTER_SERVICE_ACCOUNT_NAME>"
    irsa_iam_policies          = ["<ENTER_IAM_POLICY_ARN>"]
    eks_cluster_id             = module.eks_blueprints.eks_cluster_id
    eks_oidc_provider_arn      = module.eks_blueprints.eks_oidc_provider_arn
}
```