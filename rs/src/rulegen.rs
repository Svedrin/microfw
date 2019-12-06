use crate::interface::Interface;
use crate::address::Address;
use crate::service::Service;
use crate::rule::{Rule, RuleZone, RuleAction};

pub struct RuleGen {
    pub all_interfaces: Vec<Interface>,
    pub all_addresses:  Vec<Address>,
    pub all_services:   Vec<Service>,
}

struct RuleGenState {
    pub iptables: Option<String>,
    pub table:    Option<String>,
    pub chain:    Option<String>,
    pub iface:    Option<String>,
    pub srcaddr:  Option<String>,
    pub dstaddr:  Option<String>,
    pub service:  Option<String>,
    pub action:   Option<String>,
}

enum RuleGenStateExtend {
    IPTables(String),
    table(String),
    chain(String),
    iface(String),
    srcaddr(String),
    dstaddr(String),
    service(String),
    action(String),
}

impl RuleGenState {
    fn new() -> RuleGenState {
        RuleGenState {
            iptables: None,
            table:    None,
            chain:    None,
            iface:    None,
            srcaddr:  None,
            dstaddr:  None,
            service:  None,
            action:   None,
        }
    }

    fn derive(&self, field: RuleGenStateExtend) -> RuleGenState {
        match field {
            RuleGenStateExtend::IPTables(cmd) =>
                RuleGenState {
                    iptables: Some(cmd),
                    table:    self.table   .clone(),
                    chain:    self.chain   .clone(),
                    iface:    self.iface   .clone(),
                    srcaddr:  self.srcaddr .clone(),
                    dstaddr:  self.dstaddr .clone(),
                    service:  self.service .clone(),
                    action:   self.action  .clone(),
                },
            RuleGenStateExtend::table(table) =>
                RuleGenState {
                    iptables: self.iptables.clone(),
                    table:    Some(table),
                    chain:    self.chain   .clone(),
                    iface:    self.iface   .clone(),
                    srcaddr:  self.srcaddr .clone(),
                    dstaddr:  self.dstaddr .clone(),
                    service:  self.service .clone(),
                    action:   self.action  .clone(),
                },

        }
        RuleGenState {
            iptables: iptables.or(self.iptables.clone()),
            table:    table   .or(self.table   .clone()),
            chain:    chain   .or(self.chain   .clone()),
            iface:    iface   .or(self.iface   .clone()),
            srcaddr:  srcaddr .or(self.srcaddr .clone()),
            dstaddr:  dstaddr .or(self.dstaddr .clone()),
            service:  service .or(self.service .clone()),
            action:   action  .or(self.action  .clone()),
        }
    }
}

impl RuleGen {
    pub fn generate(&self, rule: &Rule) {
        self.iptables(rule)
    }

    fn iptables(&self, rule: &Rule) {
        self.chain(rule, RuleGenState::new()
            .derive("iptables", None, None, None, None, None));
        self.chain(rule, RuleGenState {
            iptables: Some("ip6tables".to_string()),
            chain:    None,
            srcaddr:  None,
            dstaddr:  None,
        });
    }

    fn chain(&self, rule: &Rule, state: RuleGenState) {
        let next = |chain: String| {
            match &rule.srczone {
                RuleZone::All      => panic!("All not supported in source zones"),
                RuleZone::Firewall => panic!("FW not supported in source zones"),
                RuleZone::Specific(srczone) =>
                    self.srcaddr(rule, RuleGenState {
                        iptables: state.iptables.clone(),
                        chain:    Some(format!("{}_{}", srczone, chain).to_string()),
                        srcaddr:  None,
                        dstaddr:  None,
                    })
            }
        };
        match rule.dstzone {
            RuleZone::All      => next("inp".to_string()),
            RuleZone::Firewall => next("inp".to_string()),
            _ => ()
        }
        for interface in &self.all_interfaces {
            match rule.dstzone {
                RuleZone::Specific(ref zone) if zone == &interface.zone
                    => next("fwd".to_string()),
                RuleZone::All
                    => next("fwd".to_string()),
                _ => ()
            }
        }
    }

    fn srcaddr(&self, rule: &Rule, state: RuleGenState) {
        println!("{} -A {}", &state.iptables.unwrap(), &state.chain.unwrap());
    }
}
