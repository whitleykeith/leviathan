#!/bin/bash
usage() { printf "Usage: ./install.sh -u USER -b BRANCH \nUser/Branch should point to your fork of the airflow-kubernetes repository" 1>&2; exit 1; }
GIT_ROOT=$(git rev-parse --show-toplevel)
while getopts b:u: flag
do
    case "${flag}" in
        u) user=${OPTARG};;
        b) branch=${OPTARG};;
        *) usage;;
    esac
done

if [[ -z "$user" || -z $branch ]]; then 
    usage
fi

kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl apply -f $GIT_ROOT/apps/airflow
kubectl apply -f $GIT_ROOT/apps/argocd

YQ_VERSION=3.4.1
YQ_BINARY=yq_linux_amd64
wget https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/${YQ_BINARY} -O /usr/bin/yq &&\
    chmod +x /usr/bin/yq

cat $GIT_ROOT/apps/airflow/airflow.yaml | \
    yq w - 'spec.source.helm.parameters.(name==dags.gitSync.repo).value' https://github.com/$user/airflow-kubernetes.git | \
    yq w - 'spec.source.helm.parameters.(name==dags.gitSync.branch).value' $branch | \
    kubectl apply -f -






argo_route=$(oc get routes -n argocd -o json | jq -r '.items[0].spec.host')
airflow_route=$(oc get routes -n airflow -o json | jq -r '.items[0].spec.host')

echo "Argo is setting up your Cluster, check the status here: $(argo_route)"
echo "Airflow will be at $(airflow_route), user/pass is admin/admin"


oc -n airflow adm policy add-scc-to-user privileged -z airflow-scheduler 
oc -n airflow adm policy add-scc-to-user privileged -z airflow-webserver
oc -n airflow adm policy add-scc-to-user privileged -z airflow-worker
oc -n airflow adm policy add-scc-to-user privileged -z builder
oc -n airflow adm policy add-scc-to-user privileged -z deployer
oc -n airflow adm policy add-scc-to-user privileged -z default