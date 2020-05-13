#apply the version 1.8+ manifests to the cluster. 
#kubectl apply -f metrics-server-0.3.6/deploy/1.8+/

#Deploy the Dashboard
#kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.0.0-beta4/aio/deploy/recommended.yaml

#create an eks-admin service account and cluster role binding to securely connect to the dashboard with admin-level permissions.
#kubectl apply -f ./kubeconfig/eks-admin-service-account.yaml

#Retrieve an authentication token for the eks-admin service account to connect to the Dashboard.
#kubectl -n kube-system describe secret $(kubectl -n kube-system get secret | grep eks-admin | awk '{print $1}') > dashboard_auth_token.txt
