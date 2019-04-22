use crate::parse_result::ParseResult;

#[derive(Debug)]
pub struct Interface {
    name:      String,
    zone:      String,
    protocols: Vec<String>,
    lineno:    usize
}

impl Interface {
    fn from_words(words: Vec<&str>, lineno: usize) -> ParseResult<Interface> {
        if words[1] == "ALL" || words[1] == "FW" {
            panic!("interfaces:{}: zone cannot be ALL or FW", lineno);
        }
        ParseResult::Ok(Interface {
            name:      words[0].to_string(),
            zone:      words[1].to_string(),
            protocols: words[2].to_string().split(",").map(|x| x.to_string()).collect(),
            lineno:    lineno
        })
    }
}

pub fn read_interfaces() -> ParseResult<Vec<Interface>> {
    crate::table::read_table("interfaces", 3,Interface::from_words)
}
