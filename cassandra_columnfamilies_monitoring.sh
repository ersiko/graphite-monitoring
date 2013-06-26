#!/bin/bash
echo "que empiezo" >> /tmp/cf_tmpfile
now=`date +%s`
host=`cat /etc/environment|cut -d"@" -f 2|cut -d" " -f 1`
port=8081
carbon_server=manage
tree=servers

date >> /tmp/cf_tmpfile
for column_family in `curl -s http://$host:$port|grep "org.apache.cassandra.db:type=ColumnFamilies,keyspace=" | awk -F"ColumnFamilies,keyspace=" '{print $2}'|cut -d"<" -f1`;do
#  echo $column_family
#  break
  keyspace=`echo $column_family|cut -d, -f1`
  cf=`echo $column_family|cut -d"=" -f2`
  echo $cf >> /tmp/cf_tmpfile
  # ColumnFamily data
  data="$data `curl -s http://$host:$port/mbean?objectname=org.apache.cassandra.db%3Atype%3DColumnFamilies%2Ckeyspace%3D$column_family|egrep "TotalDiskSpaceUsed|LiveDiskSpaceUsed|LiveSSTableCount|MemtableDataSize|MemtableColumnsCount|MemtableSwitchCount|PendingTasks|ReadCount|WriteCount|RecentReadLatencyMicros|RecentWriteLatencyMicros"|cut -d">" -f8|cut -d"<" -f1|awk -v now=$now -v host=$host -v tree=$tree -v keyspace=$keyspace -v cf=$cf '(NR == 1) {printf("%s.%s.cassandra.keyspaces.%s.%s.TotalDiskSpaceUsed %s %s\\\n", tree, host, keyspace, cf, $0, now)} (NR == 2) {printf("%s.%s.cassandra.keyspaces.%s.%s.LiveDiskSpaceUsed %s %s\\\n", tree, host, keyspace, cf, $0, now)} (NR == 3) {printf("%s.%s.cassandra.keyspaces.%s.%s.LiveSSTableCount %s %s\\\n", tree, host, keyspace, cf, $0, now)} (NR == 4) {printf("%s.%s.cassandra.keyspaces.%s.%s.MemtableDataSize %s %s\\\n", tree, host, keyspace, cf, $0, now)} (NR == 5) {printf("%s.%s.cassandra.keyspaces.%s.%s.MemtableColumnsCount %s %s\\\n", tree, host, keyspace, cf, $0, now)} (NR == 6) {printf("%s.%s.cassandra.keyspaces.%s.%s.MemtableSwitchCount %s %s\\\n", tree, host, keyspace, cf, $0, now)} (NR == 7) {printf("%s.%s.cassandra.keyspaces.%s.%s.PendingTasks %s %s\\\n", tree, host, keyspace, cf, $0, now)} (NR == 8) {printf("%s.%s.cassandra.keyspaces.%s.%s.ReadCount %s %s\\\n", tree, host, keyspace, cf, $0, now)} (NR == 9) {printf("%s.%s.cassandra.keyspaces.%s.%s.WriteCount %s %s\\\n", tree, host, keyspace, cf, $0, now)} (NR == 10) {printf("%s.%s.cassandra.keyspaces.%s.%s.RecentReadLatencyMicros %s %s\\\n", tree, host, keyspace, cf, $0, now)} (NR == 11) {printf("%s.%s.cassandra.keyspaces.%s.%s.RecentReadLatencyMicros %s %s\\\n", tree, host, keyspace, cf, $0, now)}'`"
  # RowCache data
  data="$data `curl -s http://$host:$port/mbean?objectname=org.apache.cassandra.db%3Atype%3DCaches%2Ckeyspace%3D$keyspace%2Ccache%3D${cf}KeyCache | egrep "Capacity|Hits|RecentHitRate|Requests|Size"|cut -d">" -f8|cut -d"<" -f1 | awk -v now=$now -v host=$host -v tree=$tree -v keyspace=$keyspace -v cf=$cf '(NR == 1) {printf("%s.%s.cassandra.keyspaces.%s.%s.KeyCache.Capacity %s %s\\\n", tree, host, keyspace, cf, $0, now)} (NR == 2) {printf("%s.%s.cassandra.keyspaces.%s.%s.KeyCache.Hits %s %s\\\n", tree, host, keyspace, cf, $0, now)} (NR == 3) {printf("%s.%s.cassandra.keyspaces.%s.%s.KeyCache.RecentHitRate %s %s\\\n", tree, host, keyspace, cf, $0, now)} (NR == 4) {printf("%s.%s.cassandra.keyspaces.%s.%s.KeyCache.Requests %s %s\\\n", tree, host, keyspace, cf, $0, now)} (NR == 5) {printf("%s.%s.cassandra.keyspaces.%s.%s.KeyCache.Size %s %s\\\n", tree, host, keyspace, cf, $0, now)} '`"
  # KeyCache data
  data="$data `curl -s http://$host:$port/mbean?objectname=org.apache.cassandra.db%3Atype%3DCaches%2Ckeyspace%3D$keyspace%2Ccache%3D${cf}RowCache | egrep "Capacity|Hits|RecentHitRate|Requests|Size"|cut -d">" -f8|cut -d"<" -f1 | awk -v now=$now -v host=$host -v tree=$tree -v keyspace=$keyspace -v cf=$cf '(NR == 1) {printf("%s.%s.cassandra.keyspaces.%s.%s.RowCache.Capacity %s %s\\\n", tree, host, keyspace, cf, $0, now)} (NR == 2) {printf("%s.%s.cassandra.keyspaces.%s.%s.RowCache.Hits %s %s\\\n", tree, host, keyspace, cf, $0, now)} (NR == 3) {printf("%s.%s.cassandra.keyspaces.%s.%s.RowCache.RecentHitRate %s %s\\\n", tree, host, keyspace, cf, $0, now)} (NR == 4) {printf("%s.%s.cassandra.keyspaces.%s.%s.RowCache.Requests %s %s\\\n", tree, host, keyspace, cf, $0, now)} (NR == 5) {printf("%s.%s.cassandra.keyspaces.%s.%s.RowCache.Size %s %s\\\n", tree, host, keyspace, cf, $0, now)} '`"  
  # Estimated number of keys
  data="$data $tree.$host.cassandra.keyspaces.$keyspace.$cf.EstimatedKeys `curl -s "http://$host:$port/invoke?operation=estimateKeys&objectname=org.apache.cassandra.db%3Atype%3DColumnFamilies%2Ckeyspace%3DGroupalia%2Ccolumnfamily%3D$cf"|grep -i result|cut -d":" -f2|cut -d"<" -f1` $now \n"
  
#  echo $data
  echo -e $data | nc -w 5 $carbon_server 2003
done


echo "que acabo" >> /tmp/cf_tmpfile
