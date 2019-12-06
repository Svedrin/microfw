Feature: Masq from a whole zone.

  Masquerading traffic is done in the POSTROUTING chain, which does not allow for source
  interface matching. In order to masq all traffic from one zone to another, source interface
  matching would be necessary though, which means it cannot be implemented trivially.

  There is a way though: We can use the mangle chain, do our source interface match there and
  have iptables mark packets in this chain. Then in POSTROUTING we do a match on the label
  instead of the source interface directly, and use -j MASQUERADE to apply NAT.

  Scenario: Masq from zone

    Here, mangle should be used.

    Given addresses table from etc
      And services table from etc
      And interfaces table of
        """
        # Interface        Zone        Protocols

        eth0               ext         gre
        eth1               int         -
        """
      And rules table of
        """
        # Src-Zone      Dest-Zone        Src-Address          Dst-Address            Service        Action
        int             ext              ALL                  ALL                    ALL            accept+nat
        """
      And virtuals table from etc
     Then the rules compile
      And these rules exist
        """
        iptables  -t mangle -I FORWARD     -j MFWFORWARD
        ip6tables -t mangle -I FORWARD     -j MFWFORWARD
        iptables  -t nat    -I POSTROUTING -j MFWPOSTROUTING
        ip6tables -t nat    -I POSTROUTING -j MFWPOSTROUTING
        iptables  -t mangle -A MFWFORWARD  -i 'eth1' -j 'int_fwd'
        ip6tables -t mangle -A MFWFORWARD  -i 'eth1' -j 'int_fwd'
        iptables  -t 'mangle' -A 'int_fwd'        -o 'eth0' -j MARK --set-mark 0x400
        iptables  -t 'nat'    -A 'MFWPOSTROUTING' -o 'eth0' -m mark --mark 0x400 -j MASQUERADE
        ip6tables -t 'mangle' -A 'int_fwd'        -o 'eth0' -j MARK --set-mark 0x401
        ip6tables -t 'nat'    -A 'MFWPOSTROUTING' -o 'eth0' -m mark --mark 0x401 -j MASQUERADE
        """

  Scenario: Masq from lan_home

    Here, a standard MASQUERADE rule should be generated.

    Given addresses table from etc
      And services table from etc
      And interfaces table of
        """
        # Interface        Zone        Protocols

        eth0               ext         gre
        eth1               int         -
        """
      And rules table of
        """
        # Src-Zone      Dest-Zone        Src-Address          Dst-Address            Service        Action
        int             ext              lan_home             ALL                    ALL            accept+nat
        """
      And virtuals table from etc
     Then the rules compile
      And these rules exist
        """
        iptables  -t nat -I POSTROUTING -j MFWPOSTROUTING
        ip6tables -t nat -I POSTROUTING -j MFWPOSTROUTING
        iptables  -t 'nat' -A 'MFWPOSTROUTING' -o 'eth0' -m set --match-set 'lan_home_v4' src -j MASQUERADE
        ip6tables -t 'nat' -A 'MFWPOSTROUTING' -o 'eth0' -m set --match-set 'lan_home_v6' src -j MASQUERADE
        """
