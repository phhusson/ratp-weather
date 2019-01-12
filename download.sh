#!/bin/bash

ep=http://opendata-tr.ratp.fr/wsiv/services/Wsiv
xmlsel() {
	xmlstarlet sel -N w=http://wsiv.ratp.fr -N x=http://wsiv.ratp.fr/xsd "$@"
}

xmled() {
	xmlstarlet ed -N w=http://wsiv.ratp.fr -N x=http://wsiv.ratp.fr/xsd "$@"
}


declare -A lines
#lines=( ["RERA"]=RA ["RERB"]=RB ["T3a"]=198721 )
lines=( ["RERA"]=RA ["RERB"]=RB)
for line in "${!lines[@]}";do
	echo Generating for line $line
	xmled -u '//ws:station/x:line/x:id' -v "${lines[$line]}" getStations.xml > tmp.xml
	curl -s $ep -d @tmp.xml -H 'Content-Type: application/soap+xml; charset=utf-8'|xmlstarlet fo > "stations-${line}.xml"

	cat watchlist-$line |while read station;do
		mkdir -p "logs/$line/${station}"
		id="$(xmlsel -t -m '//x:stations[x:name/text()="'"$station"'"]' -v ./x:id -n stations-${line}.xml)"
		echo $id > "logs/$line/${station}"/.id
		xmled -u '//w:station/x:id' -v $id getMissionsNext.xml | \
			xmled -u '//w:station/x:line/x:id' -v "${lines[$line]}" > "logs/$line/${station}"/.xml
	done
done

for line in "${!lines[@]}";do
	cat watchlist-${line} |while read station;do
		(
		echo "${line}; $station"
		p="logs/${line}/${station}"
		t="$(mktemp)"

		while true;do
			day="$(date -d '2 hours ago' +%F)"
			l="$p/$day"

			date +%s >> "$l"
			curl -s $ep -d "@${p}/.xml" -H 'Content-Type: application/soap+xml; charset=utf-8' | \
				xmlsel -t -m //x:missions -v ./x:id -o \; -v ./x:stationsMessages -o \; -v ./x:stationsDates -o \; -v './x:stations[2]/x:name' -n > $t
			cat "$t" >> "$l"

			now="$(date +%H:%M)"
			next="$(date -d '1 minute' +%H:%M)"
			next2="$(date -d '2 minute' +%H:%M)"
			next3="$(date -d '3 minute' +%H:%M)"

			if grep -qiE -e quai -e approche -e $now -e $next -e $next2 -e $next3 $t;then
				sleep $((4+(RANDOM%3)))
			else
				sleep 60
			fi
		done
		) &
	done
done

while true; do sleep 3600;done
