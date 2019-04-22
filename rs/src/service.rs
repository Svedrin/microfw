use std::io::Result;

#[derive(Debug)]
pub struct Service {
    name:      String,
    tcp:       Option<u16>,
    udp:       Option<u16>,
    lineno:    usize
}

fn parse_port(portno: &str, lineno: usize) -> Option<u16> {
    if portno != "-" {
        Some(
            portno
                .parse()
                .expect(&format!("services:{}:could not parse port number {}", lineno, portno))
        )
    } else {
        None
    }
}

impl Service {
    fn from_words(words: Vec<&str>, lineno: usize) -> Service {
        if words.len() != 3 {
            panic!("interfaces:{}: expected 3 arguments, got {}", lineno, words.len());
        }

        Service {
            name:      words[0].to_string(),
            tcp:       parse_port(words[1], lineno),
            udp:       parse_port(words[2], lineno),
            lineno:    lineno
        }
    }
}

pub fn read_services() -> Result<Vec<Service>> {
    crate::table::read_table("services", Service::from_words)
}
