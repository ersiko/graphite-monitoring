#!/bin/bash

# WARNING - ATENCIO
# This script requires mx4j to be installed on cassandra monitored nodes. For more instructions visit:
# Aquest script necessita que el mx4j estigui instal·lat als nodes monitoritzats. Per mes instruccions visita: 
# http://wiki.apache.org/cassandra/Operations#Monitoring_with_MX4J

#Carbon server where data should be stored for graphite to show - El servidor carbon on s'han de guardar les dades que mostra el graphite
carbon_server=graphite.domain.tld
# Tree structure where we want information to be stored - L'estructura de l'arbre on volem que es guardin les dades a graphite. 
tree=servers

now=`date +%s`
host=${1:-localhost}

#Number of connections - Numero de connexions
if [ $host == "localhost" ];then 
  connections=`netstat -tn|grep ESTABLISHED|awk '{print $4}'|grep 9160|wc -l`
  host=`hostname`
else 
  connections=`ssh $host netstat -tn|grep ESTABLISHED|awk '{print $4}'|grep 9160|wc -l`
fi
data="$tree.$host.cassandra.connections $connections $now\n" 

#Tasks in ReadStage - Tasques en ReadStage
data="$data `curl http://$host:8081/mbean?objectname=org.apache.cassandra.request%3Atype%3DReadStage -s |egrep "CompletedTasks|PendingTasks|ActiveCount"|cut -d">" -f8|cut -d"<" -f1|awk -v tree=$tree -v now=$now -v host=$host '(NR == 1) {printf("%s.%s.cassandra.ReadStage.ActiveCount %s %s\\\n",tree, host, $0, now)} (NR == 2) {printf("%s.%s.cassandra.ReadStage.CompletedTasks %s %s\\\n",tree, host, $0, now)} (NR ==3) {printf("%s.%s.cassandra.ReadStage.PendingTasks %s %s\\\n",tree, host, $0, now)}'`"

#Tasks in MutationStage - Tasques en MutationStage (writes)
data="$data `curl http://$host:8081/mbean?objectname=org.apache.cassandra.request%3Atype%3DMutationStage -s |egrep "CompletedTasks|PendingTasks|ActiveCount"|cut -d">" -f8|cut -d"<" -f1|awk -v tree=$tree -v now=$now -v host=$host '(NR == 1) {printf("%s.%s.cassandra.MutationStage.ActiveCount %s %s\\\n",tree,host, $0, now)} (NR == 2) {printf("%s.%s.cassandra.MutationStage.CompletedTasks %s %s\\\n",tree,host, $0, now)} (NR ==3) {printf("%s.%s.cassandra.MutationStage.PendingTasks %s %s\\\n",tree, host, $0, now)}'`"

#Tasks in GossipStage - Tasques en GossipStage (comunicacio interna entre cassandras)
data="$data `curl http://$host:8081/mbean?objectname=org.apache.cassandra.internal%3Atype%3DGossipStage -s |egrep "CompletedTasks|PendingTasks|ActiveCount"|cut -d">" -f8|cut -d"<" -f1|awk -v tree=$tree -v now=$now -v host=$host '(NR == 1) {printf("%s.%s.cassandra.GossipStage.ActiveCount %s %s\\\n",tree, host, $0, now)} (NR == 2) {printf("%s.%s.cassandra.GossipStage.CompletedTasks %s %s\\\n",tree, host, $0, now)} (NR ==3) {printf("%s.%s.cassandra.GossipStage.PendingTasks %s %s\\\n",tree, host, $0, now)}'`"

#Compaction tasks - Tasques de compactacio
data="$data `curl http://$host:8081/mbean?objectname=org.apache.cassandra.db%3Atype%3DCompactionManager -s|egrep "CompletedTasks|PendingTasks"|cut -d">" -f8|cut -d"<" -f1|awk -v tree=$tree -v now=$now -v host=$host '(NR == 1) {printf("%s.%s.cassandra.Compaction.CompletedTasks %s %s\\\n",tree, host, $0, now)} (NR == 2) {printf("%s.%s.cassandra.Compaction.PendingTasks %s %s\\\n",tree, host, $0, now)}'`"

#Operation Latency - Latencia d'operacions
data="$data `curl http://$host:8081/mbean?objectname=org.apache.cassandra.db%3Atype%3DStorageProxy -s |egrep "RecentRangeLatencyMicros|RecentReadLatencyMicros|RecentWriteLatencyMicros"|cut -d">" -f8|cut -d"<" -f1|awk -v tree=$tree -v now=$now -v host=$host '(NR == 1) {printf("%s.%s.cassandra.Latency.Range %s %s\\\n",tree, host, $0, now)} (NR == 2) {printf("%s.%s.cassandra.Latency.Read %s %s\\\n",tree,host, $0, now)} (NR ==3) {printf("%s.%s.cassandra.Latency.Write %s %s\\\n",tree,host, $0, now)}'`"

#Heap and non-heap memory - Us de Memoria Heap i NoHeap
data="$data `curl http://$host:8081/mbean?objectname=java.lang%3Atype%3DMemory -s|grep HeapMemoryUsage|awk -F"max=" '{print $2}'|cut -d"}" -f1|sed -e 's/, used=/\n/g'|awk -v tree=$tree -v now=$now -v host=$host '(NR == 1) {printf("%s.%s.cassandra.internals.MaxJavaHeap %s %s\\\n",tree, host, $0, now)} (NR == 2) {printf("%s.%s.cassandra.internals.JavaHeapUsed %s %s\\\n",tree, host, $0, now)} (NR ==3) {printf("%s.%s.cassandra.internals.MaxJavaNoHeap %s %s\\\n",tree, host, $0, now)} (NR == 4) {printf("%s.%s.cassandra.internals.JavaNoHeapUsed %s %s\\\n",tree, host, $0, now)}'`"

#Number of GarbageCollections - Numero de GarbageCollections
data="$data `curl http://$host:8081/mbean?objectname=java.lang%3Atype%3DGarbageCollector%2Cname%3DConcurrentMarkSweep -s| grep CollectionCount|cut -d">" -f8|cut -d"<" -f1|awk -v tree=$tree -v now=$now -v host=$host '{printf("%s.%s.cassandra.internals.GarbageCollections %s %s\\\n",tree, host, $0, now)}'`"

#echo $data
echo -e $data|nc -w 5 $carbon_server 2003
exit $?
