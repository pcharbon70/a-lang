use crate::diagnostic::{Diagnostic, sort_diagnostics};
use crate::source::{
    ConstraintAst, DeclarationAst, ExpressionAst, MAX_COLLECTION_LENGTH, MAX_IDENTIFIER_BYTES,
    MAX_NESTING_DEPTH, MAX_SOURCE_BYTES, ModuleAst, Origin, QualifiedName, RecordFieldAst,
    RequirementAst, SOURCE_VERSION, Spanned, TypeAst, TypeDeclarationAst,
};

/// Decode and validate a bounded canonical JSON source document.
///
/// # Errors
///
/// Returns deterministic diagnostics for size, JSON schema, version,
/// identifier, collection, nesting, or source-origin violations.
pub fn decode(source_name: &str, bytes: &[u8]) -> Result<ModuleAst, Vec<Diagnostic>> {
    if bytes.len() > MAX_SOURCE_BYTES {
        return Err(vec![Diagnostic::error(
            "JSON_SOURCE_TOO_LARGE",
            format!("canonical source exceeds {MAX_SOURCE_BYTES} bytes"),
            None,
        )]);
    }
    let module: ModuleAst = serde_json::from_slice(bytes).map_err(|error| {
        vec![Diagnostic::error(
            "JSON_SCHEMA_INVALID",
            format!("{source_name}:{}:{}: {error}", error.line(), error.column()),
            None,
        )]
    })?;
    let mut diagnostics = Vec::new();
    validate_module(&module, &mut diagnostics);
    sort_diagnostics(&mut diagnostics);
    if diagnostics.is_empty() {
        Ok(module)
    } else {
        Err(diagnostics)
    }
}

fn validate_module(module: &ModuleAst, diagnostics: &mut Vec<Diagnostic>) {
    if module.version != SOURCE_VERSION {
        diagnostics.push(Diagnostic::error(
            "SOURCE_VERSION_UNSUPPORTED",
            format!(
                "source version `{}` is unsupported; expected `{SOURCE_VERSION}`",
                module.version
            ),
            Some(module.origin.clone()),
        ));
    }
    validate_origin(&module.origin, diagnostics);
    validate_identifier(&module.name, diagnostics);
    validate_collection(
        module.declarations.len(),
        &module.origin,
        "module declarations",
        diagnostics,
    );
    for declaration in &module.declarations {
        validate_origin(&declaration.origin, diagnostics);
        validate_declaration(declaration, diagnostics);
    }
}

fn validate_declaration(declaration: &Spanned<DeclarationAst>, diagnostics: &mut Vec<Diagnostic>) {
    match &declaration.node {
        DeclarationAst::Type(TypeDeclarationAst::Opaque { name }) => {
            validate_identifier(name, diagnostics);
        }
        DeclarationAst::Type(TypeDeclarationAst::Record { name, fields }) => {
            validate_identifier(name, diagnostics);
            validate_collection(
                fields.len(),
                &declaration.origin,
                "record fields",
                diagnostics,
            );
            for field in fields {
                validate_origin(&field.origin, diagnostics);
                validate_identifier(&field.node.name, diagnostics);
                validate_type(&field.node.value_type, 0, diagnostics);
            }
        }
        DeclarationAst::Type(TypeDeclarationAst::Result { name, ok, error }) => {
            validate_identifier(name, diagnostics);
            validate_type(ok, 0, diagnostics);
            validate_type(error, 0, diagnostics);
        }
        DeclarationAst::Effect(effect) => {
            validate_identifier(&effect.name, diagnostics);
            validate_collection(
                effect.operations.len(),
                &declaration.origin,
                "effect operations",
                diagnostics,
            );
            for operation in &effect.operations {
                validate_origin(&operation.origin, diagnostics);
                validate_identifier(&operation.node.name, diagnostics);
                validate_parameters(&operation.node.parameters, &operation.origin, diagnostics);
                validate_type(&operation.node.result, 0, diagnostics);
            }
        }
        DeclarationAst::Function(function) => {
            validate_identifier(&function.name, diagnostics);
            validate_parameters(&function.parameters, &declaration.origin, diagnostics);
            validate_type(&function.result, 0, diagnostics);
            validate_expression(&function.body, 0, diagnostics);
        }
        DeclarationAst::Task(task) => {
            validate_identifier(&task.name, diagnostics);
            validate_parameters(&task.parameters, &declaration.origin, diagnostics);
            validate_type(&task.result, 0, diagnostics);
            validate_collection(
                task.effects.len(),
                &declaration.origin,
                "task effects",
                diagnostics,
            );
            for effect in &task.effects {
                validate_origin(&effect.origin, diagnostics);
                validate_qualified_name(&effect.node, &effect.origin, diagnostics);
            }
            validate_collection(
                task.requirements.len(),
                &declaration.origin,
                "task requirements",
                diagnostics,
            );
            for requirement in &task.requirements {
                validate_requirement(requirement, diagnostics);
            }
            validate_expression(&task.body, 0, diagnostics);
            validate_expression(&task.ensures, 0, diagnostics);
        }
    }
}

fn validate_parameters(
    parameters: &[Spanned<crate::source::ParameterAst>],
    parent: &Origin,
    diagnostics: &mut Vec<Diagnostic>,
) {
    validate_collection(parameters.len(), parent, "parameters", diagnostics);
    for parameter in parameters {
        validate_origin(&parameter.origin, diagnostics);
        validate_identifier(&parameter.node.name, diagnostics);
        validate_type(&parameter.node.value_type, 0, diagnostics);
    }
}

fn validate_type(value_type: &Spanned<TypeAst>, depth: usize, diagnostics: &mut Vec<Diagnostic>) {
    validate_origin(&value_type.origin, diagnostics);
    if !validate_depth(depth, &value_type.origin, diagnostics) {
        return;
    }
    match &value_type.node {
        TypeAst::Primitive { .. } => {}
        TypeAst::Named { name } => validate_identifier_value(name, &value_type.origin, diagnostics),
        TypeAst::Product { items } => {
            validate_collection(
                items.len(),
                &value_type.origin,
                "product types",
                diagnostics,
            );
            for item in items {
                validate_type(item, depth + 1, diagnostics);
            }
        }
        TypeAst::Result { ok, error } => {
            validate_type(ok, depth + 1, diagnostics);
            validate_type(error, depth + 1, diagnostics);
        }
    }
}

fn validate_requirement(requirement: &Spanned<RequirementAst>, diagnostics: &mut Vec<Diagnostic>) {
    validate_origin(&requirement.origin, diagnostics);
    validate_origin(&requirement.node.target.origin, diagnostics);
    validate_qualified_name(
        &requirement.node.target.node,
        &requirement.node.target.origin,
        diagnostics,
    );
    validate_collection(
        requirement.node.constraints.len(),
        &requirement.origin,
        "requirement constraints",
        diagnostics,
    );
    for constraint in &requirement.node.constraints {
        validate_origin(&constraint.origin, diagnostics);
        let key = match &constraint.node {
            ConstraintAst::EqualsString { key, .. }
            | ConstraintAst::EqualsInteger { key, .. }
            | ConstraintAst::Prefix { key, .. } => key,
        };
        validate_identifier_value(key, &constraint.origin, diagnostics);
    }
}

fn validate_expression(
    expression: &Spanned<ExpressionAst>,
    depth: usize,
    diagnostics: &mut Vec<Diagnostic>,
) {
    validate_origin(&expression.origin, diagnostics);
    if !validate_depth(depth, &expression.origin, diagnostics) {
        return;
    }
    match &expression.node {
        ExpressionAst::Integer { .. }
        | ExpressionAst::Boolean { .. }
        | ExpressionAst::String { .. } => {}
        ExpressionAst::Variable { name } => {
            validate_identifier_value(name, &expression.origin, diagnostics);
        }
        ExpressionAst::Record { type_name, fields } => {
            validate_identifier_value(type_name, &expression.origin, diagnostics);
            validate_collection(
                fields.len(),
                &expression.origin,
                "record values",
                diagnostics,
            );
            for field in fields {
                validate_record_field(field, depth + 1, diagnostics);
            }
        }
        ExpressionAst::Field { target, field } => {
            validate_identifier_value(field, &expression.origin, diagnostics);
            validate_expression(target, depth + 1, diagnostics);
        }
        ExpressionAst::Ok { value } | ExpressionAst::Error { value } => {
            validate_expression(value, depth + 1, diagnostics);
        }
        ExpressionAst::Call {
            function,
            arguments,
        } => {
            validate_identifier_value(function, &expression.origin, diagnostics);
            validate_collection(
                arguments.len(),
                &expression.origin,
                "call arguments",
                diagnostics,
            );
            for argument in arguments {
                validate_expression(argument, depth + 1, diagnostics);
            }
        }
        ExpressionAst::Let { name, value, body } => {
            validate_identifier(name, diagnostics);
            validate_expression(value, depth + 1, diagnostics);
            validate_expression(body, depth + 1, diagnostics);
        }
        ExpressionAst::MatchResult {
            value,
            ok_name,
            ok_body,
            error_name,
            error_body,
        } => {
            validate_expression(value, depth + 1, diagnostics);
            validate_identifier(ok_name, diagnostics);
            validate_expression(ok_body, depth + 1, diagnostics);
            validate_identifier(error_name, diagnostics);
            validate_expression(error_body, depth + 1, diagnostics);
        }
        ExpressionAst::Perform {
            operation,
            arguments,
        } => {
            validate_origin(&operation.origin, diagnostics);
            validate_qualified_name(&operation.node, &operation.origin, diagnostics);
            validate_collection(
                arguments.len(),
                &expression.origin,
                "operation arguments",
                diagnostics,
            );
            for argument in arguments {
                validate_expression(argument, depth + 1, diagnostics);
            }
        }
        ExpressionAst::Sequence { first, second }
        | ExpressionAst::Add {
            left: first,
            right: second,
        }
        | ExpressionAst::Equal {
            left: first,
            right: second,
        } => {
            validate_expression(first, depth + 1, diagnostics);
            validate_expression(second, depth + 1, diagnostics);
        }
    }
}

fn validate_record_field(
    field: &Spanned<RecordFieldAst>,
    depth: usize,
    diagnostics: &mut Vec<Diagnostic>,
) {
    validate_origin(&field.origin, diagnostics);
    validate_identifier(&field.node.name, diagnostics);
    validate_expression(&field.node.value, depth, diagnostics);
}

fn validate_identifier(value: &Spanned<String>, diagnostics: &mut Vec<Diagnostic>) {
    validate_origin(&value.origin, diagnostics);
    validate_identifier_value(&value.node, &value.origin, diagnostics);
}

fn validate_identifier_value(value: &str, origin: &Origin, diagnostics: &mut Vec<Diagnostic>) {
    let mut characters = value.chars();
    let valid = value.len() <= MAX_IDENTIFIER_BYTES
        && matches!(characters.next(), Some('a'..='z' | 'A'..='Z'))
        && characters.all(|character| character.is_ascii_alphanumeric() || character == '_');
    if !valid {
        diagnostics.push(Diagnostic::error(
            "SOURCE_IDENTIFIER_INVALID",
            format!("`{value}` is not a valid A-Lang identifier"),
            Some(origin.clone()),
        ));
    }
}

fn validate_qualified_name(
    name: &QualifiedName,
    origin: &Origin,
    diagnostics: &mut Vec<Diagnostic>,
) {
    validate_identifier_value(&name.namespace, origin, diagnostics);
    validate_identifier_value(&name.name, origin, diagnostics);
}

fn validate_origin(origin: &Origin, diagnostics: &mut Vec<Diagnostic>) {
    let valid_source = !origin.source.is_empty() && origin.source.len() <= 256;
    let valid_positions = origin.start.line > 0
        && origin.start.column > 0
        && origin.end.line > 0
        && origin.end.column > 0
        && origin.start.byte <= origin.end.byte
        && (origin.start.line, origin.start.column) <= (origin.end.line, origin.end.column);
    if !(valid_source && valid_positions) {
        diagnostics.push(Diagnostic::error(
            "SOURCE_ORIGIN_INVALID",
            "source origin must have a bounded source name and ordered one-based positions",
            Some(origin.clone()),
        ));
    }
}

fn validate_collection(
    length: usize,
    origin: &Origin,
    description: &str,
    diagnostics: &mut Vec<Diagnostic>,
) {
    if length > MAX_COLLECTION_LENGTH {
        diagnostics.push(Diagnostic::error(
            "SOURCE_COLLECTION_TOO_LARGE",
            format!("{description} exceeds {MAX_COLLECTION_LENGTH} elements"),
            Some(origin.clone()),
        ));
    }
}

fn validate_depth(depth: usize, origin: &Origin, diagnostics: &mut Vec<Diagnostic>) -> bool {
    if depth > MAX_NESTING_DEPTH {
        diagnostics.push(Diagnostic::error(
            "SOURCE_NESTING_TOO_DEEP",
            format!("source nesting exceeds {MAX_NESTING_DEPTH} levels"),
            Some(origin.clone()),
        ));
        false
    } else {
        true
    }
}

#[cfg(test)]
mod tests {
    use super::decode;
    use crate::source::{ModuleAst, Origin, Position, SOURCE_VERSION, Spanned};

    fn origin() -> Origin {
        Origin {
            source: "counter.alang".to_owned(),
            start: Position {
                byte: 0,
                line: 1,
                column: 1,
            },
            end: Position {
                byte: 8,
                line: 1,
                column: 9,
            },
        }
    }

    fn module() -> ModuleAst {
        ModuleAst {
            version: SOURCE_VERSION.to_owned(),
            name: Spanned::new("Counter".to_owned(), origin()),
            declarations: Vec::new(),
            origin: origin(),
        }
    }

    #[test]
    fn frontend_json_round_trips_the_canonical_ast() {
        let expected = module();
        let bytes = serde_json::to_vec(&expected).expect("AST must serialize");
        assert_eq!(decode("counter.json", &bytes), Ok(expected));
    }

    #[test]
    fn frontend_json_rejects_unknown_fields() {
        let mut value = serde_json::to_value(module()).expect("AST must serialize");
        value
            .as_object_mut()
            .expect("module is an object")
            .insert("unknown".to_owned(), serde_json::Value::Bool(true));
        let diagnostics = decode(
            "counter.json",
            &serde_json::to_vec(&value).expect("JSON must serialize"),
        )
        .expect_err("unknown fields must fail");
        assert_eq!(diagnostics[0].code, "JSON_SCHEMA_INVALID");
    }

    #[test]
    fn frontend_json_rejects_oversized_missing_and_unknown_tag_inputs() {
        let oversized = vec![b' '; crate::source::MAX_SOURCE_BYTES + 1];
        let size_diagnostics =
            decode("large.json", &oversized).expect_err("oversized JSON must fail");
        assert_eq!(size_diagnostics[0].code, "JSON_SOURCE_TOO_LARGE");

        let missing = decode("missing.json", b"{}").expect_err("missing fields must fail");
        assert_eq!(missing[0].code, "JSON_SCHEMA_INVALID");

        let mut value = serde_json::to_value(module()).expect("AST must serialize");
        value["declarations"] = serde_json::json!([{
            "kind": "future_declaration",
            "origin": origin()
        }]);
        let unknown_tag = decode(
            "tag.json",
            &serde_json::to_vec(&value).expect("JSON must serialize"),
        )
        .expect_err("unknown tags must fail");
        assert_eq!(unknown_tag[0].code, "JSON_SCHEMA_INVALID");
    }

    #[test]
    fn frontend_json_rejects_version_identifier_and_origin_violations() {
        let mut invalid = module();
        invalid.version = "alang-source-v2".to_owned();
        invalid.name.node = "not-valid!".to_owned();
        invalid.origin.start.line = 0;
        let bytes = serde_json::to_vec(&invalid).expect("AST must serialize");
        let diagnostics = decode("counter.json", &bytes).expect_err("invalid AST must fail");
        let codes: Vec<_> = diagnostics.iter().map(|item| item.code.as_str()).collect();
        assert!(codes.contains(&"SOURCE_VERSION_UNSUPPORTED"));
        assert!(codes.contains(&"SOURCE_IDENTIFIER_INVALID"));
        assert!(codes.contains(&"SOURCE_ORIGIN_INVALID"));
    }
}
