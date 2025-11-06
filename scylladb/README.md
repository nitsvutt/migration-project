# ScyllaDB Migration

## Table of Contents
1. [Set up ScyllaDB](#setup-scylladb)
2. [Init data](#init-data)
3. [Migrate data](#migrate-data)

<div id="setup-scylladb"/>

### 1. Set up ScyllaDB

- Build ScyllaDB image:
```
docker build \
    --build-arg SCYLLADB_AUTH_TOKEN=$SCYLLADB_AUTH_TOKEN \
    --build-arg MINIO_ROOT_USER=$MINIO_ROOT_USER \
    --build-arg MINIO_ROOT_PASSWORD=$MINIO_ROOT_PASSWORD \
    -t nitsvutt/scylla_with_agent:5.4.2 \
    -f $PROJECT_PATH/lakehouse-platform/scylladb/Dockerfile \
    .
```

#### 1.1. On K8s

See [Kubernetes in Action](https://github.com/nitsvutt/kubernetes-in-action) for more info.

#### 1.2. Using Docker Compose

- Run `docker compose`:
```
docker compose -f $PROJECT_PATH/lakehouse-platform/scylladb/docker-compose.yml up -d
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

### 2. Init data

- Generate data:
```
python $PROJECT_PATH/migration-project/scylladb/workspace/generate_data.py
```

- Copy data to one pod:
```
kubectl cp ${COMMON_PATH}/tmp/users.csv scylla/scylla-0:/var/lib/scylla/
kubectl cp ${COMMON_PATH}/tmp/products.csv scylla/scylla-0:/var/lib/scylla/
kubectl cp ${COMMON_PATH}/tmp/orders.csv scylla/scylla-0:/var/lib/scylla/
```

- Copy `init_schema.sql` and `load_data.sql` to one pod:
```
kubectl cp $PROJECT_PATH/migration-project/scylladb/workspace/init_schemasql scylla/scylla-0:/var/lib/scylla/
kubectl cp $PROJECT_PATH/migration-project/scylladb/workspace/load_data.sql scylla/scylla-0:/var/lib/scylla/
```

- Init schema:
```
kubectl exec -it scylla-0 -n scylla -- \
    cqlsh -u cassandra -f /var/lib/scylla/init_schema.sql
```

- Load data:
```
kubectl exec -it scylla-0 -n scylla -- \
    cqlsh -u cassandra -f /var/lib/scylla/load_data.sql
```

<div id="migrate-data"/>

### 3. Migrate data

### 3.1. Using `nodetool snapshot` and `nodetool refresh`

- Backup schema:
```
kubectl exec -it scylla-0 -n scylla -- \
    cqlsh -u cassandra -e "DESC SCHEMA" > ./scylladb/workspace/backup_schema.sql
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
kubectl cp ./scylla/workspace/backup_schema.sql scylla-0:/var/lib/scylla/backup_schema.sql
```
```
kubectl exec -it scylla-0 -n scylla -- \
    cqlsh -u cassandra -f /var/lib/scylla/backup_schema.sql
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

### 3.2. Using `sctool backup` and `sctool restore`

- Backup data to MinIO (can test with `--dry-run` flag):
```
kubectl exec -it scylla-manager-0 -c scylla-manager -n scylla -- \
    sctool backup -c my-cluster -L s3:scylladb -K sherlock
```

- Check backup progress:
```
kubectl exec -it scylla-manager-0 -c scylla-manager -n scylla -- \
    sctool progress -c my-cluster backup/91665116-b68c-4dde-b4c2-092c78a44020
```

- Restore schema (can test with `--dry-run` flag):
```
docker exec -it scylla-manager \
    sctool restore -c my-cluster -L s3:scylladb -T sm_20251028022323UTC --restore-schema
```

- Rolling restart Scylla Cluster (only for ScyllaDB 5.4/2024.1 or older), remember to check `nodetool status` for each operation:
```
docker exec -it scylla-node1 \
    nodetool drain
docker exec -it scylla-node1 \
    supervisorctl restart scylla
```
```
docker exec -it scylla-node2 \
    nodetool drain
docker exec -it scylla-node2 \
    supervisorctl restart scylla
```

- Restore tables (can test with `--dry-run` flag):
```
docker exec -it scylla-manager \
    sctool restore -c my-cluster -L s3:scylladb -K sherlock -T sm_20251028022323UTC --restore-tables
```

- Check restore progress:
```
docker exec -it scylla-manager \
    sctool progress -c my-cluster restore/2b789d3e-dd80-4d92-90f4-e0d9e7314413
```

### 3.3. By adding new data center to the existing cluster

- Set up a data center named `gcp-dc`:
```
docker compose -f $PROJECT_PATH/lakehouse-platform/scylladb/docker-compose-mdc-1.yml up -d
```

- Check status:
```
docker exec -it scylla-node1 \
    nodetool status
```

- Copy data to one node:
```
docker cp ${COMMON_PATH}/tmp/users.csv scylla-node1:/var/lib/scylla/
docker cp ${COMMON_PATH}/tmp/products.csv scylla-node1:/var/lib/scylla/
docker cp ${COMMON_PATH}/tmp/orders.csv scylla-node1:/var/lib/scylla/
```

- Copy `init_schema.sql` and `load_data.sql` to one node:
```
docker cp $PROJECT_PATH/migration-project/scylladb/workspace/init_schema.sql scylla-node1:/var/lib/scylla/
docker cp $PROJECT_PATH/migration-project/scylladb/workspace/load_data.sql scylla-node1:/var/lib/scylla/
```

- Init schema:
```
docker exec -it scylla-node1 \
    cqlsh -u cassandra -f /var/lib/scylla/init_schema.sql
```

- Load data:
```
docker exec -it scylla-node1 \
    cqlsh -u cassandra -f /var/lib/scylla/load_data.sql
```

- Set up a clean data center named `fci-dc`:
```
docker compose -f $PROJECT_PATH/lakehouse-platform/scylladb/docker-compose-mdc-2.yml up -d
```

- Check status:
```
docker exec -it scylla-node1 \
    nodetool status
```

- Alter keyspace add new data center:
```
docker exec -it scylla-node1 \
    cqlsh -u cassandra -e "
        ALTER KEYSPACE system_auth
        WITH replication = {'class': 'NetworkTopologyStrategy', 'gcp-dc': 3, 'fci-dc': 3};
        ALTER KEYSPACE system_distributed
        WITH replication = {'class': 'NetworkTopologyStrategy', 'gcp-dc': 3, 'fci-dc': 3};
        ALTER KEYSPACE system_traces
        WITH replication = {'class': 'NetworkTopologyStrategy', 'gcp-dc': 3, 'fci-dc': 3}
    "
```
```
docker exec -it scylla-node1 \
    cqlsh -u cassandra -e "
        ALTER KEYSPACE sherlock
        WITH replication = {'class': 'NetworkTopologyStrategy', 'gcp-dc': 3, 'fci-dc': 3}
    "
```

- Rebuild data on each node of `fci-dc`:
```
docker exec -it scylla-node3 \
    nodetool rebuild gcp-dc
```
```
docker exec -it scylla-node4 \
    nodetool rebuild gcp-dc
```

- Repair partition range on each node of the cluster (full cluster repair):
```
docker exec -it scylla-node1 \
    nodetool repair -pr
```
```
docker exec -it scylla-node2 \
    nodetool repair -pr
```
```
docker exec -it scylla-node3 \
    nodetool repair -pr
```
```
docker exec -it scylla-node4 \
    nodetool repair -pr
```

- Test by inserting data to `gcp-dc`:
```
docker exec -it scylla-node1 \
    cqlsh -u cassandra -e "
        INSERT INTO sherlock.users (user_id, email, first_name, last_name, registration_date)
        VALUES (uuid(), 'nitsvutt@gmail.com', 'Vu', 'Tran', toTimeStamp(now()))
    "
```

- Alter keyspace remove old data center:
```
docker exec -it scylla-node1 \
    cqlsh -u cassandra -e "
        ALTER KEYSPACE system_auth
        WITH replication = {'class': 'NetworkTopologyStrategy', 'fci-dc': 3};
        ALTER KEYSPACE system_distributed
        WITH replication = {'class': 'NetworkTopologyStrategy', 'fci-dc': 3};
        ALTER KEYSPACE system_traces
        WITH replication = {'class': 'NetworkTopologyStrategy', 'fci-dc': 3}
    "
```
```
docker exec -it scylla-node1 \
    cqlsh -u cassandra -e "
        ALTER KEYSPACE sherlock
        WITH replication = {'class': 'NetworkTopologyStrategy', 'fci-dc': 3}
    "
```

- Remove `gcp-dc`:
```
docker exec -it scylla-node1 \
    nodetool decommission
```
```
docker exec -it scylla-node2 \
    nodetool decommission
```

- Test by inserting data to `fci-dc`:
```
docker exec -it scylla-node3 \
    cqlsh -u cassandra -e "
        INSERT INTO sherlock.users (user_id, email, first_name, last_name, registration_date)
        VALUES (uuid(), 'nitsvutt@gmail.com', 'Vu', 'Tran', toTimeStamp(now()))
    "
```