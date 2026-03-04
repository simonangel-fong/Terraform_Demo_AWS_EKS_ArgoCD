
data "aws_ssoadmin_instances" "this" {
  provider = aws.identity # region: us-east-1
}

data "aws_identitystore_group" "aws_administrator" {
  provider          = aws.identity # region: us-east-1
  identity_store_id = one(data.aws_ssoadmin_instances.this.identity_store_ids)

  alternate_identifier {
    unique_attribute {
      attribute_path  = "DisplayName"
      attribute_value = "AWSAdministrator"
    }
  }
}

locals {
  name   = "eks-argocd"
  region = "ca-central-1"

  vpc_cidr = "10.0.0.0/16"
  azs      = slice(data.aws_availability_zones.available.names, 0, 3)

  tags = {
    Project = local.name
    Type    = "Demo"
    Managed = "Terraform"
  }
}

################################################################################
# VPC
################################################################################

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.0"

  name = local.name
  cidr = local.vpc_cidr

  azs             = local.azs
  private_subnets = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 4, k)]
  public_subnets  = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 48)]
  intra_subnets   = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 52)]

  enable_nat_gateway = true
  single_nat_gateway = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }

  tags = local.tags
}

# ################################################################################
# # EKS Module
# ################################################################################
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "21.15.1"

  name                   = local.name
  kubernetes_version     = "1.35"
  endpoint_public_access = true

  enable_cluster_creator_admin_permissions = true

  compute_config = {
    enabled    = true
    node_pools = ["general-purpose"]
  }

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  tags = local.tags
}

# ################################################################################
# # EKS Capability Module
# ################################################################################
module "argocd_eks_capability" {
  source  = "terraform-aws-modules/eks/aws//modules/capability"
  version = "21.15.1"

  type         = "ARGOCD"
  cluster_name = module.eks.cluster_name
  
  providers = {
    aws = aws.identity # region: us-east-1
  }

  configuration = {
    argo_cd = {
      aws_idc = {
        idc_instance_arn = one(data.aws_ssoadmin_instances.this.arns)
      }
      namespace = "argocd"
      rbac_role_mapping = [{
        role = "ADMIN"
        identity = [{
          id   = data.aws_identitystore_group.aws_administrator.group_id
          type = "SSO_GROUP"
        }]
      }]
    }
  }

  # IAM Role/Policy
  iam_policy_statements = {
    ECRRead = {
      actions = [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
      ]
      resources = ["*"]
    }
  }

  tags = local.tags
}
