
variable "cluster-name" {
  default = "terraform-eks"
  type    = "string"
}

provider "aws" {
    region = "eu-west-1" 
}
#_________________________________________EKS MASTER___________________________________________

#_______VPC_______________
resource "aws_vpc" "eks" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support   = "true"
  enable_dns_hostnames = "true"

  tags = {  # kubernetes.io/cluster/* resource tags required for EKS and Kubernetes to discover and manage networking resources.
     "Name":"terraform-eks-node",
     "kubernetes.io/cluster/${var.cluster-name}":"shared",
    
  }
}

#_______SUBNETS_______________
data "aws_availability_zones" "available" {}

resource "aws_subnet" "eks" {
  count = 3

  availability_zone = "${data.aws_availability_zones.available.names[count.index]}"
  cidr_block        = "10.0.${count.index}.0/24"
  vpc_id            = "${aws_vpc.eks.id}"

  tags = {
    
     "Name" : "terraform-eks-demo-node",
     "kubernetes.io/cluster/${var.cluster-name}" : "shared",
    
  }
}
#_______INTERNET-GATEWAY_______________
resource "aws_internet_gateway" "eks" {
  vpc_id = "${aws_vpc.eks.id}"

  tags = {
    Name = "terraform-eks"
  }
}
#_______ROUTE-TABLE_______________
resource "aws_route_table" "eks" {
  vpc_id = "${aws_vpc.eks.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.eks.id}"
  }
}
#_______ROUTE-TABLE-ASSOCIATION_______________
resource "aws_route_table_association" "RT" {
  count = 3

  subnet_id      = "${aws_subnet.eks.*.id[count.index]}"
  route_table_id = "${aws_route_table.eks.id}"
}

#_______EKS-IAM-ROLE_______________
#IAM role and policy to allow the EKS service to manage or retrieve data from other AWS services
resource "aws_iam_role" "eks-cluster" {
  name = "terraform-eks-cluster"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "cluster-AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = "${aws_iam_role.eks-cluster.name}"
}

resource "aws_iam_role_policy_attachment" "cluster-AmazonEKSServicePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = "${aws_iam_role.eks-cluster.name}"
}

#_______SECURITY-GROUP_______________
resource "aws_security_group" "eks-cluster" {
  name        = "terraform-eks-cluster"
  description = "Cluster communication with worker nodes"
  vpc_id      = "${aws_vpc.eks.id}"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

   ingress {
    from_port =   443
    to_port     = 443
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = -1 
    to_port     = -1
    protocol    = "ICMP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "terraform-eks-cluster"
  }
}
#_________EKS-MASTER-CLUSTER__________________
resource "aws_eks_cluster" "mycluster" {
  name            = "${var.cluster-name}"
  role_arn        = "${aws_iam_role.eks-cluster.arn}"

  vpc_config {
    security_group_ids = ["${aws_security_group.eks-cluster.id}"]
    subnet_ids         = "${aws_subnet.eks.*.id}"
  }

  depends_on = [
    "aws_iam_role_policy_attachment.cluster-AmazonEKSClusterPolicy",
    "aws_iam_role_policy_attachment.cluster-AmazonEKSServicePolicy",
  ]
}

#__________________________________________WORKERS(NODES)_________________________________________

#_______WORKERS-IAM-ROLE_______________
# IAM role and policy to allow the worker nodes to manage 
#or retrieve data from other AWS services. It is used by Kubernetes to allow worker nodes to join the cluster.
resource "aws_iam_role" "node" {
  name = "terraform-eks-node"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "node-AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = "${aws_iam_role.node.name}"
}

resource "aws_iam_role_policy_attachment" "node-AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = "${aws_iam_role.node.name}"
}

resource "aws_iam_role_policy_attachment" "node-AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = "${aws_iam_role.node.name}"
}

resource "aws_iam_instance_profile" "node" {
  name = "terraform-eks"
  role = "${aws_iam_role.node.name}"
}

#_______WORKERS-SECURITY-GROUP_______________
resource "aws_security_group" "node" {
  name        = "terraform-eks-node"
  description = "Security group for all nodes in the cluster"
  vpc_id      = "${aws_vpc.eks.id}"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port =   443
    to_port     = 443
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  ingress {
    from_port   = -1 
    to_port     = -1
    protocol    = "ICMP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    
     "Name": "terraform-eks-node",
     "kubernetes.io/cluster/${var.cluster-name}": "owned",
    
  }
}

resource "aws_security_group_rule" "node-ingress-self" {
  description              = "Allow node to communicate with each other"
  from_port                = 0
  protocol                 = "-1"
  security_group_id        = "${aws_security_group.node.id}"
  source_security_group_id = "${aws_security_group.node.id}"
  to_port                  = 65535
  type                     = "ingress"
}

resource "aws_security_group_rule" "node-ingress-cluster" {
  description              = "Allow worker Kubelets and pods to receive communication from the cluster control plane"
  from_port                = 1025
  protocol                 = "tcp"
  security_group_id        = "${aws_security_group.node.id}"
  source_security_group_id = "${aws_security_group.eks-cluster.id}"
  to_port                  = 65535
  type                     = "ingress"
}

resource "aws_security_group_rule" "cluster-ingress-node-https" {
  description              = "Allow pods to communicate with the cluster API Server"
  from_port                = 443
  protocol                 = "tcp"
  security_group_id        = "${aws_security_group.eks-cluster.id}"
  source_security_group_id = "${aws_security_group.node.id}"
  to_port                  = 443
  type                     = "ingress"
}

#_______________SSH KEY____________
resource "aws_key_pair" "eks-KEY" {
  key_name   = "eks"
  public_key = "${file("./key/eks.pem.pub")}"
}

#______EC2-WORKERS-LAUCH-CONFIG____________

locals {  #required userdata for EKS worker nodes to
          # properly configure Kubernetes applications on the EC2 instance
  node-userdata = <<USERDATA
#!/bin/bash
set -o xtrace
/etc/eks/bootstrap.sh --apiserver-endpoint '${aws_eks_cluster.mycluster.endpoint}' --b64-cluster-ca '${aws_eks_cluster.mycluster.certificate_authority.0.data}' '${var.cluster-name}'
USERDATA
}

resource "aws_launch_configuration" "config" {
  associate_public_ip_address = true
  iam_instance_profile        = "${aws_iam_instance_profile.node.name}"
  image_id                    = "ami-059c6874350e63ca9" #AMI compatible with the specific Kubernetes version being deployed.
                                                        #for region eu-west-1
  instance_type               = "t3.medium"
  name_prefix                 = "terraform-eks"
  security_groups             = ["${aws_security_group.node.id}"]
  user_data_base64            = "${base64encode(local.node-userdata)}"
  key_name                    = "${aws_key_pair.eks-KEY.key_name}"

   
  lifecycle {
    create_before_destroy = true
  }
}

#______WORKERS-AUTOSCALING-GROUP____________
#EKS service does not currently provide managed resources for running worker nodes.
resource "aws_autoscaling_group" "autoscal_workers" {
  desired_capacity     = 3
  launch_configuration = "${aws_launch_configuration.config.id}"
  max_size             = 3
  min_size             = 1
  name                 = "terraform-eks-workers"
  vpc_zone_identifier  = "${aws_subnet.eks.*.id}"

  tag {
    key                 = "Name"
    value               = "terraform-eks-workers"
    propagate_at_launch = true
  }

  tag {
    key                 = "kubernetes.io/cluster/${var.cluster-name}" #kubernetes.io/cluster/* resource tag required.
    value               = "owned"
    propagate_at_launch = true
  }
}


#____KUBECTL-CONFIG__________________
#Configuring kubectl for EKS, must install aws-iam-authenticator first
data "template_file" "eks-auth" {

depends_on = [aws_eks_cluster.mycluster,]

    template = "${file("./kubeconfig/kubectl_eks.tpl")}"

    vars = {
       cluster-endpoint = "${aws_eks_cluster.mycluster.endpoint}"
       certificate      = "${aws_eks_cluster.mycluster.certificate_authority.0.data}"
       cluster-name     = "${var.cluster-name}"
    }

}

resource "local_file" "eks-auth" {
  content  = "${data.template_file.eks-auth.rendered}"
  filename = "config.yml"
}

resource "null_resource" "kubectl_eks" {
 depends_on =[
  local_file.eks-auth,
 ]
  provisioner "local-exec" {
     command = " cp ${local_file.eks-auth.filename} ~/.kube/config"
  }
}

#______Kubernetes Configuration to Join Worker Nodes____________
data "template_file" "aws-auth" {

depends_on = [aws_iam_role.node,
aws_autoscaling_group.autoscal_workers,]

    template = "${file("./kubeconfig/config.tpl")}"

    vars = {
       role    = "${aws_iam_role.node.arn}"
    }

}

resource "local_file" "aws-auth" {
  content  = "${data.template_file.aws-auth.rendered}"
  filename = "aws-auth.yml"
}

resource "null_resource" "kubectl_awsauth" {
 depends_on =[
 local_file.aws-auth,
 null_resource.kubectl_eks,
 ]
  provisioner "local-exec" {
     command = " kubectl apply -f ${local_file.aws-auth.filename}"
  }
}

/*




 
  

