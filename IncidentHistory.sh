#!/bin/bash

if [[ "$1" =~ ^[0-9]*[0-9]$ ]]; then
	echo "対応履歴が$1件以上のインシデントを抽出します。"
else
        echo "使い方: $0 閾値"
	exit 1
fi


IncidentID=(`/usr/local/pgsql/bin/psql -Uswing swing -c "SELECT DISTINCT incident_id from incident_tbl where status <> 'COMPLETED' ORDER BY incident_id ;" -A -t`)
Number=(`/usr/local/pgsql/bin/psql -Uswing swing -c "SELECT DISTINCT count(incident_id) from incident_tbl ;" -A -t`)

Num=`expr $Number - 1`

for i in `seq 0 1 $Num`
do

Count=`/usr/local/pgsql/bin/psql -Uswing swing -c "SELECT count(*) from incident_history_tbl where incident_id = '${IncidentID[$i]}';" -A -t`

if test `expr $Count` -ge $1
then

	echo ${IncidentID[$i]} : $Count

fi

done


