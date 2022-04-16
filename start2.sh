#!/bin/sh
PoolHost=na.luckpool.net
Port=3956#xnsub
PublicVerusCoinAddress=RKRiP59bf77v8o8HxhnRofgqZH88DyppeT
WorkerName=Rock2
Threads=4

#-c stratum+tcp://na.luckpool.net:3956#xnsub -u RKRiP59bf77v8o8HxhnRofgqZH88DyppeT.Rig002 -p x --cpu 1

#exit existing screens with the name CCminer
screen -S CCminer -X quit
#create new disconnected session CCminer
screen -dmS CCminer
#run the miner
screen -S CCminer -X stuff "nice -n 19 ./ccminer -a verus -o stratum+tcp://${PoolHost}:${Port} -u ${PublicVerusCoinAddress}.${WorkerName} -t ${Threads} $@\n"