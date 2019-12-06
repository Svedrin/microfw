use crate::parse_result::ParseResult;

#[derive(Debug)]
pub struct Address {
    pub name:   String,
    pub v4:     String,
    pub v6:     String,
    pub lineno: usize
}

impl Address {
    fn from_words(words: Vec<&str>, lineno: usize) -> ParseResult<Address> {
        ParseResult::Ok(Address {
            name:   words[0].to_string(),
            v4:     words[1].to_string(),
            v6:     words[2].to_string(),
            lineno: lineno
        })
    }
}

pub fn read_addresses() -> ParseResult<Vec<Address>> {
    crate::table::read_table("addresses", 3, Address::from_words)
}
