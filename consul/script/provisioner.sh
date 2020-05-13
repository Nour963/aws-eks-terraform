#!/bin/bash 

#Create service account names tiller & ClusterRoleBinding with cluster-admin permissions to the tiller service account.
kubectl apply -f ./kubeconfig/helm-rbac.yaml

#Installs Tiller on our cluster
helm init --service-account=tiller --history-max 300

#Deploy Consul with Helm after git clone https://github.com/hashicorp/consul-helm.git
sleep 60
cd consul-helm/ && helm install --name consul -f values.yaml .

#configure Consul DNS in Kubernetes
cd ..
export CONSUL_DNS_IP=$(kubectl get svc consul-consul-dns -o jsonpath='{.spec.clusterIP}')
bash consuldns.sh > coredns.yaml
kubectl apply -f coredns.yaml


