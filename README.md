# Migration Project

## Table of Contents
1. [Set development environment](#setup-dev-env)
2. [ScyllaDB](#scylladb)

<div id="setup-dev-env"/>

## 1. Set development environment

## 1.1. Set up K8s

- Create a K8s cluster:
```
envsubst < ./k8s/kind_cluster.yml | kind create cluster --config -
```

- Check `cluster-info`:
```
kubectl cluster-info --context kind-my-cluster
```

## 1.2. Set up MinIO

- Run `docker compose`:
```
docker compose -f ./minio/docker-compose.yml up -d
```


<div id="scylladb"/>

## 2. ScyllaDB

### 2.1. Set up ScyllaDB

#### 2.1.1. On K8s

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

#### 2.1.2. Using Docker Compose

- Run `docker compose`:
```
docker compose -f ./scylladb/docker-compose.yml up -d
```

<div id="init-data"/>

### 2.2. Init data

- Generate data:
```
python ./scylladb/development/generate_data.py
```

- Copy `init_schema.sql` and `load_data.sql` to volume path:
```
cp ./scylladb/development/*.sql $COMMON_PATH/k8s/scylladb/data1
```

- Init schema:
```
kubectl exec -it scylladb-0 -n scylladb -- \
    cqlsh -f /var/lib/scylla/init_schema.sql
```

- Load data:
```
kubectl exec -it scylladb-0 -n scylladb -- \
    cqlsh -f /var/lib/scylla/load_data.sql
```

### 2.3. Migrate data

### 2.3.1. Using `nodetool` snapshot, backup, and restore

- Create snapshot:
```
kubectl exec -it scylladb-0 -n scylladb -- \
    nodetool snapshot -t 20251019_snp -sf -- sherlock
```
```
kubectl exec -it scylladb-1 -n scylladb -- \
    nodetool snapshot -t 20251019_snp -sf -- sherlock
```

- Copy data to MinIO:
```
mc cp /tmp/scylladb/ minio/scylladb/
```

### 2.3.2. Using ScyllaDB Migrator (a Spark built-in class)