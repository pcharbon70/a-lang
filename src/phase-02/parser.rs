use crate::diagnostic::{Diagnostic, sort_diagnostics};
use crate::lexer::{Token, TokenKind, lex};
use crate::source::{
    ConstraintAst, DeclarationAst, EffectDeclarationAst, ExpressionAst, FieldDeclarationAst,
    FunctionDeclarationAst, MAX_COLLECTION_LENGTH, MAX_SOURCE_BYTES, ModuleAst,
    OperationDeclarationAst, Origin, ParameterAst, PrimitiveType, QualifiedName, RecordFieldAst,
    RequirementAst, SOURCE_VERSION, Spanned, TaskDeclarationAst, TypeAst, TypeDeclarationAst,
};
use std::mem::discriminant;

/// Parse a bounded native textual A-Lang module.
///
/// # Errors
///
/// Returns sorted lexical and syntactic diagnostics after declaration-level
/// recovery. A module with any error is never returned as accepted source.
pub fn parse(source_name: &str, text: &str) -> Result<ModuleAst, Vec<Diagnostic>> {
    if text.len() > MAX_SOURCE_BYTES {
        return Err(vec![Diagnostic::error(
            "TEXT_SOURCE_TOO_LARGE",
            format!("textual source exceeds {MAX_SOURCE_BYTES} bytes"),
            None,
        )]);
    }
    let (tokens, mut diagnostics) = lex(source_name, text);
    let mut parser = Parser::new(tokens);
    let module = parser.parse_module();
    diagnostics.append(&mut parser.diagnostics);
    sort_diagnostics(&mut diagnostics);
    match (module, diagnostics.is_empty()) {
        (Some(module), true) => Ok(module),
        (_, false) => Err(diagnostics),
        (None, true) => Err(vec![Diagnostic::error(
            "PARSE_MODULE_MISSING",
            "source did not contain an A-Lang module",
            None,
        )]),
    }
}

struct Parser {
    tokens: Vec<Token>,
    current: usize,
    diagnostics: Vec<Diagnostic>,
}

impl Parser {
    fn new(tokens: Vec<Token>) -> Self {
        Self {
            tokens,
            current: 0,
            diagnostics: Vec::new(),
        }
    }

    fn parse_module(&mut self) -> Option<ModuleAst> {
        let start = self.expect(TokenKind::Module, "`module`")?;
        let name = self.identifier("module name")?;
        self.expect(TokenKind::Version, "`version`")?;
        let version = self.string_literal("source version")?;
        if version.node != SOURCE_VERSION {
            self.diagnostics.push(Diagnostic::error(
                "SOURCE_VERSION_UNSUPPORTED",
                format!(
                    "source version `{}` is unsupported; expected `{SOURCE_VERSION}`",
                    version.node
                ),
                Some(version.origin.clone()),
            ));
        }
        self.expect(TokenKind::LeftBrace, "`{` after module header")?;
        let mut declarations = Vec::new();
        while !self.check(&TokenKind::RightBrace) && !self.check(&TokenKind::Eof) {
            if declarations.len() >= MAX_COLLECTION_LENGTH {
                self.diagnostics.push(Diagnostic::error(
                    "PARSE_COLLECTION_TOO_LARGE",
                    format!("module exceeds {MAX_COLLECTION_LENGTH} declarations"),
                    Some(self.peek().origin.clone()),
                ));
                self.synchronize_declaration();
                continue;
            }
            match self.parse_declaration() {
                Some(declaration) => declarations.push(declaration),
                None => self.synchronize_declaration(),
            }
        }
        let end = self.expect(TokenKind::RightBrace, "`}` after module declarations")?;
        if !self.check(&TokenKind::Eof) {
            self.diagnostics.push(Diagnostic::error(
                "PARSE_TRAILING_TOKENS",
                "tokens after the module closing brace are not allowed",
                Some(self.peek().origin.clone()),
            ));
        }
        Some(ModuleAst {
            version: version.node,
            name,
            declarations,
            origin: Origin::merge(&start.origin, &end.origin),
        })
    }

    fn parse_declaration(&mut self) -> Option<Spanned<DeclarationAst>> {
        match &self.peek().kind {
            TokenKind::Opaque => self.parse_opaque(),
            TokenKind::Record => self.parse_record(),
            TokenKind::Result => self.parse_result(),
            TokenKind::Effect => self.parse_effect(),
            TokenKind::Function => self.parse_function(),
            TokenKind::Task => self.parse_task(),
            _ => {
                self.diagnostics.push(Diagnostic::error(
                    "PARSE_EXPECTED_DECLARATION",
                    "expected `opaque`, `record`, `result`, `effect`, `fn`, or `task`",
                    Some(self.peek().origin.clone()),
                ));
                None
            }
        }
    }

    fn parse_opaque(&mut self) -> Option<Spanned<DeclarationAst>> {
        let start = self.advance();
        let name = self.identifier("opaque type name")?;
        let end = self.expect(TokenKind::Semicolon, "`;` after opaque declaration")?;
        Some(Spanned::new(
            DeclarationAst::Type(TypeDeclarationAst::Opaque { name }),
            Origin::merge(&start.origin, &end.origin),
        ))
    }

    fn parse_record(&mut self) -> Option<Spanned<DeclarationAst>> {
        let start = self.advance();
        let name = self.identifier("record type name")?;
        self.expect(TokenKind::LeftBrace, "`{` after record name")?;
        let mut fields = Vec::new();
        while !self.check(&TokenKind::RightBrace) && !self.check(&TokenKind::Eof) {
            let field_start = self.peek().origin.clone();
            let field_name = self.identifier("record field name")?;
            self.expect(TokenKind::Colon, "`:` after record field name")?;
            let value_type = self.parse_type()?;
            let field_origin = Origin::merge(&field_start, &value_type.origin);
            fields.push(Spanned::new(
                FieldDeclarationAst {
                    name: field_name,
                    value_type,
                },
                field_origin,
            ));
            if self.take(&TokenKind::Comma).is_none() && !self.check(&TokenKind::RightBrace) {
                self.expected("`,` or `}` after record field");
                return None;
            }
        }
        let end = self.expect(TokenKind::RightBrace, "`}` after record fields")?;
        Some(Spanned::new(
            DeclarationAst::Type(TypeDeclarationAst::Record { name, fields }),
            Origin::merge(&start.origin, &end.origin),
        ))
    }

    fn parse_result(&mut self) -> Option<Spanned<DeclarationAst>> {
        let start = self.advance();
        let name = self.identifier("result type name")?;
        self.expect(TokenKind::Equal, "`=` after result type name")?;
        self.expect(TokenKind::Ok, "`ok` result alternative")?;
        let ok = self.parse_type()?;
        self.expect(TokenKind::Pipe, "`|` between result alternatives")?;
        self.expect(TokenKind::Error, "`error` result alternative")?;
        let error = self.parse_type()?;
        let end = self.expect(TokenKind::Semicolon, "`;` after result declaration")?;
        Some(Spanned::new(
            DeclarationAst::Type(TypeDeclarationAst::Result { name, ok, error }),
            Origin::merge(&start.origin, &end.origin),
        ))
    }

    fn parse_effect(&mut self) -> Option<Spanned<DeclarationAst>> {
        let start = self.advance();
        let name = self.identifier("effect name")?;
        self.expect(TokenKind::LeftBrace, "`{` after effect name")?;
        let mut operations = Vec::new();
        while !self.check(&TokenKind::RightBrace) && !self.check(&TokenKind::Eof) {
            let operation_start = self.expect(TokenKind::Operation, "`operation`")?;
            let operation_name = self.identifier("operation name")?;
            let parameters = self.parse_parameters()?;
            self.expect(TokenKind::Arrow, "`->` before operation result")?;
            let result = self.parse_type()?;
            let operation_end =
                self.expect(TokenKind::Semicolon, "`;` after operation declaration")?;
            operations.push(Spanned::new(
                OperationDeclarationAst {
                    name: operation_name,
                    parameters,
                    result,
                },
                Origin::merge(&operation_start.origin, &operation_end.origin),
            ));
        }
        let end = self.expect(TokenKind::RightBrace, "`}` after effect operations")?;
        Some(Spanned::new(
            DeclarationAst::Effect(EffectDeclarationAst { name, operations }),
            Origin::merge(&start.origin, &end.origin),
        ))
    }

    fn parse_function(&mut self) -> Option<Spanned<DeclarationAst>> {
        let start = self.advance();
        let name = self.identifier("function name")?;
        let parameters = self.parse_parameters()?;
        self.expect(TokenKind::Arrow, "`->` before function result")?;
        let result = self.parse_type()?;
        self.expect(TokenKind::Equal, "`=` before function body")?;
        let body = self.parse_expression()?;
        let end = self.expect(TokenKind::Semicolon, "`;` after function body")?;
        Some(Spanned::new(
            DeclarationAst::Function(FunctionDeclarationAst {
                name,
                parameters,
                result,
                body,
            }),
            Origin::merge(&start.origin, &end.origin),
        ))
    }

    fn parse_task(&mut self) -> Option<Spanned<DeclarationAst>> {
        let start = self.advance();
        let name = self.identifier("task name")?;
        let parameters = self.parse_parameters()?;
        self.expect(TokenKind::Arrow, "`->` before task result")?;
        let result = self.parse_type()?;
        self.expect(TokenKind::Effect, "`effect` before task effect set")?;
        let effects = self.parse_qualified_list()?;
        self.expect(TokenKind::Requires, "`requires` before task requirements")?;
        let requirements = self.parse_requirement_list()?;
        self.expect(TokenKind::Equal, "`=` before task body")?;
        let body = self.parse_expression()?;
        self.expect(TokenKind::Ensures, "`ensures` before completion predicate")?;
        let ensures = self.parse_expression()?;
        let end = self.expect(TokenKind::Semicolon, "`;` after task declaration")?;
        Some(Spanned::new(
            DeclarationAst::Task(Box::new(TaskDeclarationAst {
                name,
                parameters,
                result,
                effects,
                requirements,
                body,
                ensures,
            })),
            Origin::merge(&start.origin, &end.origin),
        ))
    }

    fn parse_parameters(&mut self) -> Option<Vec<Spanned<ParameterAst>>> {
        self.expect(TokenKind::LeftParen, "`(` before parameters")?;
        let mut parameters = Vec::new();
        while !self.check(&TokenKind::RightParen) && !self.check(&TokenKind::Eof) {
            let start = self.peek().origin.clone();
            let name = self.identifier("parameter name")?;
            self.expect(TokenKind::Colon, "`:` after parameter name")?;
            let value_type = self.parse_type()?;
            let origin = Origin::merge(&start, &value_type.origin);
            parameters.push(Spanned::new(ParameterAst { name, value_type }, origin));
            if self.take(&TokenKind::Comma).is_none() {
                break;
            }
        }
        self.expect(TokenKind::RightParen, "`)` after parameters")?;
        Some(parameters)
    }

    fn parse_type(&mut self) -> Option<Spanned<TypeAst>> {
        let token = self.advance();
        match token.kind {
            TokenKind::IntType => Some(Spanned::new(
                TypeAst::Primitive {
                    name: PrimitiveType::Int,
                },
                token.origin,
            )),
            TokenKind::BoolType => Some(Spanned::new(
                TypeAst::Primitive {
                    name: PrimitiveType::Bool,
                },
                token.origin,
            )),
            TokenKind::StringType => Some(Spanned::new(
                TypeAst::Primitive {
                    name: PrimitiveType::String,
                },
                token.origin,
            )),
            TokenKind::Identifier(name) => {
                Some(Spanned::new(TypeAst::Named { name }, token.origin))
            }
            TokenKind::ResultType => {
                self.expect(TokenKind::Less, "`<` after `Result`")?;
                let ok = self.parse_type()?;
                self.expect(TokenKind::Comma, "`,` between result types")?;
                let error = self.parse_type()?;
                let end = self.expect(TokenKind::Greater, "`>` after result types")?;
                Some(Spanned::new(
                    TypeAst::Result {
                        ok: Box::new(ok),
                        error: Box::new(error),
                    },
                    Origin::merge(&token.origin, &end.origin),
                ))
            }
            TokenKind::LeftParen => {
                let first = self.parse_type()?;
                self.expect(TokenKind::Comma, "`,` in product type")?;
                let mut items = vec![first];
                loop {
                    items.push(self.parse_type()?);
                    if self.take(&TokenKind::Comma).is_none() {
                        break;
                    }
                }
                let end = self.expect(TokenKind::RightParen, "`)` after product type")?;
                Some(Spanned::new(
                    TypeAst::Product { items },
                    Origin::merge(&token.origin, &end.origin),
                ))
            }
            _ => {
                self.diagnostics.push(Diagnostic::error(
                    "PARSE_EXPECTED_TYPE",
                    "expected a primitive, named, product, or result type",
                    Some(token.origin),
                ));
                None
            }
        }
    }

    fn parse_qualified_list(&mut self) -> Option<Vec<Spanned<QualifiedName>>> {
        self.expect(TokenKind::LeftBracket, "`[` before effect set")?;
        let mut names = Vec::new();
        while !self.check(&TokenKind::RightBracket) && !self.check(&TokenKind::Eof) {
            names.push(self.parse_qualified_name()?);
            if self.take(&TokenKind::Comma).is_none() {
                break;
            }
        }
        self.expect(TokenKind::RightBracket, "`]` after effect set")?;
        Some(names)
    }

    fn parse_requirement_list(&mut self) -> Option<Vec<Spanned<RequirementAst>>> {
        self.expect(TokenKind::LeftBracket, "`[` before requirements")?;
        let mut requirements = Vec::new();
        while !self.check(&TokenKind::RightBracket) && !self.check(&TokenKind::Eof) {
            requirements.push(self.parse_requirement()?);
            if self.take(&TokenKind::Comma).is_none() {
                break;
            }
        }
        self.expect(TokenKind::RightBracket, "`]` after requirements")?;
        Some(requirements)
    }

    fn parse_requirement(&mut self) -> Option<Spanned<RequirementAst>> {
        let target = self.parse_qualified_name()?;
        self.expect(TokenKind::LeftParen, "`(` before requirement constraints")?;
        let mut constraints = Vec::new();
        let mut deadline_ms = None;
        let mut max_calls = None;
        let mut max_bytes = None;
        while !self.check(&TokenKind::RightParen) && !self.check(&TokenKind::Eof) {
            let key = self.identifier("requirement constraint name")?;
            self.expect(TokenKind::Equal, "`=` after requirement constraint name")?;
            let value = self.advance();
            let value_origin = Origin::merge(&key.origin, &value.origin);
            match (key.node.as_str(), value.kind) {
                ("deadline_ms", TokenKind::Integer(value)) => {
                    deadline_ms = u64::try_from(value).ok();
                }
                ("max_calls", TokenKind::Integer(value)) => {
                    max_calls = u32::try_from(value).ok();
                }
                ("max_bytes", TokenKind::Integer(value)) => {
                    max_bytes = u64::try_from(value).ok();
                }
                (name, TokenKind::String(value)) if name.ends_with("_prefix") => {
                    constraints.push(Spanned::new(
                        ConstraintAst::Prefix {
                            key: name.to_owned(),
                            value,
                        },
                        value_origin,
                    ));
                }
                (name, TokenKind::String(value)) => {
                    constraints.push(Spanned::new(
                        ConstraintAst::EqualsString {
                            key: name.to_owned(),
                            value,
                        },
                        value_origin,
                    ));
                }
                (name, TokenKind::Integer(value)) => {
                    constraints.push(Spanned::new(
                        ConstraintAst::EqualsInteger {
                            key: name.to_owned(),
                            value,
                        },
                        value_origin,
                    ));
                }
                _ => {
                    self.diagnostics.push(Diagnostic::error(
                        "PARSE_REQUIREMENT_VALUE_INVALID",
                        "requirement values must be integer or string literals",
                        Some(value_origin),
                    ));
                    return None;
                }
            }
            if self.take(&TokenKind::Comma).is_none() {
                break;
            }
        }
        let end = self.expect(TokenKind::RightParen, "`)` after requirement constraints")?;
        Some(Spanned::new(
            RequirementAst {
                target: target.clone(),
                constraints,
                deadline_ms,
                max_calls,
                max_bytes,
            },
            Origin::merge(&target.origin, &end.origin),
        ))
    }

    fn parse_expression(&mut self) -> Option<Spanned<ExpressionAst>> {
        self.parse_sequence()
    }

    fn parse_sequence(&mut self) -> Option<Spanned<ExpressionAst>> {
        let mut expression = self.parse_equality()?;
        while self.take(&TokenKind::Sequence).is_some() {
            let right = self.parse_equality()?;
            let origin = Origin::merge(&expression.origin, &right.origin);
            expression = Spanned::new(
                ExpressionAst::Sequence {
                    first: Box::new(expression),
                    second: Box::new(right),
                },
                origin,
            );
        }
        Some(expression)
    }

    fn parse_equality(&mut self) -> Option<Spanned<ExpressionAst>> {
        let mut expression = self.parse_addition()?;
        while self.take(&TokenKind::EqualEqual).is_some() {
            let right = self.parse_addition()?;
            let origin = Origin::merge(&expression.origin, &right.origin);
            expression = Spanned::new(
                ExpressionAst::Equal {
                    left: Box::new(expression),
                    right: Box::new(right),
                },
                origin,
            );
        }
        Some(expression)
    }

    fn parse_addition(&mut self) -> Option<Spanned<ExpressionAst>> {
        let mut expression = self.parse_postfix()?;
        while self.take(&TokenKind::Plus).is_some() {
            let right = self.parse_postfix()?;
            let origin = Origin::merge(&expression.origin, &right.origin);
            expression = Spanned::new(
                ExpressionAst::Add {
                    left: Box::new(expression),
                    right: Box::new(right),
                },
                origin,
            );
        }
        Some(expression)
    }

    fn parse_postfix(&mut self) -> Option<Spanned<ExpressionAst>> {
        let mut expression = self.parse_primary()?;
        while self.take(&TokenKind::Dot).is_some() {
            let field = self.identifier("field name")?;
            let origin = Origin::merge(&expression.origin, &field.origin);
            expression = Spanned::new(
                ExpressionAst::Field {
                    target: Box::new(expression),
                    field: field.node,
                },
                origin,
            );
        }
        Some(expression)
    }

    fn parse_primary(&mut self) -> Option<Spanned<ExpressionAst>> {
        let token = self.advance();
        match token.kind {
            TokenKind::Integer(value) => {
                Some(Spanned::new(ExpressionAst::Integer { value }, token.origin))
            }
            TokenKind::String(value) => {
                Some(Spanned::new(ExpressionAst::String { value }, token.origin))
            }
            TokenKind::True => Some(Spanned::new(
                ExpressionAst::Boolean { value: true },
                token.origin,
            )),
            TokenKind::False => Some(Spanned::new(
                ExpressionAst::Boolean { value: false },
                token.origin,
            )),
            TokenKind::Identifier(name) => self.parse_identifier_expression(&token.origin, name),
            TokenKind::Ok => self.parse_result_constructor(&token.origin, true),
            TokenKind::Error => self.parse_result_constructor(&token.origin, false),
            TokenKind::Let => self.parse_let(&token.origin),
            TokenKind::Match => self.parse_match(&token.origin),
            TokenKind::Perform => self.parse_perform(&token.origin),
            TokenKind::LeftParen => {
                let mut expression = self.parse_expression()?;
                let end = self.expect(TokenKind::RightParen, "`)` after expression")?;
                expression.origin = Origin::merge(&token.origin, &end.origin);
                Some(expression)
            }
            _ => {
                self.diagnostics.push(Diagnostic::error(
                    "PARSE_EXPECTED_EXPRESSION",
                    "expected an A-Lang expression",
                    Some(token.origin),
                ));
                None
            }
        }
    }

    fn parse_identifier_expression(
        &mut self,
        start: &Origin,
        name: String,
    ) -> Option<Spanned<ExpressionAst>> {
        if self.take(&TokenKind::LeftParen).is_some() {
            let (arguments, end) = self.parse_arguments_after_open()?;
            return Some(Spanned::new(
                ExpressionAst::Call {
                    function: name,
                    arguments,
                },
                Origin::merge(start, &end.origin),
            ));
        }
        if name.chars().next().is_some_and(char::is_uppercase)
            && self.take(&TokenKind::LeftBrace).is_some()
        {
            let (fields, end) = self.parse_record_fields_after_open()?;
            return Some(Spanned::new(
                ExpressionAst::Record {
                    type_name: name,
                    fields,
                },
                Origin::merge(start, &end.origin),
            ));
        }
        Some(Spanned::new(
            ExpressionAst::Variable { name },
            start.clone(),
        ))
    }

    fn parse_result_constructor(
        &mut self,
        start: &Origin,
        is_ok: bool,
    ) -> Option<Spanned<ExpressionAst>> {
        self.expect(TokenKind::LeftParen, "`(` after result constructor")?;
        let value = self.parse_expression()?;
        let end = self.expect(TokenKind::RightParen, "`)` after result value")?;
        let node = if is_ok {
            ExpressionAst::Ok {
                value: Box::new(value),
            }
        } else {
            ExpressionAst::Error {
                value: Box::new(value),
            }
        };
        Some(Spanned::new(node, Origin::merge(start, &end.origin)))
    }

    fn parse_let(&mut self, start: &Origin) -> Option<Spanned<ExpressionAst>> {
        let name = self.identifier("let binding")?;
        self.expect(TokenKind::Equal, "`=` after let binding")?;
        let value = self.parse_expression()?;
        self.expect(TokenKind::Semicolon, "`;` after let value")?;
        let body = self.parse_expression()?;
        let origin = Origin::merge(start, &body.origin);
        Some(Spanned::new(
            ExpressionAst::Let {
                name,
                value: Box::new(value),
                body: Box::new(body),
            },
            origin,
        ))
    }

    fn parse_match(&mut self, start: &Origin) -> Option<Spanned<ExpressionAst>> {
        let value = self.parse_expression()?;
        self.expect(TokenKind::LeftBrace, "`{` before match arms")?;
        self.expect(TokenKind::Ok, "`ok` match arm")?;
        self.expect(TokenKind::LeftParen, "`(` before ok binding")?;
        let ok_name = self.identifier("ok binding")?;
        self.expect(TokenKind::RightParen, "`)` after ok binding")?;
        self.expect(TokenKind::FatArrow, "`=>` before ok arm body")?;
        let ok_body = self.parse_expression()?;
        self.expect(TokenKind::Comma, "`,` between match arms")?;
        self.expect(TokenKind::Error, "`error` match arm")?;
        self.expect(TokenKind::LeftParen, "`(` before error binding")?;
        let error_name = self.identifier("error binding")?;
        self.expect(TokenKind::RightParen, "`)` after error binding")?;
        self.expect(TokenKind::FatArrow, "`=>` before error arm body")?;
        let error_body = self.parse_expression()?;
        self.take(&TokenKind::Comma);
        let end = self.expect(TokenKind::RightBrace, "`}` after match arms")?;
        Some(Spanned::new(
            ExpressionAst::MatchResult {
                value: Box::new(value),
                ok_name,
                ok_body: Box::new(ok_body),
                error_name,
                error_body: Box::new(error_body),
            },
            Origin::merge(start, &end.origin),
        ))
    }

    fn parse_perform(&mut self, start: &Origin) -> Option<Spanned<ExpressionAst>> {
        let operation = self.parse_qualified_name()?;
        self.expect(TokenKind::LeftParen, "`(` before operation arguments")?;
        let (arguments, end) = self.parse_arguments_after_open()?;
        Some(Spanned::new(
            ExpressionAst::Perform {
                operation,
                arguments,
            },
            Origin::merge(start, &end.origin),
        ))
    }

    fn parse_arguments_after_open(&mut self) -> Option<(Vec<Spanned<ExpressionAst>>, Token)> {
        let mut arguments = Vec::new();
        while !self.check(&TokenKind::RightParen) && !self.check(&TokenKind::Eof) {
            arguments.push(self.parse_expression()?);
            if self.take(&TokenKind::Comma).is_none() {
                break;
            }
        }
        let end = self.expect(TokenKind::RightParen, "`)` after arguments")?;
        Some((arguments, end))
    }

    fn parse_record_fields_after_open(&mut self) -> Option<(Vec<Spanned<RecordFieldAst>>, Token)> {
        let mut fields = Vec::new();
        while !self.check(&TokenKind::RightBrace) && !self.check(&TokenKind::Eof) {
            let name = self.identifier("record field name")?;
            self.expect(TokenKind::Colon, "`:` after record field name")?;
            let value = self.parse_expression()?;
            let origin = Origin::merge(&name.origin, &value.origin);
            fields.push(Spanned::new(RecordFieldAst { name, value }, origin));
            if self.take(&TokenKind::Comma).is_none() {
                break;
            }
        }
        let end = self.expect(TokenKind::RightBrace, "`}` after record fields")?;
        Some((fields, end))
    }

    fn parse_qualified_name(&mut self) -> Option<Spanned<QualifiedName>> {
        let namespace = self.identifier("qualified namespace")?;
        self.expect(TokenKind::Dot, "`.` in qualified name")?;
        let name = self.identifier("qualified operation")?;
        let origin = Origin::merge(&namespace.origin, &name.origin);
        Some(Spanned::new(
            QualifiedName {
                namespace: namespace.node,
                name: name.node,
            },
            origin,
        ))
    }

    fn identifier(&mut self, description: &str) -> Option<Spanned<String>> {
        let token = self.advance();
        if let TokenKind::Identifier(value) = token.kind {
            Some(Spanned::new(value, token.origin))
        } else {
            self.diagnostics.push(Diagnostic::error(
                "PARSE_EXPECTED_IDENTIFIER",
                format!("expected {description}"),
                Some(token.origin),
            ));
            None
        }
    }

    fn string_literal(&mut self, description: &str) -> Option<Spanned<String>> {
        let token = self.advance();
        if let TokenKind::String(value) = token.kind {
            Some(Spanned::new(value, token.origin))
        } else {
            self.diagnostics.push(Diagnostic::error(
                "PARSE_EXPECTED_STRING",
                format!("expected {description}"),
                Some(token.origin),
            ));
            None
        }
    }

    fn synchronize_declaration(&mut self) {
        while !self.check(&TokenKind::Eof) && !self.check(&TokenKind::RightBrace) {
            if self.is_declaration_start() {
                return;
            }
            if self.take(&TokenKind::Semicolon).is_some() {
                return;
            }
            self.advance();
        }
    }

    fn is_declaration_start(&self) -> bool {
        matches!(
            self.peek().kind,
            TokenKind::Opaque
                | TokenKind::Record
                | TokenKind::Result
                | TokenKind::Effect
                | TokenKind::Function
                | TokenKind::Task
        )
    }

    #[allow(clippy::needless_pass_by_value)]
    fn expect(&mut self, kind: TokenKind, description: &str) -> Option<Token> {
        if self.check(&kind) {
            Some(self.advance())
        } else {
            self.expected(description);
            None
        }
    }

    fn expected(&mut self, description: &str) {
        self.diagnostics.push(Diagnostic::error(
            "PARSE_EXPECTED_TOKEN",
            format!("expected {description}"),
            Some(self.peek().origin.clone()),
        ));
    }

    fn take(&mut self, kind: &TokenKind) -> Option<Token> {
        if self.check(kind) {
            Some(self.advance())
        } else {
            None
        }
    }

    fn check(&self, kind: &TokenKind) -> bool {
        discriminant(&self.peek().kind) == discriminant(kind)
    }

    fn advance(&mut self) -> Token {
        let token = self.peek().clone();
        if !matches!(token.kind, TokenKind::Eof) {
            self.current += 1;
        }
        token
    }

    fn peek(&self) -> &Token {
        &self.tokens[self.current]
    }
}

#[cfg(test)]
mod tests {
    use super::parse;
    use crate::json_frontend::decode;
    use crate::source::{DeclarationAst, ExpressionAst};

    const FULL_SOURCE: &str = r#"
module Demo version "alang-source-v1" {
  opaque ModelId;
  record Prompt { text: String, }
  result Completion = ok String | error String;
  effect Model {
    operation complete(prompt: String) -> String;
  }
  fn increment(value: Int) -> Int = value + 1;
  task run(value: Int) -> Int
    effect [Model.complete]
    requires [Model.complete(model = "fixture", max_calls = 1, max_bytes = 4096, deadline_ms = 5000)]
    = let successor = increment(value); successor >> successor
    ensures true;
}
"#;

    #[test]
    fn frontend_text_parses_the_complete_declared_surface() {
        let module = parse("demo.alang", FULL_SOURCE).expect("complete source must parse");
        assert_eq!(module.name.node, "Demo");
        assert_eq!(module.declarations.len(), 6);
        let task = match &module.declarations[5].node {
            DeclarationAst::Task(task) => task,
            other => panic!("expected task, got {other:?}"),
        };
        assert_eq!(task.effects[0].node.namespace, "Model");
        assert_eq!(task.requirements[0].node.max_calls, Some(1));
        assert!(matches!(task.body.node, ExpressionAst::Let { .. }));
    }

    #[test]
    fn frontend_text_and_json_converge_on_the_same_ast() {
        let textual = parse("demo.alang", FULL_SOURCE).expect("text must parse");
        let bytes = serde_json::to_vec(&textual).expect("AST must serialize");
        let canonical = decode("demo.json", &bytes).expect("canonical JSON must decode");
        assert_eq!(textual, canonical);
    }

    #[test]
    fn frontend_parser_recovers_multiple_declaration_diagnostics() {
        let source = r#"
module Broken version "alang-source-v1" {
  opaque ;
  fn first(value Int) -> Int = value;
  task second() -> Int effect [] requires [] = 1;
}
"#;
        let diagnostics = parse("broken.alang", source).expect_err("bad source must fail");
        assert!(diagnostics.len() >= 3, "{diagnostics:#?}");
        assert!(
            diagnostics
                .iter()
                .all(|diagnostic| diagnostic.origin.is_some())
        );
    }

    #[test]
    fn frontend_precedence_is_addition_then_equality_then_sequence() {
        let source = r#"
module P version "alang-source-v1" {
  fn f(a: Int, b: Int) -> Bool = a + 1 == b >> true;
}
"#;
        let module = parse("precedence.alang", source).expect("source must parse");
        let function = match &module.declarations[0].node {
            DeclarationAst::Function(function) => function,
            other => panic!("expected function, got {other:?}"),
        };
        assert!(matches!(function.body.node, ExpressionAst::Sequence { .. }));
    }

    #[test]
    fn frontend_text_parses_records_results_matches_and_performs() {
        let source = r#"
module Views version "alang-source-v1" {
  record Prompt { text: String }
  effect Model { operation complete(prompt: String) -> String; }
  fn field() -> String = Prompt { text: "hello" }.text;
  task complete(prompt: String) -> String
    effect [Model.complete]
    requires [Model.complete(model = "fixture", max_calls = 1)]
    = perform Model.complete(prompt)
    ensures match ok(true) { ok(valid) => valid, error(reason) => false };
}
"#;
        let module = parse("views.alang", source).expect("focused source must parse");
        let function = match &module.declarations[2].node {
            DeclarationAst::Function(function) => function,
            other => panic!("expected function, got {other:?}"),
        };
        assert!(matches!(function.body.node, ExpressionAst::Field { .. }));
        let task = match &module.declarations[3].node {
            DeclarationAst::Task(task) => task,
            other => panic!("expected task, got {other:?}"),
        };
        assert!(matches!(task.body.node, ExpressionAst::Perform { .. }));
        assert!(matches!(
            task.ensures.node,
            ExpressionAst::MatchResult { .. }
        ));
    }
}
