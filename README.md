# Migration Project

## Table of Contents
1. [Set up K8s](#setup-k8s)
2. [Set up ScyllaDB](#setup-scylladb)

<div id="setup-k8s"/>

## 1. Set up K8s

- Create a K8s cluster:
```
envsubst < ./k8s/kind_cluster.yml | kind create cluster --config -
```

- Check `cluster-info`:
```
kubectl cluster-info --context kind-my-cluster
```

<div id="setup-scylladb"/>

## 2. Set up ScyllaDB

- Create `scylladb` namespace:
```
kubectl create namespace scylladb
```

- Create persistent volume:
```
kubectl apply -f ./scylladb/scylladb-persistent-volume.yml
```

- Create config map:
```
kubectl apply -f ./scylladb/scylladb-configmap.yml
```

- Create service:
```
kubectl apply -f ./scylladb/scylladb-service.yml
```

- Create statefulset:
```
kubectl apply -f ./scylladb/scylladb-statefulset.yml
```

- Create statefulset:
```
kubectl exec -it scylladb-0 -n scylladb -- cqlsh
```