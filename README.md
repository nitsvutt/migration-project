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

### 2.1. Set up ScyllaDB

- Build ScyllaDB image:
```
docker build \
    --build-arg SCYLLADB_AUTH_TOKEN=$SCYLLADB_AUTH_TOKEN \
    --build-arg MINIO_ROOT_USER=$MINIO_ROOT_USER \
    --build-arg MINIO_ROOT_PASSWORD=$MINIO_ROOT_PASSWORD \
    -t nitsvutt/scylla_with_agent:5.4.2 \
    -f ./scylladb/Dockerfile \
    .
```

#### 2.1.1. On K8s

- Create `scylla` namespace:
```
kubectl create namespace scylla
```

- Create persistent volume:
```
kubectl apply -f ./scylladb/scylla-persistent-volume.yml
```

- Create service:
```
kubectl apply -f ./scylladb/scylla-service.yml
```

- Create config map:
```
kubectl apply -f ./scylladb/scylla-configmap.yml
```

- Create Scylla and Scylla Manager statefulset:
```
kubectl apply -f ./scylladb/scylla-statefulset.yml
```

- Check Scylla Cluster:
```
kubectl exec -it scylla-0 -n scylla -- \
    nodetool status
```

- Add Scylla Cluster for Scylla Manager:
```
kubectl exec -it scylla-manager-0 -c scylla-manager -n scylla -- \
    sctool cluster add \
    --host scylla-0.scylla-clusterip.scylla.svc.cluster.local \
    --name my-cluster \
    --auth-token $SCYLLADB_AUTH_TOKEN
```

#### 2.1.2. Using Docker Compose

- Run `docker compose`:
```
docker compose -f ./scylladb/docker-compose.yml up -d
```

- Check Scylla Cluster:
```
docker exec -it scylla-node1 \
    nodetool status
```

- Add cluster for Scylla Manager:
```
docker exec -it scylla-manager \
    sctool cluster add \
    --host scylla-node1 \
    --name my-cluster \
    --auth-token $SCYLLADB_AUTH_TOKEN
```

<div id="init-data"/>

### 2.2. Init data

- Generate data:
```
python ./scylladb/development/generate_data.py
```

- Copy `init_schema.sql` and `load_data.sql` to one pod:
```
kubectl cp ./scylladb/development/init_schema.sql scylla/scylla-0:/var/lib/scylla
kubectl cp ./scylladb/development/load_data.sql scylla/scylla-0:/var/lib/scylla
```

- Init schema:
```
kubectl exec -it scylla-0 -n scylla -- \
    cqlsh -f /var/lib/scylla/init_schema.sql
```

- Load data:
```
kubectl exec -it scylla-0 -n scylla -- \
    cqlsh -f /var/lib/scylla/load_data.sql
```

### 2.3. Migrate data

### 2.3.1. Using `nodetool snapshot` and `nodetool refresh`

- Backup schema:
```
kubectl exec -it scylla-0 -n scylla -- \
    cqlsh -e "DESC SCHEMA" > ./development/backup_schema.sql
```

- Create snapshot:
```
kubectl exec -it scylla-0 -n scylla -- \
    nodetool snapshot -t 20251019_snp -- sherlock
```
```
kubectl exec -it scylla-1 -n scylla -- \
    nodetool snapshot -t 20251019_snp -- sherlock
```

- Copy data from old cluster to MinIO:
```
echo '#!/bin/bash
for snapshot_dir in /tmp/scylladb/data1/data/sherlock/*/snapshots/20251019_snp/; do
    tmp="${snapshot_dir#/tmp/scylladb/data1/data/sherlock/}"
    table_name_uid="${tmp%/snapshots/20251019_snp/}"
    table_name="${table_name_uid%-*}"
    mc cp -r /tmp/scylladb/data1/data/sherlock/$table_name_uid/snapshots/20251019_snp/ minio/scylladb/data1/data/sherlock/$table_name/snapshots/20251019_snp/
done' > move_node1.sh
```
```
echo '#!/bin/bash
for snapshot_dir in /tmp/scylladb/data2/data/sherlock/*/snapshots/20251019_snp/; do
    tmp="${snapshot_dir#/tmp/scylladb/data2/data/sherlock/}"
    table_name_uid="${tmp%/snapshots/20251019_snp/}"
    table_name="${table_name_uid%-*}"
    mc cp -r /tmp/scylladb/data2/data/sherlock/$table_name_uid/snapshots/20251019_snp/ minio/scylladb/data2/data/sherlock/$table_name/snapshots/20251019_snp/
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

- Restore schema:
```
kubectl cp ./scylla/development/backup_schema.sql scylla-0:/var/lib/scylla/backup_schema.sql
```
```
kubectl exec -it scylla-0 -n scylla -- \
    cqlsh -f /var/lib/scylla/backup_schema.sql
```

- Refresh data:
```
echo '#!/bin/bash
for tmp_dir in /var/lib/scylla/tmp/data1/data/sherlock/*/snapshots/20251019_snp/; do
    tmp="${tmp_dir#/var/lib/scylla/tmp/data2/data/sherlock/}"
    table_name="${tmp%/snapshots/20251019_snp/}"
    for upload_dir in /var/lib/scylla/data/sherlock/orders-*/upload/; do
        cp $tmp_dir/* $upload_dir
    done
done' > upload_node1.sh; bash upload_node1.sh

```
```
nodetool refresh -las -- sherlock orders
```
```
echo '#!/bin/bash
for tmp_dir in /var/lib/scylla/tmp/data2/data/sherlock/*/snapshots/20251019_snp/; do
    tmp="${tmp_dir#/var/lib/scylla/tmp/data2/data/sherlock/}"
    table_name="${tmp%/snapshots/20251019_snp/}"
    for upload_dir in /var/lib/scylla/data/sherlock/orders-*/upload/; do
        cp $tmp_dir/* $upload_dir
    done
done' > upload_node2.sh; bash upload_node2.sh
```
```
nodetool refresh -las -- sherlock orders
```

### 2.3.2. Using `sctool backup` and `sctool restore`

- Backup data to MinIO (can test with `--dry-run` flag):
```
kubectl exec -it scylla-manager-0 -c scylla-manager -n scylla -- \
    sctool backup -c my-cluster -L s3:scylladb -K sherlock
```

- Check backup progress:
```
kubectl exec -it scylla-manager-0 -c scylla-manager -n scylla -- \
    sctool progress -c my-cluster backup/d76aabc0-16e1-4afb-993d-b30adc8885e3
```

- Restore schema (can test with `--dry-run` flag):
```
docker exec -it scylla-manager \
    sctool restore -c my-cluster -L s3:scylladb -T sm_20251022095353UTC --restore-schema
```

- Rolling restart Scylla Cluster (only for ScyllaDB 5.4/2024.1 or older), remember to check `nodetool status` for each operation:
```
docker exec -it scylla-node1 \
    supervisorctl restart scylla
```
```
docker exec -it scylla-node2 \
    supervisorctl restart scylla
```

- Restore tables (can test with `--dry-run` flag):
```
docker exec -it scylla-manager \
    sctool restore -c my-cluster -L s3:scylladb -K sherlock -T sm_20251022090826UTC --restore-tables
```

- Check restore progress:
```
docker exec -it scylla-manager \
    sctool progress -c my-cluster restore/4e1a6d36-ff69-46a5-91f9-d3bb109c1db3
```

### 2.3.3. Note

- Ensure that all of your materialized views were created with at least a filter like `IS NOT NULL`. If not, when recreating restored views, it will raise a stupid error called `WHERE` nothing.