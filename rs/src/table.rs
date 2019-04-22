use std::fs::File;
use std::io::{BufRead, BufReader, Result};

pub fn read_table<Obj>(table: &str, typefunc: fn(Vec<&str>, usize) -> Obj) -> Result<Vec<Obj>> {
    Ok(
        BufReader::new(File::open(table)?)
            .lines()
            .enumerate()
            .map(|rec| {
                let (lineno, line) = rec;
                if let Ok(line) = line {
                    if line.starts_with("#") {
                        return None;
                    }
                    let words = line.split_whitespace().collect::<Vec<&str>>();
                    if words.len() == 0 {
                        return None;
                    }
                    Some(typefunc(words, lineno))
                }
                else {
                    None
                }
            })
            .filter(|rec| rec.is_some())
            .map(|rec| rec.unwrap())
            .collect()
    )
}
