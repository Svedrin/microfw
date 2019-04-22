use crate::parse_result::ParseResult;
use std::num::ParseIntError;

#[derive(Debug)]
pub struct Service {
    name:      String,
    tcp:       Option<u16>,
    udp:       Option<u16>,
    lineno:    usize
}

fn parse_port(portno: &str) -> Result<Option<u16>, ParseIntError> {
    if portno != "-" {
        Ok(Some(portno.parse()?))
    } else {
        Ok(None)
    }
}

impl Service {
    fn from_words(words: Vec<&str>, lineno: usize) -> ParseResult<Service> {
        ParseResult::Ok(Service {
            name:      words[0].to_string(),
            tcp:       parse_port(words[1])?,
            udp:       parse_port(words[2])?,
            lineno:    lineno
        })
    }
}

pub fn read_services() -> ParseResult<Vec<Service>> {
    crate::table::read_table("services", 3, Service::from_words)
}
