#!/bin/bash

SCRIPT_DIR=$(cd $(dirname $0); pwd)
FILENAME="info.txt"
OUTPUT=$SCRIPT_DIR/$FILENAME

UNAME=commands/uname_-a.txt
VIMDUMP=commands/vmware-vimdump_-o----U-dcui.txt
PPHOSTLIST=commands/prettyPrint.sh_hostlist.txt
DF=commands/df.txt
ESXCFG_VMKNIC=commands/esxcfg-vmknic_-l.txt
ESXCFG_SCSI=commands/esxcfg-scsidevs_-m.txt
VMX=vmfs/volumes/*/*/*.vmx
VMWARE_LOG=vmfs/volumes/*/*/vmware*
HOSTD=var/run/log/hostd.*
VPXA=var/run/log/vpxa.*
NET_DVS=commands/net-dvs_-l.txt
STORAGE_CORE_DEVICE=commands/localcli_storage-core-device-list.txt
PARTED_UTIL=commands/partedUtil.sh.txt
NET_STAT=commands/net-stats_-l.txt
ESXCFG_MPATH=commands/esxcfg-mpath_-b.txt
VM_INV=etc/vmware/hostd/vmInventory.xml
SMBIOS_DUMP=commands/smbiosDump.txt
LIST_VMX=()
LIST_VM=()

# $1 line number begin
# $2 line number end
function extract_lines () {
    if [ -z "$2" ]; then
        awk "NR>=$1 {print}"
    else
        awk "NR==$1,NR==$2 {print}"
    fi
}

# $1 grep pattern
function get_line_number () {
    grep -n -m 1 -E "$1" | cut -d : -f 1
}

# grep after the specific line
# 
# $1 line num to start searching
# $2 grep pattern
# $3 file
# $4 mode
function grep_after () {
    case "$4" in
      "n") # return line number
        num=$(cat $3 | extract_lines $1 | get_line_number "$2") 
        if [ -z "$num" ]; then
            break
        else
            echo $(( $1 + $num - 1 ))
        fi
        ;;
      *) # return matched string
        cat $3 | extract_lines $1 | grep -m 1 "$2" 
        ;;
    esac
}

# grep after the specific line but input is reversed
# 
# $1 line num to start searching
# $2 grep pattern
# $3 file
# $4 mode
function perg_after () {
    case "$4" in
      "n") # return line number
        num=$(tac $3 | extract_lines $1 | get_line_number "$2") 
        if [ -z "$num" ]; then
            break
        else
            echo $(( $1 + $num - 1 ))
        fi
        ;;
      *) # return matched string
        tac $3 | extract_lines $1 | grep -m 1 "$2" 
        ;;
    esac
}

## test code
#s=$(cat $VIMDUMP | get_line_number "config = (vim.vm.Summary.ConfigSummary)")
#echo $s
#e=$(cat $VIMDUMP | extract_lines $s | get_line_number "},")
#echo $(( $s+$e-1 ))
#end=$(grep_after 3 "dynamic" $VIMDUMP "n")
#end=$(tac $VIMDUMP | grep_after 3 "dynamic" )
#$echo "end is $end"
#exit

if test -f $OUTPUT; then
    echo "File $FILENAME already exists"
    exit
fi


# Fill LIST_VMX
OLDIFS=$IFS
IFS=$'\n'
LIST_VMX=( $(find $SCRIPT_DIR/vmfs -name *.vmx | sed 's/.*\(vmfs.*\)/\1/') )
IFS=$OLDIFS

# Fill LIST_VM
for i in "${LIST_VMX[@]}"
do
    LIST_VM+=( $( echo $i | sed 's/.*\/\(.*\)\.vmx/\1/' ) )
done


echo "- ESXi Hosts Information" > $OUTPUT
printf "\n\n" >> $OUTPUT


echo "- Output of 'uname -a'. From: $UNAME" >> $OUTPUT
cat $UNAME >> $OUTPUT
printf "\n\n" >> $OUTPUT


echo "- Fullname of this host. From: $VIMDUMP" >> $OUTPUT
grep -m 1 -e "fullName = 'VMware.*'" $VIMDUMP | sed -r 's/  +/  /' >> $OUTPUT
printf "\n\n" >> $OUTPUT


echo "- List of the Section line of hostd logs. From: $HOSTD" >> $OUTPUT
for i in $HOSTD
do
    #zgrep -Hn -m 1 "Section" $i | sed 's/^/  /' >> $OUTPUT
    zgrep -Hn "Section" $i | sed 's/^/  /' >> $OUTPUT
done
printf "\n\n" >> $OUTPUT


echo "- List of the Section line of vpxa logs. From: $VPXA" >> $OUTPUT
for i in $VPXA
do
    #zgrep -Hn -m 1 "Section" $i | sed 's/^/  /' >> $OUTPUT
    zgrep -Hn "Section" $i | sed 's/^/  /' >> $OUTPUT
done
printf "\n\n" >> $OUTPUT


echo "- List of vmk nic of this host. From: $ESXCFG_VMKNIC" >> $OUTPUT
cat $ESXCFG_VMKNIC | sed 's/^/  /' >> $OUTPUT
printf "\n\n" >> $OUTPUT


echo "- vSwitch, vmk, and vmnic info. From: $NET_STAT" >> $OUTPUT
cat $NET_STAT | sed 's/^/  /' >> $OUTPUT
printf "\n\n" >> $OUTPUT

echo "- List of paths. From: $ESXCFG_MPATH" >> $OUTPUT
cat $ESXCFG_MPATH | sed 's/^/  /' >> $OUTPUT
printf "\n\n" >> $OUTPUT

echo "- List of all ESXi hosts. From: $PPHOSTLIST" >> $OUTPUT
echo " <hostId> <hostName> <ipAddress> <version> <build>" >> $OUTPUT
tail -n +$(grep -n -m1 "<host>" $PPHOSTLIST | sed 's/:.*$//') $PPHOSTLIST \
    | grep -E '<hostId|<hostName|<ipAddress|<version|<build' \
    | sed -rz 's/\n//g' \
    | sed -r 's/ +//g' \
    | sed -r 's/<\/build>/<\/build>\n/g' \
    | sed -r 's/<[^<>]*>/ /g' \
    >> $OUTPUT
printf "\n\n" >> $OUTPUT


echo "- List of virtual machines. From: $VIMDUMP" >> $OUTPUT
#ip_addr="ipAddress"
name="name"
guest_id="guestId"
guest_full_name="guestFullName"
annotation="annotation"
keys=($name $guest_id $guest_full_name $annotation)
end=1
while true; # get VM info
do
    begin=$(grep_after $end "config = (vim.vm.Summary.ConfigSummary)" $VIMDUMP "n")
    #begin=$(cat $VIMDUMP | grep_after2 $end "config = (vim.vm.Summary.ConfigSummary)" "n")
    #echo "begin $begin"
    if [ -z "$begin" ] # if the string was not found
    then
        break
    fi

    end=$(grep_after $begin "}," $VIMDUMP "n")
    #end=$(cat $VIMDUMP | grep_after2 $begin "}," "n")
    #echo "end $end"

    for i in "${keys[@]}"
    do
        value=$(cat $VIMDUMP | extract_lines $begin $end | grep -E $i | sed -e "s/.*\($i.*\)/\1/")
        echo "  $value" >> $OUTPUT
    done
    printf "\n" >> $OUTPUT

done
printf "\n\n" >> $OUTPUT


echo "- List of DVS. From: $NET_DVS" >> $OUTPUT
grep -E '^switch|port [0-9]*:|\.alias|host\.portset|port\.vlan' $NET_DVS >> $OUTPUT
printf "\n\n" >> $OUTPUT
## test code
#echo "- List of DVS. From: $NET_DVS" >> $OUTPUT
#OLDIFS=$IFS
#IFS=$'\n'
#list_switch=( $(grep -n '^switch' $NET_DVS) )
##list_line_number=()
##list_string=()
#for i in "${list_switch[@]}"
#do
#    list_line_number+=( $(echo $i | cut -d : -f 1) )
#    list_string+=( $(echo $i | cut -d : -f 2) )
#done
#IFS=$OLDIFS
#
#len=${#list_string[@]}
#list_line_number+=( $(wc -l $NET_DVS | cut -d ' ' -f 1) ) #add last line number
##for i in "${list_line_number[@]}"
##do
##    echo $i
##done
##exit
#for i in $(seq 0 $(( $len-1 )))
#do
#    j=$(( $i + 1 ))
#    string=${list_string[$i]}
#    begin=${list_line_number[$i]}
#    end=${list_line_number[$j]}
#    echo $string >> $OUTPUT
#    sed ' '"$begin"','"$end"'!d ' $NET_DVS | grep "com\.vmware\.common\.alias" >> $OUTPUT
#    sed ' '"$begin"','"$end"'!d ' $NET_DVS | grep "com\.vmware\.common\.host\.portset" >> $OUTPUT
#    sed ' '"$begin"','"$end"'!d ' $NET_DVS | grep "port .*:" >> $OUTPUT
#    printf "\n" >> $OUTPUT
#done
#printf "\n\n" >> $OUTPUT


echo "- List of all vmx files and vm ID. From: $VMX and $VM_INV" >> $OUTPUT
#du $VMX | sed -r 's/[0-9]+//' >> $OUTPUT
for i in "${LIST_VMX[@]}"
do
    begin=$(perg_after 1 "$i" $VM_INV "n")
    objID=$(perg_after $begin "objID" $VM_INV)
    echo "    $i  $objID" >> $OUTPUT
done
printf "\n\n" >> $OUTPUT


echo "- List of disks. From: $DF" >> $OUTPUT
cat $DF | sed 's/^/  /' >> $OUTPUT
printf "\n\n" >> $OUTPUT


echo "- List of scsi devices. From: $ESXCFG_SCSI" >> $OUTPUT
cat $ESXCFG_SCSI | sed 's/^/  /' >> $OUTPUT
printf "\n\n" >> $OUTPUT


echo "- List of connected storage devices. From: $PARTED_UTIL" >> $OUTPUT
grep -E "Device:" $PARTED_UTIL | sed -e "s/\(Device:.*\)/  \1/"  >> $OUTPUT
printf "\n\n" >> $OUTPUT


echo "- Hardware specifications. From: $SMBIOS_DUMP" >> $OUTPUT
# -------------------------------- get cpu info
version="Version"
keys=($version)
end=1
while true; # get VM info
do
    begin=$(grep_after $end "Processor Info" $SMBIOS_DUMP "n")
    if [ -z "$begin" ] # if the string was not found
    then
        break
    fi

    end=$(grep_after $(($begin+1)) "^  [^ ]+" $SMBIOS_DUMP "n")

    for i in "${keys[@]}"
    do
        string=$(grep_after $begin "Processor Info" $SMBIOS_DUMP)
        echo "  $string" >> $OUTPUT
        string=$(cat $SMBIOS_DUMP| extract_lines $begin $end | grep -E $i)
        echo "  $string" >> $OUTPUT
    done
    #printf "\n" >> $OUTPUT

done
#printf "\n\n" >> $OUTPUT
# -------------------------------- get memory info
manufacturer="Manufacturer"
part_number="Part"
size="Size"
keys=($manufacturer $part_number $size)
end=1
while true; # get VM info
do
    begin=$(grep_after $end "Memory Device" $SMBIOS_DUMP "n")
    if [ -z "$begin" ] # if the string was not found
    then
        break
    fi

    end=$(grep_after $(($begin+1)) "^  [^ ]+" $SMBIOS_DUMP "n")

    string=$(grep_after $begin "Memory Device" $SMBIOS_DUMP)
    echo "  $string" >> $OUTPUT
    for i in "${keys[@]}"
    do
        string=$(cat $SMBIOS_DUMP| extract_lines $begin $end | grep -E $i)
        if [ -z "$string" ] # if the string was not found
        then
            continue
        fi
        echo "  $string" >> $OUTPUT
    done
    #printf "\n" >> $OUTPUT

done
printf "\n\n" >> $OUTPUT


echo "- List of DVS. From: $NET_DVS" >> $OUTPUT
grep -E '^switch|port [0-9]*:|\.alias|host\.portset|port\.vlan' $NET_DVS >> $OUTPUT
printf "\n\n" >> $OUTPUT


#echo "- List of storage devices. From: $STORAGE_CORE_DEVICE" >> $OUTPUT
#grep -E "^[^ ].*|  Display|Other" $STORAGE_CORE_DEVICE >> $OUTPUT
#printf "\n\n" >> $OUTPUT


# List "State Transition"
#OLDIFS=$IFS
#IFS=$'\n'
#state_transition=( $(zgrep "State Transition" $HOSTD) )
#for i in "${LIST_VMX[@]}"
#do
#    echo $i
#    echo "==> $i" >> $OUTPUT
#    for j in "${state_transition[@]}"
#    do
#        echo $j | grep "$i" >> $OUTPUT
#    done
#done
#IFS=$OLDIFS
#printf "\n\n" >> $OUTPUT


#echo "- Search error message I've ever seen before." >> $OUTPUT
#messages_hostd=(
#    "IpmiIfcSdrReadRecordId: retry expired"
#    "Another process has kept this file locked for more than "
#    "Invalid transition requested (VM_STATE_ON_SHUTTING_DOWN -> VM_STATE_CREATE_SNAPSHOT)"
#    "There is not enough space on the file system for the selected operation"
#    "vim.fault.GenericVmConfigFault"
#    "was not in passthrough mode"
#    "Throw vim.fault.FileNotFound"
#)
#for i in "${messages_hostd[@]}"
#do
#    echo "==> '$i' in $HOSTD" >> $OUTPUT
#    zgrep "$i" $HOSTD >> $OUTPUT
#    printf "\n" >> $OUTPUT
#done
#
#messages_vmware_log=(
#    "'VssSyncStart' operation failed"
#    "PANIC: VERIFY bora/vmcore/vmx/main/monitorAction.c:598 bugNr=10871"
#    "is incompatible with this virtual machine configuration"
#    "is corrupted. If the problem persists, discard the redo log"
#)
#for i in "${messages_vmware_log[@]}"
#do
#    echo "==> '$i' in $VMWARE_LOG" >> $OUTPUT
#    zgrep "$i" $VMWARE_LOG >> $OUTPUT
#    printf "\n" >> $OUTPUT
#done


echo "$OUTPUT   generated."
