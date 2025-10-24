# Migration Project

## Table of Contents
1. [Set development environment](#setup-dev-env)
2. [ScyllaDB](#scylladb)

<div id="setup-dev-env"/>

## 1. Set up development environment

## 1.1. Set up K8s

- Create a K8s cluster:
```
envsubst < ./k8s/kind_cluster.yml | kind create cluster --config -
```

- Check `cluster-info`:
```
kubectl cluster-info --context kind-my-cluster
```

- Connect to pre-exsisting network:
```
docker network connect lakehouse_platform my-cluster-control-plane
docker network connect lakehouse_platform my-cluster-worker
```

## 1.2. Set up MinIO

- Run `docker compose`:
```
docker compose -f ./minio/docker-compose.yml up -d
```


<div id="scylladb"/>

## 2. ScyllaDB

See [ScyllaDB Migration](scylladb/README.md) for more info.