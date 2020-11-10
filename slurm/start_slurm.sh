#!/bin/bash
# @file start_slurm.sh
# @brief Script to start slurm
# @author Andre Maximo
# @date May, 2020
# @copyright The MIT License

OUTFP=/tmp/$0.log

echo "Enabling SLURM accounting access for all users" &>> $OUTFP

touch /var/log/slurm/accounting.txt
chmod a+r /var/log/slurm/accounting.txt

echo "Filling slurm.conf and gres.conf in /usr/local/etc/" &>> $OUTFP

cp /usr/local/etc/base_gres.conf /usr/local/etc/gres.conf &>> $OUTFP

i=0 | nvidia-smi --query-gpu=gpu_name --format=csv,noheader | tr '[:upper:]' '[:lower:]' | tr ' ' '_' | while read gpu_name; do echo "Name=gpu Type=$gpu_name File=/dev/nvidia$((i++))"; done >> /usr/local/etc/gres.conf

sed "s/SlurmctldHost=/SlurmctldHost=$(head -n 1 /etc/JARVICE/nodes)/g" /usr/local/etc/base_slurm.conf > /usr/local/etc/slurm.conf

#cat /etc/JARVICE/nodes | while read node; do echo -e "NodeName=$node RealMemory=$(expr $(grep MemTotal /proc/meminfo | awk '{print $2}') / 1024) Sockets=$(lscpu | grep Socket\(s\) | awk '{print $2}') CoresPerSocket=$(lscpu | grep Core\(s\) | awk '{print $4}') ThreadsPerCore=$(lscpu | grep Thread\(s\) | awk '{print $4}') Gres=gpu:tesla_k80:no_consume:1 State=UNKNOWN\n"; done >> /usr/local/etc/slurm.conf

cat /etc/JARVICE/nodes | while read node; do echo -e "NodeName=$node RealMemory=$(expr $(grep MemTotal /proc/meminfo | awk '{print $2}') / 1024) Procs=$(nproc) Gres=gpu:$(nvidia-smi --query-gpu=gpu_name --format=csv,noheader | head -n 1 | tr '[:upper:]' '[:lower:]' | tr ' ' '_'):$(nvidia-smi --query-gpu=gpu_name --format=csv,noheader | wc -l),gpu_mem:$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits | head -n 1) State=UNKNOWN\n"; done >> /usr/local/etc/slurm.conf

echo "PartitionName=all Nodes=$(cat /etc/JARVICE/nodes | tr '\n' ',' | sed s/.$// -) Default=YES MaxTime=INFINITE State=UP" >> /usr/local/etc/slurm.conf

echo "Cleaning up SLURM log and starting SLURM ctld + d" &>> $OUTFP

rm -f /var/log/slurm/slurm*.log

nohup slurmctld -D -vvvvvv &> /dev/null &
nohup slurmd -D -vvvvvv &> /dev/null &
