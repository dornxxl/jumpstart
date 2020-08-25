#!/bin/bash
##################################################
# CIDR Cleansing                                 #
##################################################
ret_code=1

if [ $# -ne 1 ]; then
    echo "Usage : $0 CIDR"
else
    cidr=$1
    OIFS=$IFS
    IFS='/'
    cidr=($cidr)
    if [[ ${#cidr[@]} -eq 2 ]]; then
        network=${cidr[0]}
        bitmask=${cidr[1]}
        if [[ $network =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ && $bitmask =~ ^[0-9]{1,2}$ ]]; then
            IFS='.'
            network=($network)
            if [[ ${network[0]} -le 255 && ${network[1]} -le 255 && ${network[2]} -le 255 && ${network[3]} -le 255 && $bitmask -le 32 ]]; then
                bin_nm=$(( 0xffffffff ^ ((1 << (32 - $bitmask)) - 1) ))
                netmask=$(( (bin_nm >> 24) & 0xff )).$(( (bin_nm >> 16) & 0xff )).$(( (bin_nm >> 8) & 0xff )).$(( bin_nm & 0xff ))
                netmask=($netmask)
                printf "%d.%d.%d.%d/%d"  "$((network[0] & netmask[0]))" "$((network[1] & netmask[1]))" "$((network[2] & netmask[2]))" "$((network[3] & netmask[3]))" "$((bitmask))"
                ret_code=0
            fi
        fi
    fi
    if [[ ${#cidr[@]} -eq 1 ]]; then
        ip=${cidr[0]}
        if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        IFS='.'
        ip=($ip)
            if [[ ${ip[0]} -le 255 && ${ip[1]} -le 255 && ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]; then
                if [[ ${ip[0]} -lt 224 ]]; then
                    case ${ip[0]} in
                        0|127)
                            ret_code=1
                            ;;
                        169)
                            if [[ ${ip[1]} -eq 254 ]]; then
                                ret_code=1
                            else
                                ret_code=0
                            fi
                            ;;
                        *)
                            ret_code=0
                            ;;
                    esac
                fi
            fi
        fi
        if [[ $ret_code -eq 0 ]]; then
            printf "%d.%d.%d.%d" ${ip[0]} ${ip[1]} ${ip[2]} ${ip[3]}
        fi
    fi
    IFS=$OIFS
fi

exit $ret_code
