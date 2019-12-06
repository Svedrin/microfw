Feature: Docker attachment.

  Scenario: Docker zone is present

    Docker is present: Make sure the MFWFORWARD chain attaches to DOCKER-USER.

    Given addresses table from etc
      And services table from etc
      And interfaces table of
        """
        # Interface        Zone        Protocols

        eth0               ext         gre
        eth1               int         -
        tun0               int         ospf
        gre0               int         ospf
        docker0            DOCKER      -
        """
      And rules table from etc
      And virtuals table from etc
     Then the rules compile
      And these rules exist
        """
        iptables  -t filter -I DOCKER-USER -j MFWFORWARD
        ip6tables -t filter -I FORWARD     -j MFWFORWARD
        """

  Scenario: Docker zone does not exist

    Docker is absent: Make sure the MFWFORWARD chain attaches to FORWARD.

    Given addresses table from etc
      And services table from etc
      And interfaces table of
        """
        # Interface        Zone        Protocols

        eth0               ext         gre
        eth1               int         -
        tun0               int         ospf
        gre0               int         ospf
        """
      And rules table from etc
      And virtuals table of
        """
        # src-zone       ext-addr          int-addr       ext-service      int-service
        ext              lan_router_ext    lan_nas        https            https
        """
     Then the rules compile
      And these rules exist
        """
        iptables  -t filter -I FORWARD -j MFWFORWARD
        ip6tables -t filter -I FORWARD -j MFWFORWARD
        """
