#!/usr/bin/python3

import argparse
import datetime
import re
import time

parser = argparse.ArgumentParser(description = 'Parse RATP logs files')
parser.add_argument('--follow', action='store_true')
parser.add_argument('file', action='store')
args = parser.parse_args()

def tail_f(f):
    interval = 1.0

    while True:
        where = f.tell()
        line = f.readline()
        if not line:
            if args.follow:
                time.sleep(interval)
                f.seek(where)
            else:
                break
        else:
            yield line

nowTs=-1
f=open(args.file, 'r')
fstats = open(args.file + '.stats', 'w')
tsMatch = re.compile('^[0-9]+$')
approcheMatch = re.compile('.*approche.*', re.IGNORECASE)
quaiMatch = re.compile('.*quai.*', re.IGNORECASE)
infosExtract = re.compile('([^;]*);([^;]*);([^;]*)')

lastApproche = []
lastQuai = []
approche = []
quai = []
status = {}
screenLine = 0
for line in tail_f(f):
    if tsMatch.match(line):
        screenLine = 0
        sortedApprocheQuai = sorted((approche + quai), key = lambda r : r[3])

        previousLine = -1
        for info in sortedApprocheQuai:
            train = info[0]
            if info[3] > (previousLine+2):
                print("Ghost train {} at {} ({} vs {})".format(train, nowTs, info[3], previousLine+2))
                continue
            previousLine = info[3]
            if not status.__contains__(train):
                status[train] = (train, nowTs, True)

        toDelete = []
        for train in status:
            wasApproche = sum(1 for i in lastApproche if i[0] == train) >= 1
            wasQuai = sum(1 for i in lastQuai if i[0] == train) >= 1
            isQuai = sum(1 for i in quai if i[0] == train) >= 1
            isApproche = sum(1 for i in approche if i[0] == train) >= 1
            if isQuai:
                if not wasApproche and not wasQuai:
                    status[train] = (train, nowTs, False)
                    print("Train {} is at quai, but wasn't approaching".format(train))
                    print(quai)
                    print(approche)
                continue
            if isApproche:
                continue
            
            #This train is no longer displayed
            if not wasQuai:
                toDelete.append(train)
                print("Train {} was approaching, but disappeared".format(train))
                continue

            delta = nowTs - status[train][1]
            result = status[train][2]
            d = datetime.datetime.fromtimestamp(status[train][1])
            d2 = datetime.datetime.fromtimestamp(nowTs)
            print("{}-{} Train {} stayed for {}".format(d.strftime('%T'), d2.strftime('%T'), train, delta))
            if result:
                print('{} {} {}'.format(train, delta, nowTs), file = fstats)
                fstats.flush()
            toDelete.append(train)

        for train in toDelete:
            status.__delitem__(train)

        nowTs = int(line)
        lastApproche = approche
        lastQuai = quai
        approche = []
        quai = []
        continue
    
    res = infosExtract.match(line)
    train = res.group(1)
    text = res.group(2)
    destination = res.group(3)
    t = (train, text, destination, screenLine)
    screenLine += 1

    if approcheMatch.match(text):
        approche.append(t)

    if quaiMatch.match(text):
        quai.append(t)
