Feature: Intelligent tear-down.

  Scenario: Docker is absent, mangle chains are absent.

    Given iptables dump of
        """
        # Generated by xtables-save v1.8.2 on Fri Dec  6 22:40:47 2019
        *filter
        :INPUT ACCEPT [0:0]
        :FORWARD ACCEPT [0:0]
        :OUTPUT ACCEPT [0:0]
        :MFWINPUT - [0:0]
        :MFWFORWARD - [0:0]
        :accept - [0:0]
        :drop - [0:0]
        :reject - [0:0]
        :ext_inp - [0:0]
        :ext_fwd - [0:0]
        :int_inp - [0:0]
        :int_fwd - [0:0]
        :f2b-sshd - [0:0]
        -A INPUT -p tcp -m multiport --dports 22 -j f2b-sshd
        -A INPUT -j MFWINPUT
        -A FORWARD -j MFWFORWARD
        -A MFWINPUT -i lo -j ACCEPT
        -A MFWINPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
        -A MFWINPUT -j reject
        -A MFWFORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT
        -A MFWFORWARD -i ens3 -o ens3 -j drop
        -A MFWFORWARD -i ens3 -j ext_fwd
        -A MFWFORWARD -i tun0 -o tun0 -j drop
        -A MFWFORWARD -i tun0 -j int_fwd
        -A MFWFORWARD -j reject
        -A accept -j ACCEPT
        -A drop -j DROP
        -A reject -m addrtype --src-type BROADCAST -j DROP
        -A reject -s 224.0.0.0/4 -j DROP
        -A reject -p igmp -j DROP
        -A reject -p tcp -j REJECT --reject-with tcp-reset
        -A reject -p udp -j REJECT --reject-with icmp-port-unreachable
        -A reject -p icmp -j REJECT --reject-with icmp-host-unreachable
        -A reject -j REJECT --reject-with icmp-host-prohibited
        -A ext_inp -p tcp -m set --match-set tiamat_v4 dst -m set --match-set ssh_tcp dst -j accept
        -A int_inp -j accept
        -A f2b-sshd -j RETURN
        COMMIT
        # Completed on Fri Dec  6 22:40:47 2019
        # Generated by xtables-save v1.8.2 on Fri Dec  6 22:40:47 2019
        *nat
        :PREROUTING ACCEPT [0:0]
        :INPUT ACCEPT [0:0]
        :POSTROUTING ACCEPT [0:0]
        :OUTPUT ACCEPT [0:0]
        :DOCKER - [0:0]
        :MFWPREROUTING - [0:0]
        :MFWPOSTROUTING - [0:0]
        -A PREROUTING -j MFWPREROUTING
        -A PREROUTING -m addrtype --dst-type LOCAL -j DOCKER
        -A DOCKER -i docker0 -j RETURN
        COMMIT
        # Completed on Fri Dec  6 22:40:47 2019
        """
     Then these rules exist
        """
        iptables  -t filter -D FORWARD     -j MFWFORWARD
        iptables  -t filter -D INPUT       -j MFWINPUT
        iptables  -t nat    -D PREROUTING  -j MFWPREROUTING
        iptables  -t nat    -D POSTROUTING -j MFWPOSTROUTING

        iptables  -t filter -F accept
        iptables  -t filter -F drop
        iptables  -t filter -F reject

        iptables  -t filter -F MFWINPUT
        iptables  -t filter -F MFWFORWARD
        iptables  -t nat    -F MFWPREROUTING
        iptables  -t nat    -F MFWPOSTROUTING

        iptables  -t filter -F ext_inp
        iptables  -t filter -X ext_inp
        iptables  -t filter -F ext_fwd
        iptables  -t filter -X ext_fwd
        iptables  -t filter -F int_inp
        iptables  -t filter -X int_inp
        iptables  -t filter -F int_fwd
        iptables  -t filter -X int_fwd

        iptables  -t filter -X accept
        iptables  -t filter -X drop
        iptables  -t filter -X reject

        iptables  -t filter -X MFWINPUT
        iptables  -t filter -X MFWFORWARD
        iptables  -t nat    -X MFWPREROUTING
        iptables  -t nat    -X MFWPOSTROUTING
        """
     Then these rules do NOT exist
        """
        iptables  -t filter -D DOCKER-USER -j MFWFORWARD
        iptables  -t mangle -D FORWARD     -j MFWFORWARD
        iptables  -t mangle -F MFWFORWARD
        iptables  -t mangle -X MFWFORWARD
        """

  Scenario: Docker is absent, mangle chains are present.

    Given iptables dump of
        """
        # Generated by xtables-save v1.8.2 on Fri Dec  6 22:40:47 2019
        *filter
        :INPUT ACCEPT [0:0]
        :FORWARD ACCEPT [0:0]
        :OUTPUT ACCEPT [0:0]
        :MFWINPUT - [0:0]
        :MFWFORWARD - [0:0]
        :accept - [0:0]
        :drop - [0:0]
        :reject - [0:0]
        :ext_inp - [0:0]
        :ext_fwd - [0:0]
        :int_inp - [0:0]
        :int_fwd - [0:0]
        :f2b-sshd - [0:0]
        -A INPUT -p tcp -m multiport --dports 22 -j f2b-sshd
        -A INPUT -j MFWINPUT
        -A FORWARD -j MFWFORWARD
        -A MFWINPUT -i lo -j ACCEPT
        -A MFWINPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
        -A MFWINPUT -j reject
        -A MFWFORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT
        -A MFWFORWARD -i ens3 -o ens3 -j drop
        -A MFWFORWARD -i ens3 -j ext_fwd
        -A MFWFORWARD -i tun0 -o tun0 -j drop
        -A MFWFORWARD -i tun0 -j int_fwd
        -A MFWFORWARD -j reject
        -A accept -j ACCEPT
        -A drop -j DROP
        -A reject -m addrtype --src-type BROADCAST -j DROP
        -A reject -s 224.0.0.0/4 -j DROP
        -A reject -p igmp -j DROP
        -A reject -p tcp -j REJECT --reject-with tcp-reset
        -A reject -p udp -j REJECT --reject-with icmp-port-unreachable
        -A reject -p icmp -j REJECT --reject-with icmp-host-unreachable
        -A reject -j REJECT --reject-with icmp-host-prohibited
        -A ext_inp -p tcp -m set --match-set tiamat_v4 dst -m set --match-set ssh_tcp dst -j accept
        -A int_inp -j accept
        -A f2b-sshd -j RETURN
        COMMIT
        # Completed on Fri Dec  6 22:40:47 2019
        # Generated by xtables-save v1.8.2 on Fri Dec  6 22:40:47 2019
        *nat
        :PREROUTING ACCEPT [0:0]
        :INPUT ACCEPT [0:0]
        :POSTROUTING ACCEPT [0:0]
        :OUTPUT ACCEPT [0:0]
        :DOCKER - [0:0]
        :MFWPREROUTING - [0:0]
        :MFWPOSTROUTING - [0:0]
        -A PREROUTING -j MFWPREROUTING
        -A PREROUTING -m addrtype --dst-type LOCAL -j DOCKER
        -A DOCKER -i docker0 -j RETURN
        COMMIT
        # Completed on Fri Dec  6 22:40:47 2019
        # Generated by xtables-save v1.8.2 on Fri Dec  6 22:40:47 2019
        *mangle
        :PREROUTING ACCEPT [0:0]
        :INPUT ACCEPT [0:0]
        :FORWARD ACCEPT [0:0]
        :OUTPUT ACCEPT [0:0]
        :POSTROUTING ACCEPT [0:0]
        :DOCKER_fwd - [0:0]
        :ext_fwd - [0:0]
        :int_fwd - [0:0]
        :MFWFORWARD - [0:0]
        -A FORWARD -j MFWFORWARD
        -A MFWFORWARD -i ens3 -j ext_fwd
        -A MFWFORWARD -i tun0 -j int_fwd
        COMMIT
        # Completed on Fri Dec  6 22:40:47 2019
        """
     Then these rules exist
        """
        iptables  -t filter -D FORWARD     -j MFWFORWARD
        iptables  -t filter -D INPUT       -j MFWINPUT
        iptables  -t mangle -D FORWARD     -j MFWFORWARD
        iptables  -t nat    -D PREROUTING  -j MFWPREROUTING
        iptables  -t nat    -D POSTROUTING -j MFWPOSTROUTING

        iptables  -t filter -F accept
        iptables  -t filter -F drop
        iptables  -t filter -F reject

        iptables  -t filter -F MFWINPUT
        iptables  -t filter -F MFWFORWARD
        iptables  -t mangle -F MFWFORWARD
        iptables  -t nat    -F MFWPREROUTING
        iptables  -t nat    -F MFWPOSTROUTING

        iptables  -t filter -F ext_inp
        iptables  -t filter -X ext_inp
        iptables  -t filter -F ext_fwd
        iptables  -t filter -X ext_fwd
        iptables  -t filter -F int_inp
        iptables  -t filter -X int_inp
        iptables  -t filter -F int_fwd
        iptables  -t filter -X int_fwd

        iptables  -t filter -X accept
        iptables  -t filter -X drop
        iptables  -t filter -X reject

        iptables  -t filter -X MFWINPUT
        iptables  -t filter -X MFWFORWARD
        iptables  -t mangle -X MFWFORWARD
        iptables  -t nat    -X MFWPREROUTING
        iptables  -t nat    -X MFWPOSTROUTING
        """
     Then these rules do NOT exist
        """
        iptables  -t filter -D DOCKER-USER -j MFWFORWARD
        """

  Scenario: Docker is present, mangle chains are absent.

    Given iptables dump of
        """
        # Generated by xtables-save v1.8.2 on Fri Dec  6 22:40:47 2019
        *filter
        :INPUT ACCEPT [0:0]
        :FORWARD ACCEPT [0:0]
        :OUTPUT ACCEPT [0:0]
        :DOCKER-USER - [0:0]
        :DOCKER - [0:0]
        :DOCKER-ISOLATION-STAGE-1 - [0:0]
        :DOCKER-ISOLATION-STAGE-2 - [0:0]
        :MFWINPUT - [0:0]
        :MFWFORWARD - [0:0]
        :accept - [0:0]
        :drop - [0:0]
        :reject - [0:0]
        :DOCKER_inp - [0:0]
        :DOCKER_fwd - [0:0]
        :ext_inp - [0:0]
        :ext_fwd - [0:0]
        :int_inp - [0:0]
        :int_fwd - [0:0]
        :f2b-sshd - [0:0]
        -A INPUT -p tcp -m multiport --dports 22 -j f2b-sshd
        -A INPUT -j MFWINPUT
        -A FORWARD -j DOCKER-USER
        -A FORWARD -j DOCKER-ISOLATION-STAGE-1
        -A FORWARD -o docker0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
        -A FORWARD -o docker0 -j DOCKER
        -A FORWARD -i docker0 ! -o docker0 -j ACCEPT
        -A FORWARD -i docker0 -o docker0 -j ACCEPT
        -A DOCKER-USER -j MFWFORWARD
        -A MFWINPUT -i lo -j ACCEPT
        -A MFWINPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
        -A MFWINPUT -j reject
        -A MFWFORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT
        -A MFWFORWARD -i ens3 -o ens3 -j drop
        -A MFWFORWARD -i ens3 -j ext_fwd
        -A MFWFORWARD -i tun0 -o tun0 -j drop
        -A MFWFORWARD -i tun0 -j int_fwd
        -A MFWFORWARD -j reject
        -A accept -j ACCEPT
        -A drop -j DROP
        -A reject -m addrtype --src-type BROADCAST -j DROP
        -A reject -s 224.0.0.0/4 -j DROP
        -A reject -p igmp -j DROP
        -A reject -p tcp -j REJECT --reject-with tcp-reset
        -A reject -p udp -j REJECT --reject-with icmp-port-unreachable
        -A reject -p icmp -j REJECT --reject-with icmp-host-unreachable
        -A reject -j REJECT --reject-with icmp-host-prohibited
        -A DOCKER_fwd -o ens3 -j accept
        -A ext_inp -p tcp -m set --match-set tiamat_v4 dst -m set --match-set ssh_tcp dst -j accept
        -A int_inp -j accept
        -A f2b-sshd -j RETURN
        COMMIT
        # Completed on Fri Dec  6 22:40:47 2019
        # Generated by xtables-save v1.8.2 on Fri Dec  6 22:40:47 2019
        *nat
        :PREROUTING ACCEPT [0:0]
        :INPUT ACCEPT [0:0]
        :POSTROUTING ACCEPT [0:0]
        :OUTPUT ACCEPT [0:0]
        :DOCKER - [0:0]
        :MFWPREROUTING - [0:0]
        :MFWPOSTROUTING - [0:0]
        -A PREROUTING -j MFWPREROUTING
        -A PREROUTING -m addrtype --dst-type LOCAL -j DOCKER
        -A DOCKER -i docker0 -j RETURN
        COMMIT
        # Completed on Fri Dec  6 22:40:47 2019
        """
     Then these rules exist
        """
        iptables  -t filter -D DOCKER-USER -j MFWFORWARD
        iptables  -t filter -D INPUT       -j MFWINPUT
        iptables  -t nat    -D PREROUTING  -j MFWPREROUTING
        iptables  -t nat    -D POSTROUTING -j MFWPOSTROUTING

        iptables  -t filter -F accept
        iptables  -t filter -F drop
        iptables  -t filter -F reject

        iptables  -t filter -F MFWINPUT
        iptables  -t filter -F MFWFORWARD
        iptables  -t nat    -F MFWPREROUTING
        iptables  -t nat    -F MFWPOSTROUTING

        iptables  -t filter -F ext_inp
        iptables  -t filter -X ext_inp
        iptables  -t filter -F ext_fwd
        iptables  -t filter -X ext_fwd
        iptables  -t filter -F int_inp
        iptables  -t filter -X int_inp
        iptables  -t filter -F int_fwd
        iptables  -t filter -X int_fwd

        iptables  -t filter -X accept
        iptables  -t filter -X drop
        iptables  -t filter -X reject

        iptables  -t filter -X MFWINPUT
        iptables  -t filter -X MFWFORWARD
        iptables  -t nat    -X MFWPREROUTING
        iptables  -t nat    -X MFWPOSTROUTING
        """
     Then these rules do NOT exist
        """
        iptables  -t filter -D FORWARD -j MFWFORWARD
        iptables  -t mangle -D FORWARD     -j MFWFORWARD
        iptables  -t mangle -F MFWFORWARD
        iptables  -t mangle -X MFWFORWARD
        """


  Scenario: Docker is present, mangle chains are present.

    Given iptables dump of
        """
        # Generated by xtables-save v1.8.2 on Fri Dec  6 22:40:47 2019
        *filter
        :INPUT ACCEPT [0:0]
        :FORWARD ACCEPT [0:0]
        :OUTPUT ACCEPT [0:0]
        :DOCKER-USER - [0:0]
        :DOCKER - [0:0]
        :DOCKER-ISOLATION-STAGE-1 - [0:0]
        :DOCKER-ISOLATION-STAGE-2 - [0:0]
        :MFWINPUT - [0:0]
        :MFWFORWARD - [0:0]
        :accept - [0:0]
        :drop - [0:0]
        :reject - [0:0]
        :DOCKER_inp - [0:0]
        :DOCKER_fwd - [0:0]
        :ext_inp - [0:0]
        :ext_fwd - [0:0]
        :int_inp - [0:0]
        :int_fwd - [0:0]
        :f2b-sshd - [0:0]
        -A INPUT -p tcp -m multiport --dports 22 -j f2b-sshd
        -A INPUT -j MFWINPUT
        -A FORWARD -j DOCKER-USER
        -A FORWARD -j DOCKER-ISOLATION-STAGE-1
        -A FORWARD -o docker0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
        -A FORWARD -o docker0 -j DOCKER
        -A FORWARD -i docker0 ! -o docker0 -j ACCEPT
        -A FORWARD -i docker0 -o docker0 -j ACCEPT
        -A DOCKER-USER -j MFWFORWARD
        -A MFWINPUT -i lo -j ACCEPT
        -A MFWINPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
        -A MFWINPUT -j reject
        -A MFWFORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT
        -A MFWFORWARD -i ens3 -o ens3 -j drop
        -A MFWFORWARD -i ens3 -j ext_fwd
        -A MFWFORWARD -i tun0 -o tun0 -j drop
        -A MFWFORWARD -i tun0 -j int_fwd
        -A MFWFORWARD -j reject
        -A accept -j ACCEPT
        -A drop -j DROP
        -A reject -m addrtype --src-type BROADCAST -j DROP
        -A reject -s 224.0.0.0/4 -j DROP
        -A reject -p igmp -j DROP
        -A reject -p tcp -j REJECT --reject-with tcp-reset
        -A reject -p udp -j REJECT --reject-with icmp-port-unreachable
        -A reject -p icmp -j REJECT --reject-with icmp-host-unreachable
        -A reject -j REJECT --reject-with icmp-host-prohibited
        -A DOCKER_fwd -o ens3 -j accept
        -A ext_inp -p tcp -m set --match-set tiamat_v4 dst -m set --match-set ssh_tcp dst -j accept
        -A int_inp -j accept
        -A f2b-sshd -j RETURN
        COMMIT
        # Completed on Fri Dec  6 22:40:47 2019
        # Generated by xtables-save v1.8.2 on Fri Dec  6 22:40:47 2019
        *nat
        :PREROUTING ACCEPT [0:0]
        :INPUT ACCEPT [0:0]
        :POSTROUTING ACCEPT [0:0]
        :OUTPUT ACCEPT [0:0]
        :DOCKER - [0:0]
        :MFWPREROUTING - [0:0]
        :MFWPOSTROUTING - [0:0]
        -A PREROUTING -j MFWPREROUTING
        -A PREROUTING -m addrtype --dst-type LOCAL -j DOCKER
        -A DOCKER -i docker0 -j RETURN
        COMMIT
        # Completed on Fri Dec  6 22:40:47 2019
        # Generated by xtables-save v1.8.2 on Fri Dec  6 22:40:47 2019
        *mangle
        :PREROUTING ACCEPT [0:0]
        :INPUT ACCEPT [0:0]
        :FORWARD ACCEPT [0:0]
        :OUTPUT ACCEPT [0:0]
        :POSTROUTING ACCEPT [0:0]
        :DOCKER_fwd - [0:0]
        :ext_fwd - [0:0]
        :int_fwd - [0:0]
        :MFWFORWARD - [0:0]
        -A FORWARD -j MFWFORWARD
        -A MFWFORWARD -i ens3 -j ext_fwd
        -A MFWFORWARD -i tun0 -j int_fwd
        COMMIT
        # Completed on Fri Dec  6 22:40:47 2019
        """
     Then these rules exist
        """
        iptables  -t filter -D DOCKER-USER -j MFWFORWARD
        iptables  -t filter -D INPUT       -j MFWINPUT
        iptables  -t mangle -D FORWARD     -j MFWFORWARD
        iptables  -t nat    -D PREROUTING  -j MFWPREROUTING
        iptables  -t nat    -D POSTROUTING -j MFWPOSTROUTING

        iptables  -t filter -F accept
        iptables  -t filter -F drop
        iptables  -t filter -F reject

        iptables  -t filter -F MFWINPUT
        iptables  -t filter -F MFWFORWARD
        iptables  -t mangle -F MFWFORWARD
        iptables  -t nat    -F MFWPREROUTING
        iptables  -t nat    -F MFWPOSTROUTING

        iptables  -t filter -F ext_inp
        iptables  -t filter -X ext_inp
        iptables  -t filter -F ext_fwd
        iptables  -t filter -X ext_fwd
        iptables  -t filter -F int_inp
        iptables  -t filter -X int_inp
        iptables  -t filter -F int_fwd
        iptables  -t filter -X int_fwd

        iptables  -t filter -X accept
        iptables  -t filter -X drop
        iptables  -t filter -X reject

        iptables  -t filter -X MFWINPUT
        iptables  -t filter -X MFWFORWARD
        iptables  -t mangle -X MFWFORWARD
        iptables  -t nat    -X MFWPREROUTING
        iptables  -t nat    -X MFWPOSTROUTING
        """
     Then these rules do NOT exist
        """
        iptables  -t filter -D FORWARD -j MFWFORWARD
        """
