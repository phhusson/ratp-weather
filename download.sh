#!/bin/bash

ep=http://opendata-tr.ratp.fr/wsiv/services/Wsiv
xmlsel() {
	xmlstarlet sel -N w=http://wsiv.ratp.fr -N x=http://wsiv.ratp.fr/xsd "$@"
}

xmled() {
	xmlstarlet ed -N w=http://wsiv.ratp.fr -N x=http://wsiv.ratp.fr/xsd "$@"
}


for rer in A B;do
	xmled -u '//ws:station/x:line/x:id' -v R${rer} getStations.xml > tmp.xml
	curl -s $ep -d @tmp.xml -H 'Content-Type: application/soap+xml; charset=utf-8'|xmlstarlet fo > stations-RER${rer}.xml

	cat watchlist-RER${rer} |while read station;do
		mkdir -p "logs/RER${rer}/${station}"
		id="$(xmlsel -t -m '//x:stations[x:name/text()="'"$station"'"]' -v ./x:id -n stations-RER${rer}.xml)"
		echo $id > "logs/RER${rer}/${station}"/.id
		xmled -u '//w:station/x:id' -v $id getMissionsNext.xml | \
			xmled -u '//w:station/x:line/x:id' -v R${rer} > "logs/RER${rer}/${station}"/.xml
	done
done

for rer in A B;do
	day="$(date +%F)"
	cat watchlist-RER${rer} |while read station;do
		(
		echo "RER ${rer}; $station"
		p="logs/RER${rer}/${station}"
		l="$p/$day"
		t="$(mktemp)"

		while true;do
			date +%s >> "$l"
			curl -s $ep -d "@${p}/.xml" -H 'Content-Type: application/soap+xml; charset=utf-8' | \
				xmlsel -t -m //x:missions -v ./x:id -o \; -v ./x:stationsMessages -o \; -v ./x:stationsDates -o \; -v './x:stations[2]/x:name' -n > $t
			cat "$t" >> "$l"

			now="$(date +%H:%M)"
			next="$(date -d '1 minute' +%H:%M)"
			next2="$(date -d '2 minute' +%H:%M)"

			if grep -qiE -e quai -e approche -e $now -e $next -e $next2 $t;then
				sleep 5
			else
				sleep 60
			fi
		done
		) &
	done
done

while true; do sleep 3600;done
