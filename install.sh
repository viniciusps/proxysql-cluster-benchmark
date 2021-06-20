#!/bin/bash

KUBE_VERSION=1.18.16
PROXYSQL_VERSION=2.1.1
ROOT_DIR=$(pwd)

###### create kube cluster on minikube

minikube start --vm-driver=hyperkit -p kube-proxysql --kubernetes-version=v${KUBE_VERSION}
minikube -p kube-proxysql addons enable ingress

MINIKUBE_IP=$(minikube ip -p kube-proxysql)
DNS_NAME=$MINIKUBE_IP.nip.io

####### install mysql

helm repo add bitnami https://charts.bitnami.com/bitnami

helm install mysql -f mysql/values.yaml bitnami/mysql

####### Install mysql exporter

helm install mysql-primary -f mysql/mysql_exporter_primary_values.yaml prometheus-community/prometheus-mysql-exporter

helm install mysql-secondary -f mysql/mysql_exporter_secondary_values.yaml prometheus-community/prometheus-mysql-exporter

############ install proxysql + connect to mysql

sed -i -e s/VERSION/$PROXYSQL_VERSION/ proxysql-cluster/Dockerfile

eval $(minikube -p kube-proxysql docker-env)

docker build -t local/proxysql:$PROXYSQL_VERSION proxysql-cluster/

sed -i -e s/VERSION/$PROXYSQL_VERSION/ proxysql-cluster/proxysql-statefulset.yaml

kubectl create configmap proxysqlcm --from-file=proxysql-cluster/proxysql.cnf

kubectl apply -f proxysql-cluster/proxysql-statefulset.yaml

kubectl apply -f proxysql-cluster/proxysql-service.yaml

kubectl apply -f proxysql-cluster/proxysql-headless.yaml

################ install WP

sed -i -e s/DNS_NAME/$DNS_NAME/ wordpress/values.yaml

helm install wordpress -f wordpress/values.yaml bitnami/wordpress

############### Install prom

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts

helm install prometheus -f prometheus/prometheus-values.yaml prometheus-community/prometheus

sed -i -e s/DNS_NAME/$DNS_NAME/ prometheus/prometheus-ingress.yaml

kubectl apply -f prometheus/prometheus-ingress.yaml

############### Install Granafa

helm repo add grafana https://grafana.github.io/helm-charts

helm install grafana -f grafana/values.yaml grafana/grafana

sed -i -e s/DNS_NAME/$DNS_NAME/ grafana/grafana-ingress.yaml

kubectl apply -f grafana/grafana-ingress.yaml

echo "MYSQL PASSWORD: $(kubectl get secret --namespace default mysql -o jsonpath="{.data.mysql-root-password}" | base64 --decode)"

echo "Grafana PASSWORD: $(kubectl get secret grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo)"
