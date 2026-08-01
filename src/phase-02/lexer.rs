use crate::diagnostic::{Diagnostic, sort_diagnostics};
use crate::source::{MAX_IDENTIFIER_BYTES, Origin, Position};

#[derive(Clone, Debug, Eq, PartialEq)]
pub enum TokenKind {
    Identifier(String),
    Integer(i64),
    String(String),
    Module,
    Version,
    Opaque,
    Record,
    Result,
    Ok,
    Error,
    Effect,
    Operation,
    Function,
    Task,
    Requires,
    Perform,
    Ensures,
    Let,
    Match,
    True,
    False,
    IntType,
    BoolType,
    StringType,
    ResultType,
    LeftBrace,
    RightBrace,
    LeftParen,
    RightParen,
    LeftBracket,
    RightBracket,
    Less,
    Greater,
    Comma,
    Colon,
    Semicolon,
    Dot,
    Pipe,
    Equal,
    EqualEqual,
    Plus,
    Arrow,
    FatArrow,
    Sequence,
    Eof,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct Token {
    pub kind: TokenKind,
    pub origin: Origin,
}

#[must_use]
pub fn lex(source_name: &str, text: &str) -> (Vec<Token>, Vec<Diagnostic>) {
    let mut lexer = Lexer::new(source_name, text);
    lexer.run();
    sort_diagnostics(&mut lexer.diagnostics);
    (lexer.tokens, lexer.diagnostics)
}

struct Lexer<'a> {
    source_name: &'a str,
    text: &'a str,
    byte: usize,
    line: u32,
    column: u32,
    tokens: Vec<Token>,
    diagnostics: Vec<Diagnostic>,
}

impl<'a> Lexer<'a> {
    fn new(source_name: &'a str, text: &'a str) -> Self {
        Self {
            source_name,
            text,
            byte: 0,
            line: 1,
            column: 1,
            tokens: Vec::new(),
            diagnostics: Vec::new(),
        }
    }

    fn run(&mut self) {
        while let Some(character) = self.peek() {
            match character {
                ' ' | '\t' | '\r' | '\n' => self.skip_whitespace(),
                '/' if self.peek_next() == Some('/') => self.skip_comment(),
                'a'..='z' | 'A'..='Z' | '_' => self.identifier(),
                '0'..='9' => self.integer(),
                '"' => self.string(),
                '{' => self.single(TokenKind::LeftBrace),
                '}' => self.single(TokenKind::RightBrace),
                '(' => self.single(TokenKind::LeftParen),
                ')' => self.single(TokenKind::RightParen),
                '[' => self.single(TokenKind::LeftBracket),
                ']' => self.single(TokenKind::RightBracket),
                '<' => self.single(TokenKind::Less),
                ',' => self.single(TokenKind::Comma),
                ':' => self.single(TokenKind::Colon),
                ';' => self.single(TokenKind::Semicolon),
                '.' => self.single(TokenKind::Dot),
                '|' => self.single(TokenKind::Pipe),
                '+' => self.single(TokenKind::Plus),
                '=' => self.equal_or_arrow(),
                '-' => self.required_compound('>', TokenKind::Arrow, "LEX_EXPECTED_ARROW"),
                '>' => self.compound('>', TokenKind::Sequence, TokenKind::Greater),
                _ => self.invalid_character(),
            }
        }
        let position = self.position();
        self.tokens.push(Token {
            kind: TokenKind::Eof,
            origin: Origin {
                source: self.source_name.to_owned(),
                start: position.clone(),
                end: position,
            },
        });
    }

    fn skip_whitespace(&mut self) {
        while matches!(self.peek(), Some(' ' | '\t' | '\r' | '\n')) {
            self.advance();
        }
    }

    fn skip_comment(&mut self) {
        while !matches!(self.peek(), None | Some('\n')) {
            self.advance();
        }
    }

    fn identifier(&mut self) {
        let start = self.position();
        let start_byte = self.byte;
        while matches!(self.peek(), Some('a'..='z' | 'A'..='Z' | '0'..='9' | '_')) {
            self.advance();
        }
        let value = &self.text[start_byte..self.byte];
        let origin = self.origin_from(start);
        if value.len() > MAX_IDENTIFIER_BYTES {
            self.diagnostics.push(Diagnostic::error(
                "LEX_IDENTIFIER_TOO_LONG",
                format!("identifier exceeds {MAX_IDENTIFIER_BYTES} bytes"),
                Some(origin),
            ));
            return;
        }
        let kind = match value {
            "module" => TokenKind::Module,
            "version" => TokenKind::Version,
            "opaque" => TokenKind::Opaque,
            "record" => TokenKind::Record,
            "result" => TokenKind::Result,
            "ok" => TokenKind::Ok,
            "error" => TokenKind::Error,
            "effect" => TokenKind::Effect,
            "operation" => TokenKind::Operation,
            "fn" => TokenKind::Function,
            "task" => TokenKind::Task,
            "requires" => TokenKind::Requires,
            "perform" => TokenKind::Perform,
            "ensures" => TokenKind::Ensures,
            "let" => TokenKind::Let,
            "match" => TokenKind::Match,
            "true" => TokenKind::True,
            "false" => TokenKind::False,
            "Int" => TokenKind::IntType,
            "Bool" => TokenKind::BoolType,
            "String" => TokenKind::StringType,
            "Result" => TokenKind::ResultType,
            _ => TokenKind::Identifier(value.to_owned()),
        };
        self.tokens.push(Token { kind, origin });
    }

    fn integer(&mut self) {
        let start = self.position();
        let start_byte = self.byte;
        while matches!(self.peek(), Some('0'..='9')) {
            self.advance();
        }
        let text = &self.text[start_byte..self.byte];
        let origin = self.origin_from(start);
        match text.parse::<i64>() {
            Ok(value) => self.tokens.push(Token {
                kind: TokenKind::Integer(value),
                origin,
            }),
            Err(_) => self.diagnostics.push(Diagnostic::error(
                "LEX_INTEGER_OUT_OF_RANGE",
                "integer literal is outside the signed 64-bit range",
                Some(origin),
            )),
        }
    }

    fn string(&mut self) {
        let start = self.position();
        self.advance();
        let mut value = String::new();
        let mut terminated = false;
        while let Some(character) = self.peek() {
            match character {
                '"' => {
                    self.advance();
                    terminated = true;
                    break;
                }
                '\n' => break,
                '\\' => {
                    self.advance();
                    let escape_start = self.position();
                    match self.peek() {
                        Some('"') => {
                            self.advance();
                            value.push('"');
                        }
                        Some('\\') => {
                            self.advance();
                            value.push('\\');
                        }
                        Some('n') => {
                            self.advance();
                            value.push('\n');
                        }
                        Some('r') => {
                            self.advance();
                            value.push('\r');
                        }
                        Some('t') => {
                            self.advance();
                            value.push('\t');
                        }
                        Some(_) => {
                            self.advance();
                            self.diagnostics.push(Diagnostic::error(
                                "LEX_INVALID_ESCAPE",
                                "string escape must be one of \\\", \\\\, \\n, \\r, or \\t",
                                Some(self.origin_from(escape_start)),
                            ));
                        }
                        None => break,
                    }
                }
                _ => {
                    self.advance();
                    value.push(character);
                }
            }
        }
        let origin = self.origin_from(start);
        if terminated {
            self.tokens.push(Token {
                kind: TokenKind::String(value),
                origin,
            });
        } else {
            self.diagnostics.push(Diagnostic::error(
                "LEX_UNTERMINATED_STRING",
                "string literal is missing a closing quote",
                Some(origin),
            ));
        }
    }

    fn single(&mut self, kind: TokenKind) {
        let start = self.position();
        self.advance();
        self.tokens.push(Token {
            kind,
            origin: self.origin_from(start),
        });
    }

    fn compound(&mut self, second: char, compound: TokenKind, single: TokenKind) {
        let start = self.position();
        self.advance();
        let kind = if self.peek() == Some(second) {
            self.advance();
            compound
        } else {
            single
        };
        self.tokens.push(Token {
            kind,
            origin: self.origin_from(start),
        });
    }

    fn equal_or_arrow(&mut self) {
        let start = self.position();
        self.advance();
        let kind = match self.peek() {
            Some('=') => {
                self.advance();
                TokenKind::EqualEqual
            }
            Some('>') => {
                self.advance();
                TokenKind::FatArrow
            }
            _ => TokenKind::Equal,
        };
        self.tokens.push(Token {
            kind,
            origin: self.origin_from(start),
        });
    }

    fn required_compound(&mut self, second: char, kind: TokenKind, code: &str) {
        let start = self.position();
        self.advance();
        if self.peek() == Some(second) {
            self.advance();
            self.tokens.push(Token {
                kind,
                origin: self.origin_from(start),
            });
        } else {
            self.diagnostics.push(Diagnostic::error(
                code,
                format!("expected `{second}` after the preceding character"),
                Some(self.origin_from(start)),
            ));
        }
    }

    fn invalid_character(&mut self) {
        let start = self.position();
        let character = self.advance().expect("peeked character must exist");
        self.diagnostics.push(Diagnostic::error(
            "LEX_INVALID_CHARACTER",
            format!("character `{character}` is not part of A-Lang source"),
            Some(self.origin_from(start)),
        ));
    }

    fn peek(&self) -> Option<char> {
        self.text[self.byte..].chars().next()
    }

    fn peek_next(&self) -> Option<char> {
        let mut characters = self.text[self.byte..].chars();
        characters.next()?;
        characters.next()
    }

    fn advance(&mut self) -> Option<char> {
        let character = self.peek()?;
        self.byte += character.len_utf8();
        if character == '\n' {
            self.line += 1;
            self.column = 1;
        } else {
            self.column += 1;
        }
        Some(character)
    }

    fn position(&self) -> Position {
        Position {
            byte: u32::try_from(self.byte).unwrap_or(u32::MAX),
            line: self.line,
            column: self.column,
        }
    }

    fn origin_from(&self, start: Position) -> Origin {
        Origin {
            source: self.source_name.to_owned(),
            start,
            end: self.position(),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::{TokenKind, lex};

    #[test]
    fn frontend_lexer_tracks_utf8_byte_and_line_columns() {
        let (tokens, diagnostics) = lex("sample.alang", "module M {\n // π\n opaque Id;\n}");
        assert!(diagnostics.is_empty());
        assert_eq!(tokens[0].kind, TokenKind::Module);
        assert_eq!(tokens[0].origin.start.byte, 0);
        assert_eq!(tokens[2].origin.start.line, 1);
        assert_eq!(tokens[3].origin.start.line, 3);
        assert_eq!(tokens[3].origin.start.column, 2);
    }

    #[test]
    fn frontend_lexer_reports_multiple_independent_errors() {
        let (_tokens, diagnostics) = lex("bad.alang", "@ \"bad\\q\" #");
        let codes: Vec<_> = diagnostics.iter().map(|item| item.code.as_str()).collect();
        assert_eq!(
            codes,
            vec![
                "LEX_INVALID_CHARACTER",
                "LEX_INVALID_ESCAPE",
                "LEX_INVALID_CHARACTER"
            ]
        );
    }
}
