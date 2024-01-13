locals {
  cluster_autoscaler_image_repository_uri = "registry.k8s.io/autoscaling/cluster-autoscaler"
  cluster_autoscaler_image_tag            = var.cluster_autoscaler_image_tag
  cluster_name                            = var.cluster_name
  cluster_autoscaler_role_arn             = aws_iam_role.autoscaler.arn
  region                                  = var.region
}

resource "helm_release" "cluster_autoscaler" {
  name       = "cluster-autoscaler"
  repository = "https://kubernetes.github.io/autoscaler"
  chart      = "cluster-autoscaler"
  version    = "9.34.1"
  namespace  = "kube-system"

  set {
    name  = "awsRegion"
    value = var.region
  }

  set {
    name  = "cloudProvider"
    value = "aws"
  }

  set {
    name  = "image.repository"
    value = local.cluster_autoscaler_image_repository_uri
  }

  set {
    name  = "image.tag"
    value = local.cluster_autoscaler_image_tag
  }

  set {
    name  = "autoDiscovery.clusterName"
    value = var.cluster_name
  }

  set {
    name  = "extraArgs.skip-nodes-with-system-pods"
    value = false
  }

  set {
    name  = "extraArgs.scale-down-delay-after-delete"
    value = "2m"
  }

  dynamic "set" {
    for_each = var.pod_identity_type == "IRSA" ? [1] : []
    content {
      name  = "rbac.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
      value = local.cluster_autoscaler_role_arn
    }
  }

  set {
    name  = "rbac.serviceAccount.name"
    value = "cluster-autoscaler"
  }

  set {
    name  = "extraEnv.AWS_DEFAULT_REGION"
    value = var.region
  }

  set {
    name  = "extraEnv.AWS_STS_REGIONAL_ENDPOINTS"
    value = "regional"
  }

  set {
    name  = "extraVolumeMounts[0].name"
    value = "ssl-certs"
  }

  set {
    name  = "extraVolumeMounts[0].mountPath"
    value = "/etc/ssl/certs/ca-certificates.crt"
  }

  set {
    name  = "extraVolumeMounts[0].readOnly"
    value = true
  }

  set {
    name  = "extraVolumes[0].name"
    value = "ssl-certs"
  }

  set {
    name  = "extraVolumes[0].hostPath.path"
    value = "/etc/ssl/certs/ca-bundle.crt"
  }
}
