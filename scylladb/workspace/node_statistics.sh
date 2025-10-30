#!/bin/bash

nodetool cfstats sherlock -H | awk '
BEGIN {
  printf "%-30s %-30s %-20s %-20s %-20s\n", "Keyspace", "Table", "Live", "Total", "Memtable"
}
/^Keyspace : / {
  ks = $3
}
/Table:/ {
  t = $2
}
/Space used \(live\):/ {
  live_size = $4 " " $5
}
/Space used \(total\):/ {
  total_size = $4 " " $5
}
/Memtable data size:/ {
  memtable_size = $4 " " $5
  printf "%-30s %-30s %-20s %-20s %-20s\n", ks, t, live_size, total_size, memtable_size
}
'