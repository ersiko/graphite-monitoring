#!/bin/bash

#Carbon server where data should be stored for graphite to show - El servidor carbon on s'han de guardar les dades que mostra el graphite
carbon_server=graphite.domain.tld

# Tree structure where we want information to be stored - L'estructura de l'arbre on volem que es guardin les dades a graphite. 
tree="servers" #In this case, info will be shown in graphite as "servers.servername.loadavg_1min". We could use "pro" and "pre" to separate environments: "servers.pro.servername.loadavg_1min" - En el nostre cas es veuran a "servers.servername.loadavg_1min". Podriem posar "prod" i "pre" per separar entorns: "servers.pro.servername.loadavg_1min"

now=`date +%s`
host=`hostname`

#Load average - Carrega
read un cinc quinze resta < /proc/loadavg
data="$tree.$host.loadavg_1min $un $now \n $tree.$host.loadavg_5min $cinc $now \n $tree.$host.loadavg_15min $quinze $now \n"

#Memory - Memoria
data="$data `free -o|awk -v host=$host -v now=$now '(NR==2) {printf("servers.%s.memory %s %s \\\n ", host, $3/$2*100, now)} (NR==3) {printf("servers.%s.swap %s %s\\\n ", host, $3/$2*100, now)}'`"

#CPU Used - Recollim CPU
data="$data `sar -u 3|awk -v host=$host -v now=$now 'END {printf("servers.%s.cpu %s %s \\\n ", host, 100-$8, now)}'`"

#Disk data - Recollim dades de disc
data="$data `sar -b 3|awk -v host=$host -v now=$now 'END {printf("servers.%s.disk.totalops %s %s  \\\n servers.%s.disk.readops %s %s  \\\n servers.%s.disk.writeops %s %s  \\\n servers.%s.disk.breads %s %s  \\\n servers.%s.disk.bwrites %s %s  \\\n ", host, $2, now, host, $3, now, host, $4, now, host, $5, now, host, $6, now)}'`"

#Show data for debugging purpose - Mostrem les dades per depurar errors
echo $data
#Send data to graphite - Enviem dades a graphite
echo -e $data |nc -w 5 $carbon_server 2003 2>&2
exit $?
