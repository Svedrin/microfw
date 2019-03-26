#!/bin/bash

set -e
set -u

# ETC_DIR="/etc/microfw"
ETC_DIR="nodes"

# set sane defaults: Delete all rules and user-defined chains, then set the
# policies to ACCEPT. we will add reject rules down the line, setting the
# policy to ACCEPT means that the admin can get things to work using
# iptables -F manually.
# Then, delete all ipsets.

echo iptables -F
echo iptables -X

echo iptables -P INPUT   ACCEPT
echo iptables -P FORWARD ACCEPT
echo iptables -P OUTPUT  ACCEPT

echo iptables -A INPUT   -p icmp -j ACCEPT
echo iptables -A FORWARD -p icmp -j ACCEPT


echo ip6tables -F
echo ip6tables -X

echo ip6tables -P INPUT   ACCEPT
echo ip6tables -P FORWARD ACCEPT
echo ip6tables -P OUTPUT  ACCEPT

echo ip6tables -A INPUT   -p icmpv6 -j ACCEPT
echo ip6tables -A FORWARD -p icmpv6 -j ACCEPT


echo ipset flush
echo ipset destroy


# Parse address objects into ipsets

grep . $ETC_DIR/addresses | grep -v '^#' | while read name v4addr v6addr; do
    if [ "$v4addr" != '-' ]; then
        echo "ipset create ${name}_v4 hash:net family inet  hashsize 1024 maxelem 65536"
        echo "ipset add    ${name}_v4 $v4addr"
    fi
    if [ "$v6addr" != '-' ]; then
        echo "ipset create ${name}_v6 hash:net family inet6 hashsize 1024 maxelem 65536"
        echo "ipset add    ${name}_v6 $v6addr"
    fi
done

grep . $ETC_DIR/services | grep -v '^#' | while read name tcp udp; do
    if [ "$tcp" != '-' ]; then
        echo "ipset create ${name}_tcp bitmap:port range 1-65535"
        echo "ipset add    ${name}_tcp $tcp"
    fi
    if [ "$udp" != '-' ]; then
        echo "ipset create ${name}_udp bitmap:port range 1-65535"
        echo "ipset add    ${name}_udp $udp"
    fi
done



# define action chains

echo iptables -N accept
echo iptables -A accept -j ACCEPT

echo iptables -N drop
echo iptables -A drop -j DROP

echo iptables -N reject
echo iptables -A reject -m addrtype --src-type BROADCAST -j DROP
echo iptables -A reject -s 224.0.0.0/4 -j DROP
echo iptables -A reject -p igmp -j DROP
echo iptables -A reject -p tcp -j REJECT --reject-with tcp-reset
echo iptables -A reject -p udp -j REJECT --reject-with icmp-port-unreachable
echo iptables -A reject -p icmp -j REJECT --reject-with icmp-host-unreachable
echo iptables -A reject -j REJECT --reject-with icmp-host-prohibited

echo ip6tables -N accept
echo ip6tables -A accept -j ACCEPT

echo ip6tables -N drop
echo ip6tables -A drop -j DROP

echo ip6tables -N reject
echo ip6tables -A reject -p tcp -j REJECT --reject-with tcp-reset
echo ip6tables -A reject -j REJECT --reject-with icmp6-adm-prohibited



# declare <zone>_in chain per zone, and have all traffic arriving on an
# interface routed there
ZONES=$(
    # Get the second column of the interfaces table, but unique values only
    grep . ${ETC_DIR}/$1/interfaces | grep -v '^#' | while read iface zone; do
        echo $zone
    done | sort | uniq
)

for zone in $ZONES; do
    echo "iptables  -N ${zone}_inp"
    echo "ip6tables -N ${zone}_inp"
    echo "iptables  -N ${zone}_fwd"
    echo "ip6tables -N ${zone}_fwd"
done


# Always accept traffic for already-established connections
echo "iptables  -A INPUT   -m state --state RELATED,ESTABLISHED -j ACCEPT"
echo "ip6tables -A INPUT   -m state --state RELATED,ESTABLISHED -j ACCEPT"
echo "iptables  -A FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT"
echo "ip6tables -A FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT"


# Route incoming traffic to zone-specific input and forward chains
grep . ${ETC_DIR}/$1/interfaces | grep -v '^#' | while read iface zone; do
    echo "iptables  -A INPUT   -i $iface -j ${zone}_inp"
    echo "ip6tables -A INPUT   -i $iface -j ${zone}_inp"

    # We will never allow hairpin traffic though (traffic cannot be
    # forwarded out the same interface where it came in)
    echo "iptables  -A FORWARD -i $iface -o $iface -j drop"
    echo "ip6tables -A FORWARD -i $iface -o $iface -j drop"

    echo "iptables  -A FORWARD -i $iface -j ${zone}_fwd"
    echo "ip6tables -A FORWARD -i $iface -j ${zone}_fwd"
done


function gen_iptables_commands() {
    chain="$1"
    filter="$2"
    srcaddr="$3"
    dstaddr="$4"
    service="$5"
    action="$6"

    ADDR_FILTER=""
    if [ "$srcaddr" != "ALL" ]; then ADDR_FILTER="${ADDR_FILTER} -m set --match-set ${srcaddr}_v4 src"; fi
    if [ "$dstaddr" != "ALL" ]; then ADDR_FILTER="${ADDR_FILTER} -m set --match-set ${dstaddr}_v4 dst"; fi

    if [ "$service" != "ALL" ]; then
        SERVICE_FILTER="-p tcp -m set --match-set ${service}_tcp src"
        echo "iptables  -A ${chain} $filter $ADDR_FILTER $SERVICE_FILTER -j $action"

        SERVICE_FILTER="-p udp -m set --match-set ${service}_udp src"
        echo "iptables  -A ${chain} $filter $ADDR_FILTER $SERVICE_FILTER -j $action"
    else
        echo "iptables  -A ${chain} $filter $ADDR_FILTER -j $action"
    fi

    ADDR_FILTER=""
    if [ "$srcaddr" != "ALL" ]; then ADDR_FILTER="${ADDR_FILTER} -m set --match-set ${srcaddr}_v6 src"; fi
    if [ "$dstaddr" != "ALL" ]; then ADDR_FILTER="${ADDR_FILTER} -m set --match-set ${dstaddr}_v6 dst"; fi

    if [ "$service" != "ALL" ]; then
        SERVICE_FILTER="-p tcp -m set --match-set ${service}_tcp src"
        echo "ip6tables -A ${chain} $filter $ADDR_FILTER $SERVICE_FILTER -j $action"

        SERVICE_FILTER="-p udp -m set --match-set ${service}_udp src"
        echo "ip6tables -A ${chain} $filter $ADDR_FILTER $SERVICE_FILTER -j $action"
    else
        echo "ip6tables -A ${chain} $filter $ADDR_FILTER -j $action"
    fi
}

# parse rules. those now only need to be filled into the chains defined earlier
grep . ${ETC_DIR}/$1/rules | grep -v '^#' | while read srczone dstzone srcaddr dstaddr service action; do
    if [ "$action" != "accept" ] && [ "$action" != "reject" ] && [ "$action" != "drop" ]; then
        echo >&2 "Invalid action '$action' in rule"
        exit 1
    fi

    # If dst is FW, then we're talking about the INPUT chain
    if [ "$dstzone" = "FW" ]; then
        gen_iptables_commands "${srczone}_inp" "" "$srcaddr" "$dstaddr" "$service" "$action"

    # If dst is ALL, add rules for all interfaces
    elif [ "$dstzone" = "ALL" ]; then
        grep . ${ETC_DIR}/$1/interfaces | grep -v '^#' | while read iface zone; do
            gen_iptables_commands "${srczone}_fwd" "-o ${iface}" "$srcaddr" "$dstaddr" "$service" "$action"
        done

    # Otherwise, add rules for all interfaces in the given zone
    else
        grep . ${ETC_DIR}/$1/interfaces | grep -v '^#' | while read iface zone; do
            if [ "$dstzone" = "$zone" ]; then
                gen_iptables_commands "${srczone}_fwd" "-o ${iface}" "$srcaddr" "$dstaddr" "$service" "$action"
            fi
        done
    fi
done


# Add rules to reject traffic for which no allow rule exists
echo "iptables  -A INPUT   -j reject"
echo "ip6tables -A INPUT   -j reject"

echo "iptables  -A FORWARD -j reject"
echo "ip6tables -A FORWARD -j reject"
