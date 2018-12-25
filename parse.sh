#!/bin/bash

rm -Rf tmp
mkdir -p tmp

if [ "$1" == "--follow" ];then
	shift
	get_file() {
		cat "$1" ; tail -f -n0 "$1"
	}
else
	get_file() {
		cat "$1"
	}
fi

get_file "$1" |while read i;do
	now=$(cat tmp/now)
	if echo "$i"|grep -qE '^[0-9]+$';then
		last=$(cat tmp/last)

		if [ -n "$last" ];then
			for train in $(cat tmp/$last/approche 2>/dev/null);do
				if ! cat tmp/$now/approche tmp/$now/quai 2>/dev/null | grep -q "$train";then
					echo "$now: $train was approaching and now disappeared!"
				fi
				mv tmp/$last/$train tmp/$now/$train
			done

			for train in $(cat tmp/$last/quai 2>/dev/null);do
				if ! grep -q "$train" tmp/$now/quai 2> /dev/null;then
					initial="$(cat tmp/$last/$train)"
					echo "$(date -d @$now +%T) $train stayed for $((now-initial)) from $initial to $now"
				fi
				mv tmp/$last/$train tmp/$now/$train
			done

		fi

		for train in $(cat tmp/$now/approche 2>/dev/null);do
			if [ ! -f tmp/$now/$train ];then
				echo $now > tmp/$now/$train
			fi
		done

		for train in $(cat tmp/$now/quai 2>/dev/null);do
			if [ ! -f tmp/$now/$train ];then
				echo $now: Train $train a quai mais pas approche
			fi
		done

		rm -Rf "tmp/$i"
		mkdir -p tmp/$i
		mv -f tmp/now tmp/last
		echo $i > tmp/now
		continue
	fi

	mkdir -p tmp/$now/
	trainCode="$(echo "$i"|cut -d ';' -f 1)"
	if echo "$i"|grep -iqE 'approche';then
		(cat approche-keys; echo "$i" |cut -d ';' -f 2) |sort -u > tmp/approche-keys
		mv -f tmp/approche-keys approche-keys

		echo $trainCode >> tmp/$now/approche
	elif echo "$i" |grep -iqE 'quai';then
		(cat quai-keys; echo "$i" |cut -d ';' -f 2) |sort -u > tmp/quai-keys
		mv -f tmp/quai-keys quai-keys

		echo $trainCode >> tmp/$now/quai
	else
	# Pas à l'approche, ni à quai
		true
	fi
done

#rm -Rf tmp
