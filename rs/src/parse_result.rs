use std::ops::Try;

#[derive(Debug)]
pub enum ParseResult<T> {
    Ok(T),
    Error(ParseErrorKind)
}

#[derive(Debug)]
pub enum ParseErrorKind {
    InvalidValue(std::num::ParseIntError),
    IoError(std::io::Error),
    GenericError(String)
}

impl<T> ParseResult<T> {
    pub fn unwrap(self) -> T {
        match self {
            ParseResult::Ok(t) => t,
            ParseResult::Error(e) => panic!("called `Result::unwrap()` on an `Err` value: {:?}", e),
        }
    }
}

impl<T> From<Result<T, String>> for ParseResult<T> {
    fn from(res: Result<T, String>) -> ParseResult<T> {
        match res {
            Ok(v)  => ParseResult::Ok(v),
            Err(e) => ParseResult::Error(ParseErrorKind::GenericError(e))
        }
    }
}

impl<T> Try for ParseResult<T> {
    type Ok = T;
    type Error = ParseErrorKind;

    fn into_result(self) -> Result<<Self as Try>::Ok, <Self as Try>::Error> {
        match self {
            ParseResult::Ok(v)     => Ok(v),
            ParseResult::Error(e)  => Err(e),
        }
    }

    fn from_error(v: <Self as Try>::Error) -> Self {
        ParseResult::Error(v)
    }

    fn from_ok(v: <Self as Try>::Ok) -> Self {
        ParseResult::Ok(v)
    }
}

impl From<std::io::Error> for ParseErrorKind {
    fn from(err: std::io::Error) -> ParseErrorKind {
        ParseErrorKind::IoError(err)
    }
}

impl From<std::num::ParseIntError> for ParseErrorKind {
    fn from(err: std::num::ParseIntError) -> ParseErrorKind {
        ParseErrorKind::InvalidValue(err)
    }
}
