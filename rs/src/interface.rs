use std::io::Result;

#[derive(Debug)]
pub struct Interface {
    name:      String,
    zone:      String,
    protocols: Vec<String>,
    lineno:    usize
}

impl Interface {
    fn from_words(words: Vec<&str>, lineno: usize) -> Interface {
        if words.len() != 3 {
            panic!("interfaces:{}: expected 3 arguments, got {}", lineno, words.len());
        }
        if words[1] == "ALL" || words[1] == "FW" {
            panic!("interfaces:{}: zone cannot be ALL or FW", lineno);
        }
        Interface {
            name:      words[0].to_string(),
            zone:      words[1].to_string(),
            protocols: words[2].to_string().split(",").map(|x| x.to_string()).collect(),
            lineno:    lineno
        }
    }
}

pub fn read_interfaces() -> Result<Vec<Interface>> {
    crate::table::read_table("interfaces", Interface::from_words)
}
