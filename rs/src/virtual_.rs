use std::io::Result;

#[derive(Debug)]
pub enum VirtualZone {
    All,
    Specific(String)
}

#[derive(Debug)]
pub enum VirtualAddress {
    All,
    Specific(String)
}

#[derive(Debug)]
pub enum VirtualService {
    All,
    Specific(String)
}

impl From<&str> for VirtualZone {
    fn from(zone: &str) -> Self {
        match zone {
            "ALL" => VirtualZone::All,
            _     => VirtualZone::Specific(zone.to_string())
        }
    }
}

impl From<&str> for VirtualAddress {
    fn from(addr: &str) -> Self {
        match addr {
            "ALL" => VirtualAddress::All,
            _     => VirtualAddress::Specific(addr.to_string())
        }
    }
}

impl From<&str> for VirtualService {
    fn from(service: &str) -> Self {
        match service {
            "ALL" => VirtualService::All,
            _     => VirtualService::Specific(service.to_string())
        }
    }
}

#[derive(Debug)]
pub struct Virtual {
    srczone: VirtualZone,
    extaddr: VirtualAddress,
    intaddr: VirtualAddress,
    extservice: VirtualService,
    intservice: VirtualService,
    lineno:  usize
}

impl Virtual {
    fn from_words(words: Vec<&str>, lineno: usize) -> Virtual {
        if words.len() != 5 {
            panic!("virtuals:{}: expected 5 arguments, got {}", lineno, words.len());
        }
        Virtual {
            srczone: VirtualZone::from(words[0]),
            extaddr: VirtualAddress::from(words[1]),
            intaddr: VirtualAddress::from(words[2]),
            extservice: VirtualService::from(words[3]),
            intservice: VirtualService::from(words[4]),
            lineno:  lineno
        }
    }
}

pub fn read_virtuals() -> Result<Vec<Virtual>> {
    crate::table::read_table("virtuals", Virtual::from_words)
}
