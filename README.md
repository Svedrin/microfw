# MicroFW

iptables firewall inspired by [shorewall](http://www.shorewall.net).


# Configuration

MicroFW uses five tables to read configuration data from. Examples of those can be found in the `etc` subdirectory.

## Services

A list of services (ssh, http, https etc) and their TCP and UDP ports. You can probably use this one as-is.

It is not possible to use plain port numbers in the rules file. If you're running stuff on custom ports, add them here.

## Addresses

A list of address objects you want your firewall to know. You'll have to add your own entries here.

It is not possible to use plain IP addresses in the rules file. If you want your rules to target specific IP addresses or ranges, add them here.

## Interfaces

A list of interfaces, and which zone they belong to. (Note that unlike shorewall, MicroFW does not require a separate zones definition.)

If you need to accept traffic for protocols other than TCP or UDP (for instance, to enable IPsec, GRE tunnels or OSPF), this is also configured here.

## Rules

Here's where things get interesting: The rules file defines which traffic to allow or reject. This is basically a mixture of shorewall's
`rules` and `policy` files.

One rule consists of:

* Source Zone
* Destination Zone
* Source Address
* Destination Address
* Service
* Action

Actions can be:

*   `accept+nat`: Allow the traffic and apply masquerading. To the destination, it will appear as if the traffic originated from the firewall.
    Note that for such rules, the source address field must not be set to `ALL`.
*   `accept`: Allow the traffic.
*   `reject`: Block the traffic, and send a notification back to the sender to let them _know_ they were blocked.
*   `drop`: Block the traffic without letting the sender know. They'll just run into a timeout.

Outbound traffic and ICMP traffic is always allowed.

## Custom

A list of custom rules to include in the configuration. Mostly useful for services to be exposed via DNAT.


# Installation

You can either set things up manually, or use the Ansible playbook provided in the `ansible` directory.

If you choose to install manually:

* `apt-get install ipset iptables`
* Copy `etc/microfw.service` to `/etc/systemd/system/`
* Copy `addresses`, `services`, `interfaces` and `rules` from the `etc` folder to `/etc/microfw` and edit them to your needs
* `mkdir /var/lib/microfw`
* `systemctl daemon-reload`, `systemctl enable microfw`
* `microfw compile`, `systemctl start microfw`
* `microfw apply`


# Usage

MicroFW is used by editing the respective files under `/etc/microfw`, then running `microfw apply` to update iptables.

The `apply` command will compile the rules and import them into iptables. Then it prompts for you to confirm that your SSH session is still
alive. If you don't respond to the prompt within 30 seconds, the firewall is stopped and iptables is torn down. This will enable you to
revive your SSH session, but it also leaves your box completely unprotected. So if that happens, be sure to not leave it like this :P


# Architecture

MicroFW routes traffic through two stages of iptables chains:

1.  IPtables categorizes traffic into INPUT and FORWARD chains by default. MicroFW picks it up from there, and routes it into zone-specific
    Input and Forward chains, depending on the interface over which the traffic arrived originally.

    Traffic belonging to a protocol other than TCP or UDP is accepted in this stage already, if configured.

2.  The actual rules are applied in the zone-specific chains. These chains apply matching on

    * destination interface (mapped from the destination zone)
    * source/destination IP addresses
    * destination TCP and UDP ports.

    This stage then makes a decision on acceptance or rejection for TCP and UDP packets.


NAT rules are applied in the `POSTROUTING` chain. This chain does not allow source interface matching, thus we need to match on source
IP addresses instead. This is why for `accept+nat` rules, the source IP address field cannot be set to `ALL`, but needs to reference
an address object instead.
