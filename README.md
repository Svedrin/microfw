# MicroFW

iptables firewall inspired by [shorewall](http://www.shorewall.net).

* easy to configure
* keeps rulesets in sync for IPv4 and IPv6 (but allows for divergences where necessary)
* correctly integrates with Docker (you can run it on a Docker host and be sure Docker won't render it useless)
* implemented in pure Python with zero dependencies

# Configuration

MicroFW uses ascii tables to read configuration data from. Examples of those can be found in the `etc` subdirectory.

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
*   `accept`: Allow the traffic.
*   `reject`: Block the traffic, and send a notification back to the sender to let them _know_ they were blocked.
*   `drop`: Block the traffic without letting the sender know. They'll just run into a timeout.

Outbound traffic is always allowed.

ICMP traffic is allowed by default. However, if you define an explicit rule to reject or drop traffic for `ALL` services, that includes ICMP.

## Virtuals

A list of virtual services to expose via DNAT.


# Docker integration

MicroFW is developed with Docker in mind, and is supposed to Just Work with Docker present. To make sure this works, be sure to list
your `docker0` bridge in your `interfaces` file as such:

    # Interface        Zone        Protocols
    docker0            DOCKER      -

In the presence of a `DOCKER` zone, MicroFW will attach all its rules to the `DOCKER-USER` chain to ensure Docker and MicroFW play
nicely with one another. (Requires a fairly up-to-date version of Docker though.)


# Installation

You can either set things up manually, or use the Ansible playbook provided in the `ansible` directory.

If you choose to install manually:

* `apt-get install ipset iptables`
* Copy `etc/microfw.service` to `/etc/systemd/system/`
* Copy `addresses`, `services`, `interfaces`, `rules` and `virtuals` from the `etc` folder to `/etc/microfw` and edit them to your needs
* `mkdir /var/lib/microfw`
* `systemctl daemon-reload`, `systemctl enable microfw`
* `microfw compile`, `systemctl start microfw`
* `microfw apply`


# Usage

MicroFW is used by editing the respective files under `/etc/microfw`, then running `microfw apply` to update iptables.

The `apply` command will compile the rules and import them into iptables. Then it prompts for you to confirm that your SSH session is still
alive. If you don't respond to the prompt within 30 seconds, the firewall is stopped and iptables is torn down. This will enable you to
revive your SSH session, but it also leaves your box completely unprotected. So if that happens, be sure to not leave it like this :P


# Managing multiple MicroFWs from a central location

If you want to make use of the ansible playbook and `deploy.sh`, you'll notice that both refer to a `nodes/` subdirectory which does not exist.
To properly support managing multiple nodes from a central location, you need to:

* `mkdir nodes`
* create a file named `nodes/inventory` that contains a list of all nodes you wish to manage
* for each node, `mkdir nodes/<node>` and put the config files in there
* then run `./deploy.sh [<node>]` to deploy.

Note that the playbook does not actually _apply_ the rules. It just installs everything and runs `microfw compile`, then chickens out. If
you want to actually apply the rules, it's probably easiest if you add a step to restart the `microfw` service through systemd.


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


## Ingress path

Here's how incoming packets are routed:

```
         NAT                     |                             FILTER

       +---------------+         |         +---------------+       +---------------+
 --->  |   PREROUTING  |                   |    FORWARD    |------>|  DOCKER-USER  |
       +---------------+         |         +---------------+       +---------------+
               |                                   ^                       |
               v                 |                 |                       v
       +---------------+                 NO:       |               +---------------+      +----------+
       | MFWPREROUTING |         |  For Container  |               |  MFWFORWARD   |----->| DOCKER   |
       +---------------+            For VM         |               +---------------+      +----------+
               |                 |  For whomever   |
               v                               --------
       +---------------+         |            /   For  \           +---------------+      +----------+
       |    DOCKER     | ---------------->   *    me?   *  ------->|  INPUT        |----->| MFWINPUT |
       +---------------+         |            \        /           +---------------+      +----------+
                                               --------    YES:
                                                         Local services,
                                                         docker-proxy
```

If Docker is not present on a system, all docker-related chains are skipped and MicroFW plugs directly into `FORWARD`.

## Egress path

The only situation in which outgoing packets are touched is if they match an `accept+nat` rule, in which case they are
routed through the `MFWPOSTROUTING` chain to be masqueraded. In all other cases, outgoing packets are left alone.
