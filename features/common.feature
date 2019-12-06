Feature: Stuff where none of the more specific features matter.

  Scenario: Example configuration.

    Let's validate that the example configuration from the etc directory actually
    parses, and that the address and service objects are unpacked into ipsets correctly.
    Also validate the basics such as accept/drop/reject chains and RELATED,ESTABLISHED
    rules and protocol-based rules.

    Given addresses table from etc
      And services table from etc
      And interfaces table from etc
      And rules table from etc
      And virtuals table from etc
     Then the rules compile
      And these rules exist
        """
        ipset create 'google_v4' hash:net family inet hashsize 1024 maxelem 65536
        ipset add    'google_v4' '216.58.207.238'
        ipset create 'google_v6' hash:net family inet6 hashsize 1024 maxelem 65536
        ipset add    'google_v6' '2a00:1450:400f:80c::200e'
        ipset create 'lan_home_v4' hash:net family inet hashsize 1024 maxelem 65536
        ipset add    'lan_home_v4' '192.168.0.0/24'
        ipset create 'lan_home_v6' hash:net family inet6 hashsize 1024 maxelem 65536
        ipset add    'lan_home_v6' '2a01::1111:1'
        ipset create 'http_tcp' bitmap:port range 1-65535
        ipset add    'http_tcp' '80'
        ipset create 'mumble_tcp' bitmap:port range 1-65535
        ipset add    'mumble_tcp' '64738'
        ipset create 'mumble_udp' bitmap:port range 1-65535
        ipset add    'mumble_udp' '64738'

        iptables  -N accept
        iptables  -A accept -j ACCEPT
        iptables  -N drop
        iptables  -A drop -j DROP
        iptables  -N reject
        iptables  -A reject -m addrtype --src-type BROADCAST -j DROP
        iptables  -A reject -s 224.0.0.0/4 -j DROP
        iptables  -A reject -p igmp -j DROP
        iptables  -A reject -p tcp -j REJECT --reject-with tcp-reset
        iptables  -A reject -p udp -j REJECT --reject-with icmp-port-unreachable
        iptables  -A reject -p icmp -j REJECT --reject-with icmp-host-unreachable
        iptables  -A reject -j REJECT --reject-with icmp-host-prohibited
        ip6tables -N accept
        ip6tables -A accept -j ACCEPT
        ip6tables -N drop
        ip6tables -A drop -j DROP
        ip6tables -N reject
        ip6tables -A reject -p tcp -j REJECT --reject-with tcp-reset
        ip6tables -A reject -j REJECT --reject-with icmp6-adm-prohibited

        iptables  -A MFWINPUT   -m state --state RELATED,ESTABLISHED -j ACCEPT
        ip6tables -A MFWINPUT   -m state --state RELATED,ESTABLISHED -j ACCEPT
        iptables  -A MFWFORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT
        ip6tables -A MFWFORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT

        iptables  -A MFWINPUT -i 'eth0' -p 'gre'  -j ACCEPT
        ip6tables -A MFWINPUT -i 'eth0' -p 'gre'  -j ACCEPT
        iptables  -A MFWINPUT -i 'tun0' -p 'ospf' -j ACCEPT
        ip6tables -A MFWINPUT -i 'tun0' -p 'ospf' -j ACCEPT

        iptables  -t 'nat'    -A 'MFWPREROUTING' -i 'eth0' -d '123.123.123.123' -p 'tcp' -m 'tcp' --dport '443' -j DNAT --to-destination '192.168.0.1'
        iptables  -t 'filter' -A 'MFWFORWARD'    -i 'eth0' -d '192.168.0.1'     -p 'tcp' -m 'tcp' --dport '443' -j ACCEPT
        ip6tables -t 'nat'    -A 'MFWPREROUTING' -i 'eth0' -d '2a01::1'         -p 'tcp' -m 'tcp' --dport '443' -j DNAT --to-destination '2a01::1111:1111'
        ip6tables -t 'filter' -A 'MFWFORWARD'    -i 'eth0' -d '2a01::1111:1111' -p 'tcp' -m 'tcp' --dport '443' -j ACCEPT
        """
