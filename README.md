# Migration Project

## Table of Contents
1. [Set up development environment](#setup-dev-env)
2. [ScyllaDB](#scylladb)

<div id="setup-dev-env"/>

## 1. Set up development environment

## 1.1. Clone installation projects

- Clone lakehouse-platforms and k8s-in-action projects:
```
mkdir $PROJECT_PATH/lakehouse-platform
git clone https://github.com/nitsvutt/lakehouse-platform.git $PROJECT_PATH/lakehouse-platform
```
```
mkdir $PROJECT_PATH/kubernetes-in-action
git clone https://github.com/nitsvutt/kubernetes-in-action.git $PROJECT_PATH/kubernetes-in-action
```

### 1.2. Set up K8s

See [Kubernetes in Action](https://github.com/nitsvutt/kubernetes-in-action) for more info.

### 1.3. Set up MinIO

- Run `docker compose`:
```
docker compose -f $PROJECT_PATH/lakehouse-platform/minio/docker-compose.yml up -d
```

<div id="scylladb"/>

## 2. ScyllaDB Migration

See [ScyllaDB Migration](scylladb/README.md) for more info.