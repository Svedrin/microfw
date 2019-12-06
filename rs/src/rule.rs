use crate::parse_result::ParseResult;

#[derive(Debug)]
pub enum RuleZone {
    All,
    Firewall,
    Specific(String)
}

#[derive(Debug)]
pub enum RuleAddress {
    All,
    Specific(String)
}

#[derive(Debug)]
pub enum RuleService {
    All,
    Specific(String)
}

#[derive(Debug)]
pub enum RuleAction {
    Reject,
    Drop,
    Accept,
    AcceptNat
}

impl From<&str> for RuleZone {
    fn from(zone: &str) -> Self {
        match zone {
            "ALL" => RuleZone::All,
            "FW"  => RuleZone::Firewall,
            _     => RuleZone::Specific(zone.to_string())
        }
    }
}

impl From<&str> for RuleAddress {
    fn from(addr: &str) -> Self {
        match addr {
            "ALL" => RuleAddress::All,
            _     => RuleAddress::Specific(addr.to_string())
        }
    }
}

impl From<&str> for RuleService {
    fn from(service: &str) -> Self {
        match service {
            "ALL" => RuleService::All,
            _     => RuleService::Specific(service.to_string())
        }
    }
}

impl From<&str> for RuleAction {
    fn from(action: &str) -> Self {
        match action {
            "reject"     => RuleAction::Reject,
            "drop"       => RuleAction::Drop,
            "accept"     => RuleAction::Accept,
            "accept+nat" => RuleAction::AcceptNat,
            _ => panic!("Invalid action {}", action)
        }
    }
}

#[derive(Debug)]
pub struct Rule {
    pub srczone: RuleZone,
    pub dstzone: RuleZone,
    pub srcaddr: RuleAddress,
    pub dstaddr: RuleAddress,
    pub service: RuleService,
    pub action:  RuleAction,
    pub lineno:  usize
}

impl Rule {
    fn from_words(words: Vec<&str>, lineno: usize) -> ParseResult<Rule> {
        ParseResult::Ok(Rule {
            srczone: RuleZone::from(words[0]),
            dstzone: RuleZone::from(words[1]),
            srcaddr: RuleAddress::from(words[2]),
            dstaddr: RuleAddress::from(words[3]),
            service: RuleService::from(words[4]),
            action:  RuleAction::from(words[5]),
            lineno:  lineno
        })
    }
}

pub fn read_rules() -> ParseResult<Vec<Rule>> {
    crate::table::read_table("rules", 6, Rule::from_words)
}
