Feature: Stuff where none of the more specific features matter.

  Scenario: Example configuration.

    Let's validate that the example configuration from the etc directory actually
    parses, and that the address and service objects are unpacked into ipsets correctly.
    Also validate the basics such as accept/drop/reject chains, RELATED,ESTABLISHED rules,
    protocol-based rules, basic virtuals and make sure that objects that should not be
    created are not just being created anyway.

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
        ipset create 'smtp_tcp' bitmap:port range 1-65535
        ipset add    'smtp_tcp' '25'

        iptables  -A MFWINPUT   -m state --state RELATED,ESTABLISHED -j ACCEPT
        ip6tables -A MFWINPUT   -m state --state RELATED,ESTABLISHED -j ACCEPT
        iptables  -A MFWFORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT
        ip6tables -A MFWFORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT

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

        iptables  -A MFWINPUT   -i 'eth0' -p 'gre'  -j ACCEPT
        ip6tables -A MFWINPUT   -i 'eth0' -p 'gre'  -j ACCEPT
        if [ ! -e "/sys/class/net/eth0/bridge/" ]; then
          iptables  -A MFWFORWARD -i 'eth0' -o 'eth0' -j drop
          ip6tables -A MFWFORWARD -i 'eth0' -o 'eth0' -j drop
        fi
        iptables  -A MFWFORWARD -i 'eth0' -j 'ext_fwd'
        ip6tables -A MFWFORWARD -i 'eth0' -j 'ext_fwd'

        if [ ! -e "/sys/class/net/eth1/bridge/" ]; then
          iptables  -A MFWFORWARD -i 'eth1' -o 'eth1' -j drop
          ip6tables -A MFWFORWARD -i 'eth1' -o 'eth1' -j drop
        fi
        iptables  -A MFWFORWARD -i 'eth1' -j 'int_fwd'
        ip6tables -A MFWFORWARD -i 'eth1' -j 'int_fwd'

        iptables  -A MFWINPUT -i 'tun0' -p 'ospf' -j ACCEPT
        ip6tables -A MFWINPUT -i 'tun0' -p 'ospf' -j ACCEPT

        iptables  -A 'ext_inp' -m geoip --src-cc 'DE' -p 'tcp' -m set --match-set 'smtp_tcp' dst -j accept
        ip6tables -A 'ext_inp' -m geoip --src-cc 'DE' -p 'tcp' -m set --match-set 'smtp_tcp' dst -j accept

        iptables  -A 'ext_fwd' -o 'eth0' -j reject
        iptables  -A 'ext_fwd' -o 'eth1' -j reject
        ip6tables -A 'ext_fwd' -o 'eth0' -j reject
        ip6tables -A 'ext_fwd' -o 'eth1' -j reject

        iptables  -A 'int_fwd' -o 'eth1' -j accept
        ip6tables -A 'int_fwd' -o 'eth1' -j accept

        iptables  -A 'int_fwd' -o 'eth0' -m set --match-set 'lan_home_v4' src -m set --match-set 'google_v4' dst -p 'tcp' -m set --match-set 'http_tcp' dst -j accept
        ip6tables -A 'int_fwd' -o 'eth0' -m set --match-set 'lan_home_v6' src -m set --match-set 'google_v6' dst -p 'tcp' -m set --match-set 'http_tcp' dst -j accept

        iptables  -t 'nat'    -A 'MFWPREROUTING' -i 'eth0' -d '123.123.123.123' -p 'tcp' -m 'tcp' --dport '443' -j DNAT --to-destination '192.168.0.1'
        iptables  -t 'filter' -A 'MFWFORWARD'    -i 'eth0' -d '192.168.0.1'     -p 'tcp' -m 'tcp' --dport '443' -j ACCEPT
        ip6tables -t 'nat'    -A 'MFWPREROUTING' -i 'eth0' -d '2a01::1'         -p 'tcp' -m 'tcp' --dport '443' -j DNAT --to-destination '2a01::1111:1111'
        ip6tables -t 'filter' -A 'MFWFORWARD'    -i 'eth0' -d '2a01::1111:1111' -p 'tcp' -m 'tcp' --dport '443' -j ACCEPT
        """
      And these rules do NOT exist
        """
        ipset create 'http_udp' bitmap:port range 1-65535
        ipset add    'http_udp' '80'
        ipset create 'bgp_tcp' bitmap:port range 1-65535
        ipset add    'bgp_tcp' '179'
        ipset create 'bgp_udp' bitmap:port range 1-65535
        ipset add    'bgp_udp' '179'

        ip6tables -A 'int_fwd' -o 'eth0' -m set --match-set 'lan_home_v4' src -m set --match-set 'google_v4' dst -p 'tcp' -m set --match-set 'http_tcp' dst -j accept
        iptables  -A 'int_fwd' -o 'eth0' -m set --match-set 'lan_home_v6' src -m set --match-set 'google_v6' dst -p 'tcp' -m set --match-set 'http_tcp' dst -j accept
        """

  Scenario: Virtual with services set to ALL

    Given addresses table from etc
      And services table from etc
      And interfaces table from etc
      And rules table from etc
      And virtuals table of
        """
        # src-zone       ext-addr          int-addr       ext-service      int-service
        ext              lan_router_ext    lan_nas        ALL              ALL
        """
     Then the rules compile
      And these rules exist
        """
        iptables  -t 'nat'    -A 'MFWPREROUTING' -i 'eth0' -d '123.123.123.123' -j DNAT --to-destination '192.168.0.1'
        iptables  -t 'filter' -A 'MFWFORWARD'    -i 'eth0' -d '192.168.0.1'     -j ACCEPT
        ip6tables -t 'nat'    -A 'MFWPREROUTING' -i 'eth0' -d '2a01::1'         -j DNAT --to-destination '2a01::1111:1111'
        ip6tables -t 'filter' -A 'MFWFORWARD'    -i 'eth0' -d '2a01::1111:1111' -j ACCEPT
        """

  Scenario: Broken Config: Duplicate interface

    Given addresses table from etc
      And services table from etc
      And interfaces table of
        """
        # Interface        Zone        Protocols
        eth0               ext         gre
        eth0               int         -
        """
      And rules table from etc
      And virtuals table is empty
     Then rule compilation raises a ValueError

  Scenario: Broken Config: Missing column

    Given addresses table from etc
      And services table from etc
      And interfaces table of
        """
        # Interface        Zone
        eth0               ext
        eth1               int
        """
      And rules table from etc
      And virtuals table is empty
     Then rule compilation raises a ValueError

  Scenario: Broken Config: source zone cannot be ALL

    Given addresses table from etc
      And services table from etc
      And interfaces table from etc
      And rules table of
        """
        # Src-Zone      Dest-Zone        Src-Address          Dst-Address            Service        Action
        ALL             FW               ALL                  ALL                    ssh            accept
        """
      And virtuals table is empty
     Then rule compilation raises a ValueError

  Scenario: Broken Config: Invalid action

    Given addresses table from etc
      And services table from etc
      And interfaces table from etc
      And rules table of
        """
        # Src-Zone      Dest-Zone        Src-Address          Dst-Address            Service        Action
        ext             FW               ALL                  ALL                    ssh            ACCEPT
        """
      And virtuals table is empty
     Then rule compilation raises a ValueError

  Scenario: Broken Config: Virtual with only one service set to ALL

    Given addresses table from etc
      And services table from etc
      And interfaces table from etc
      And rules table from etc
      And virtuals table of
        """
        # src-zone       ext-addr          int-addr       ext-service      int-service
        ext              lan_router_ext    lan_nas        https            ALL
        """
     Then rule compilation raises a ValueError
