# Overview

AWS Warm Pool provides an innovative solution for addressing the "Cold Start" issue in Kubernetes clusters. By maintaining a pool of EC2 instances in either 'stopped' or 'hibernated' states, this approach ensures these pre-warmed nodes are nearly ready for deployment. This strategy significantly cuts down startup time as these nodes have completed initial boot-ups, such as pulling container images and running startup scripts. The 'stopped' state preserves instance store data, while 'hibernated' state saves in-memory data to the root EBS volume for quicker resumption. This method enhances flexibility, responsiveness, and cost-efficiency in cloud-based Kubernetes environments, offering a standby resource solution without the full operational costs.

# Prerequisites

Before beginning, ensure the following tools are installed and configured:

- Terraform: Install from [HashiCorp's Terraform Installation Guide](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli).
- AWS CLI: Install or update to the latest version following [AWS CLI User Guide](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html).
- AWS Credentials: Set up your AWS credentials for access.
- kubectl: Install using the [Kubernetes Official Guide](https://kubernetes.io/docs/tasks/tools/#kubectl).
- git: Install using the [Git Installation Guide](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git).


# Deployment Steps

The project sets up a VPC, Security Groups, an EKS cluster, and various necessary addons, including coredns, kube-proxy, vpc-cni, eks-pod-identity-agent (optional), and a cluster autoscaler.

1. Clone the Git repository

```bash
git clone https://github.com/kankou-aliaksei/terraform-eks-warm-pool.git
```

2. Initialize and Apply Terraform Configuration

```bash
cd terraform-eks-warm-pool/examples/warm_pool_and_eks
terraform init
terraform apply
```

3. Update your kubeconfig file to interact with the new EKS cluster

```bash
aws eks --region eu-central-1 update-kubeconfig --name warm-pool-eks-cluster
```

4. Verify your connection to the cluster

```bash
kubectl cluster-info
```

5. Verify Instance States

```bash
aws ec2 describe-instances \
--filters "Name=tag:Name,Values=warm-pool-eks-cluster-ng" \
--region eu-central-1 \
--query "Reservations[*].Instances[*].[Tags[?Key=='Name'].Value|[0], InstanceId, State.Name]" \
--output text
```

You should wait until you see in the output that a worker node instance has been created and is in a “stopped” status. This indicates that the worker node has completed script initialization and has entered the pool in a “stopped” status, and now we have one node in the Warm Pool.


6. Deploy Test Application

Make sure you go to the “deployment” folder relative to the base project folder

```bash
cd deployment
kubectl apply -f test-deployment.yaml
```

7. Monitor the deployment

```bash
watch "kubectl get pods"
```

You will see that the pod launch occurs within 90 seconds, despite the basic setup of the instance requiring 2 minutes, because all the basic configuration is completed during the instance’s warm-up period

8. Destroy terraform project

If you have finished testing and no longer need the project, remember to delete it to avoid incurring additional charges.

Ensure that you are in the examples/warm_pool_and_eks directory before executing

```bash
terraform destroy
```