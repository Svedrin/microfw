use std::fs::File;
use std::io::{BufRead, BufReader};

use crate::parse_result::ParseResult;

pub fn read_table<Obj>(
    table: &str,
    cols: usize,
    typefunc: fn(Vec<&str>, usize) -> ParseResult<Obj>
) -> ParseResult<Vec<Obj>> {
    // collect() can magically turn Vec<Result<Obj, String>> into Result<Vec<Obj>, String>.
    // all we need to do is indicate in the return type that we want it to do so.
    // see https://doc.rust-lang.org/std/iter/trait.Iterator.html#method.collect
    let results: Result<Vec<Obj>, String> =
        BufReader::new(File::open(table)?)
            .lines()
            .enumerate()
            .filter_map(|(lineno, line)| {
                if let Err(err) = line {
                    return Some(Err(err.to_string()));
                }
                let line = line.unwrap();
                if line.starts_with("#") {
                    return None;
                }
                let words = line.split_whitespace().collect::<Vec<&str>>();
                if words.len() == 0 {
                    return None;
                }
                if words.len() != cols {
                    return Some(Err(format!(
                        "{}:{}: expected {} columns, found {}",
                        table,
                        lineno,
                        cols,
                        words.len()
                    )));
                }
                let obj = typefunc(words, lineno);
                if let ParseResult::Error(err) = obj {
                    return Some(Err(format!(
                        "{}:{}: {:?}",
                        table,
                        lineno,
                        err
                    )));
                }
                Some(Ok(obj.unwrap()))
            })
            .collect();

    ParseResult::from(results)
}
