use std::io::Result;

#[derive(Debug)]
pub struct Address {
    name:   String,
    v4:     String,
    v6:     String,
    lineno: usize
}

impl Address {
    fn from_words(words: Vec<&str>, lineno: usize) -> Address {
        if words.len() != 3 {
            panic!("addresses:{}: expected 3 arguments, got {}", lineno, words.len());
        }
        Address {
            name:   words[0].to_string(),
            v4:     words[1].to_string(),
            v6:     words[2].to_string(),
            lineno: lineno
        }
    }
}

pub fn read_addresses() -> Result<Vec<Address>> {
    crate::table::read_table("addresses", Address::from_words)
}
