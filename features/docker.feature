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
      And virtuals table is empty
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
      And virtuals table is empty
     Then the rules compile
      And these rules exist
        """
        iptables  -t filter -I FORWARD -j MFWFORWARD
        ip6tables -t filter -I FORWARD -j MFWFORWARD
        """

  Scenario: Docker port forwarding

    Expose a Docker service via the virtuals table.

    Given addresses table from etc
      And services table from etc
      And interfaces table from etc
      And rules table from etc
      And virtuals table from etc
     Then the rules compile
      And these rules exist
        """
        iptables  -A 'MFWFORWARD' -i 'eth0' -o 'docker0' -p 'tcp' -m 'tcp' --dport '80' -j RETURN
        ip6tables -A 'MFWFORWARD' -i 'eth0' -o 'docker0' -p 'tcp' -m 'tcp' --dport '80' -j RETURN
        """
