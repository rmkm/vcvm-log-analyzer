#!/bin/bash

SCRIPT_DIR=$(cd $(dirname $0); pwd)
FILENAME="info.txt"
OUTPUT=$SCRIPT_DIR/$FILENAME

UNAME=commands/uname_-a.txt
BUILDINFO=etc/vmware/.buildInfo #depricated
IFCONFIG=commands/ifconfig_-a.txt
DF=commands/df.txt
VPXDUPTIME=var/log/vmware/vpxd/*vpxduptime
VPXD_LOG=var/log/vmware/vpxd/vpxd-[0-9]*.log*
SERVICE_CONTROL=commands/service-control_--status---all.txt


if test -f $OUTPUT; then
    echo "File $FILENAME already exists"
    exit
fi


echo "vCenter Server Information" > $OUTPUT
printf "\n\n" >> $OUTPUT


echo "- From: $UNAME" >> $OUTPUT
cat $UNAME | sed 's/^/  /' >> $OUTPUT
printf "\n\n" >> $OUTPUT


echo "- The installed vc build information. From: $BUILDINFO" >> $OUTPUT
grep -E "BUILDNUMBER|CLOUDVM_VERSION|CLOUDVM_NAME|SUMMARY" $BUILDINFO | sed 's/^/  /' >> $OUTPUT
printf "\n\n" >> $OUTPUT


echo "- List of the Section line of vpxd logs. From: $BUILDINFO" >> $OUTPUT
for i in $VPXD_LOG
do
    zgrep -Hn -m 1 "Section" $i | sed 's/^/  /' >> $OUTPUT
done
printf "\n\n" >> $OUTPUT


echo "- From: $SERVICE_CONTROL" >> $OUTPUT
cat $SERVICE_CONTROL | sed 's/^/  /' >> $OUTPUT
printf "\n\n" >> $OUTPUT


#VPXDCONF=etc/vmware-vpx/vpxd.cfg
#echo "From: $VPXDCONF" >> $OUTPUT
#grep -e '<hostnameUrl>.*</hostnameUrl>' $VPXDCONF >> $OUTPUT
#printf "\n" >> $OUTPUT

echo "- From: $IFCONFIG" >> $OUTPUT
cat $IFCONFIG | sed 's/^/  /' >> $OUTPUT
printf "\n\n" >> $OUTPUT


echo "- From: $DF" >> $OUTPUT
cat $DF | sed 's/^/  /' >> $OUTPUT
printf "\n\n" >> $OUTPUT


echo "- vpxd uptime and build number info. From: $VPXDUPTIME" >> $OUTPUT
for i in $VPXDUPTIME
do
    num_delimiters=$(awk -F "|" '{print NF-1}' $i)
    if [ $num_delimiters -lt 6 ]; then
        continue
    fi
    begin=$(( $(cat $i | cut -d \| -f 1)/1000000 ))
    end=$(( $(cat $i | cut -d \| -f 6)/1000000 ))
    build=$(cat $i | cut -d \| -f 4)
    echo "  $build" >> $OUTPUT
    echo "  $(date -d @$begin)" >> $OUTPUT
    echo "  $(date -d @$end)" >> $OUTPUT
    printf "\n" >> $OUTPUT
done
printf "\n" >> $OUTPUT


echo "- Search error message I've ever seen before." >> $OUTPUT
error_list=(
    "SSL Exception"
    "connection state changed to NO_RESPONSE"
    "Insufficient free space for the Database"
)
for i in "${error_list[@]}"
do  
    echo "==> '$i'" >> $OUTPUT
    zgrep "$i" var/log/vmware/vpxd/vpxd* >> $OUTPUT
    printf "\n" >> $OUTPUT
done


echo "$OUTPUT   generated."
