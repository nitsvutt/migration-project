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
    nodetool snapshot -t 20251019_snp -- sherlock
```
```
kubectl exec -it scylladb-1 -n scylladb -- \
    nodetool snapshot -t 20251019_snp -- sherlock
```

- Copy data from old cluster to MinIO:
```
echo '#!/bin/bash
for snapshot_dir in /tmp/scylladb/data1/data/sherlock/**/snapshots/20251019_snp/; do
    tmp="${snapshot_dir#/tmp/scylladb/data1/data/sherlock/}"
    table_name="${tmp%/snapshots/20251019_snp/}"
    mc cp -r /tmp/scylladb/data1/data/sherlock/$table_name/snapshots/20251019_snp/ minio/scylladb/data1/data/sherlock/$table_name/snapshots/20251019_snp/
done' > move_node1.sh
```
```
echo '#!/bin/bash
for snapshot_dir in /tmp/scylladb/data2/data/sherlock/**/snapshots/20251019_snp/; do
    tmp="${snapshot_dir#/tmp/scylladb/data2/data/sherlock/}"
    table_name="${tmp%/snapshots/20251019_snp/}"
    mc cp -r /tmp/scylladb/data2/data/sherlock/$table_name/snapshots/20251019_snp/ minio/scylladb/data2/data/sherlock/$table_name/snapshots/20251019_snp/
done' > move_node2.sh
```
```
bash move_node1.sh
```
```
bash move_node2.sh
```

- Copy data from MinIO to new cluster:
```
mc cp --recursive minio/scylladb/data1 /target/data1/tmp/
```
```
mc cp --recursive minio/scylladb/data2 /target/data2/tmp/
```

- Restore data:
```
cp /var/lib/scylla/tmp/data1/data/sherlock/orders-e2c5cd50acfe11f097a50cb3f313a56b/snapshots/20251019_snp/* /var/lib/scylla/data/sherlock/orders-303d9e10ad0d11f084680fae08788721/upload/
```
```
nodetool refresh -las -- sherlock orders
```
```
cp /var/lib/scylla/tmp/data2/data/sherlock/orders-e2c5cd50acfe11f097a50cb3f313a56b/snapshots/20251019_snp/* /var/lib/scylla/data/sherlock/orders-303d9e10ad0d11f084680fae08788721/upload/
```
```
nodetool refresh -las -- sherlock orders
```

### 2.3.2. Using ScyllaDB Migrator (a Spark built-in class)