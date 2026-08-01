use crate::diagnostic::{Diagnostic, sort_diagnostics};
use crate::semantic::{
    CheckedModule, Definition, OriginKey, RecordShape, ResolvedModule, ResultShape, Signature,
    SymbolId, SymbolKind, TypeEnvironment, ValueType, canonical_operation_id,
};
use crate::source::{
    DeclarationAst, ExpressionAst, Origin, PrimitiveType, Spanned, TypeAst, TypeDeclarationAst,
};
use std::collections::{BTreeMap, BTreeSet};

/// Check ordinary monomorphic data types after successful resolution.
///
/// # Errors
///
/// Returns source-oriented diagnostics for type mismatches, invalid records or
/// fields, impossible result constructors or matches, and opaque inspection or
/// construction attempts.
pub fn check(mut resolved: ResolvedModule) -> Result<CheckedModule, Vec<Diagnostic>> {
    let (signatures, records, results, opaque_types, expression_types, field_uses, mut diagnostics) = {
        let mut checker = TypeChecker::new(&resolved);
        checker.build_type_declarations();
        checker.build_signatures();
        checker.check_bodies();
        (
            checker.signatures,
            checker.records,
            checker.results,
            checker.opaque_types,
            checker.expression_types,
            checker.field_uses,
            checker.diagnostics,
        )
    };
    sort_diagnostics(&mut diagnostics);
    if diagnostics.is_empty() {
        resolved.symbols.uses.extend(field_uses);
        Ok(CheckedModule {
            ast: resolved.ast,
            symbols: resolved.symbols,
            types: TypeEnvironment {
                signatures,
                records,
                results,
                opaque_types: opaque_types.into_iter().collect(),
                expression_types,
            },
        })
    } else {
        Err(diagnostics)
    }
}

struct TypeChecker<'a> {
    resolved: &'a ResolvedModule,
    signatures: BTreeMap<SymbolId, Signature>,
    records: BTreeMap<SymbolId, RecordShape>,
    results: BTreeMap<SymbolId, ResultShape>,
    opaque_types: BTreeSet<SymbolId>,
    expression_types: BTreeMap<OriginKey, ValueType>,
    field_uses: BTreeMap<OriginKey, SymbolId>,
    local_types: BTreeMap<SymbolId, ValueType>,
    diagnostics: Vec<Diagnostic>,
}

impl<'a> TypeChecker<'a> {
    fn new(resolved: &'a ResolvedModule) -> Self {
        Self {
            resolved,
            signatures: BTreeMap::new(),
            records: BTreeMap::new(),
            results: BTreeMap::new(),
            opaque_types: BTreeSet::new(),
            expression_types: BTreeMap::new(),
            field_uses: BTreeMap::new(),
            local_types: BTreeMap::new(),
            diagnostics: Vec::new(),
        }
    }

    fn build_type_declarations(&mut self) {
        for declaration in &self.resolved.ast.declarations {
            let DeclarationAst::Type(type_declaration) = &declaration.node else {
                continue;
            };
            let name = match type_declaration {
                TypeDeclarationAst::Opaque { name }
                | TypeDeclarationAst::Record { name, .. }
                | TypeDeclarationAst::Result { name, .. } => name,
            };
            let Some(type_id) = self.definition_id(&name.origin, SymbolKind::Type) else {
                continue;
            };
            match type_declaration {
                TypeDeclarationAst::Opaque { .. } => {
                    self.opaque_types.insert(type_id);
                }
                TypeDeclarationAst::Record { fields, .. } => {
                    let mut shape = BTreeMap::new();
                    for field in fields {
                        let Some(value_type) = self.lower_type(&field.node.value_type) else {
                            continue;
                        };
                        let field_id =
                            SymbolId(format!("field:{}.{}", type_id.0, field.node.name.node));
                        shape.insert(field.node.name.node.clone(), (field_id, value_type));
                    }
                    self.records.insert(type_id, RecordShape { fields: shape });
                }
                TypeDeclarationAst::Result { ok, error, .. } => {
                    if let (Some(ok), Some(error)) = (self.lower_type(ok), self.lower_type(error)) {
                        self.results.insert(type_id, ResultShape { ok, error });
                    }
                }
            }
        }
    }

    fn build_signatures(&mut self) {
        for declaration in &self.resolved.ast.declarations {
            match &declaration.node {
                DeclarationAst::Effect(effect) => {
                    for operation in &effect.operations {
                        let id =
                            canonical_operation_id(&effect.name.node, &operation.node.name.node);
                        self.insert_signature(
                            id,
                            &operation.node.parameters,
                            &operation.node.result,
                        );
                    }
                }
                DeclarationAst::Function(function) => {
                    if let Some(id) =
                        self.definition_id(&function.name.origin, SymbolKind::Function)
                    {
                        self.insert_signature(id, &function.parameters, &function.result);
                    }
                }
                DeclarationAst::Task(task) => {
                    if let Some(id) = self.definition_id(&task.name.origin, SymbolKind::Task) {
                        self.insert_signature(id, &task.parameters, &task.result);
                    }
                }
                DeclarationAst::Type(_) => {}
            }
        }
    }

    fn insert_signature(
        &mut self,
        id: SymbolId,
        parameters: &[Spanned<crate::source::ParameterAst>],
        result: &Spanned<TypeAst>,
    ) {
        let parameter_types: Option<Vec<_>> = parameters
            .iter()
            .map(|parameter| self.lower_type(&parameter.node.value_type))
            .collect();
        if let (Some(parameters), Some(result)) = (parameter_types, self.lower_type(result)) {
            self.signatures.insert(id, Signature { parameters, result });
        }
    }

    fn check_bodies(&mut self) {
        for declaration in &self.resolved.ast.declarations {
            match &declaration.node {
                DeclarationAst::Function(function) => {
                    let Some(owner) =
                        self.definition_id(&function.name.origin, SymbolKind::Function)
                    else {
                        continue;
                    };
                    let Some(signature) = self.signatures.get(&owner).cloned() else {
                        continue;
                    };
                    self.bind_parameters(&function.parameters, &signature.parameters);
                    self.check_expression(&function.body, Some(&signature.result));
                    self.clear_locals();
                }
                DeclarationAst::Task(task) => {
                    let Some(owner) = self.definition_id(&task.name.origin, SymbolKind::Task)
                    else {
                        continue;
                    };
                    let Some(signature) = self.signatures.get(&owner).cloned() else {
                        continue;
                    };
                    self.bind_parameters(&task.parameters, &signature.parameters);
                    self.check_expression(&task.body, Some(&signature.result));
                    if let Some(result_symbol_id) = self
                        .find_definition(SymbolKind::Local, "result", Some(&task.ensures.origin))
                        .map(|definition| definition.id.clone())
                    {
                        self.local_types
                            .insert(result_symbol_id, signature.result.clone());
                    }
                    self.check_expression(&task.ensures, Some(&ValueType::Bool));
                    self.clear_locals();
                }
                DeclarationAst::Type(_) | DeclarationAst::Effect(_) => {}
            }
        }
    }

    fn check_expression(
        &mut self,
        expression: &Spanned<ExpressionAst>,
        expected: Option<&ValueType>,
    ) -> Option<ValueType> {
        let actual = match &expression.node {
            ExpressionAst::Integer { .. } => Some(ValueType::Int),
            ExpressionAst::Boolean { .. } => Some(ValueType::Bool),
            ExpressionAst::String { .. } => Some(ValueType::String),
            ExpressionAst::Variable { .. } => self.variable_type(expression),
            ExpressionAst::Record { fields, .. } => self.record_type(expression, fields),
            ExpressionAst::Field { target, field } => self.field_type(expression, target, field),
            ExpressionAst::Ok { value } => self.constructor_type(expression, value, expected, true),
            ExpressionAst::Error { value } => {
                self.constructor_type(expression, value, expected, false)
            }
            ExpressionAst::Call { arguments, .. } | ExpressionAst::Perform { arguments, .. } => {
                self.call_type(expression, arguments)
            }
            ExpressionAst::Let { name, value, body } => {
                let value_type = self.check_expression(value, None)?;
                if let Some(definition_id) = self
                    .definition_at(&name.origin, &[SymbolKind::Local, SymbolKind::Parameter])
                    .map(|definition| definition.id.clone())
                {
                    self.local_types
                        .insert(definition_id.clone(), value_type.clone());
                    let result = self.check_expression(body, expected);
                    self.local_types.remove(&definition_id);
                    return result;
                }
                None
            }
            ExpressionAst::MatchResult {
                value,
                ok_name,
                ok_body,
                error_name,
                error_body,
            } => self.match_type(
                expression, value, ok_name, ok_body, error_name, error_body, expected,
            ),
            ExpressionAst::Sequence { first, second } => {
                self.check_expression(first, None);
                self.check_expression(second, expected)
            }
            ExpressionAst::Add { left, right } => {
                self.check_expression(left, Some(&ValueType::Int));
                self.check_expression(right, Some(&ValueType::Int));
                Some(ValueType::Int)
            }
            ExpressionAst::Equal { left, right } => {
                let left_type = self.check_expression(left, None)?;
                self.check_expression(right, Some(&left_type));
                Some(ValueType::Bool)
            }
        };
        let actual = actual?;
        if let Some(expected) = expected
            && &actual != expected
        {
            self.type_mismatch(expected, &actual, &expression.origin);
            return None;
        }
        self.expression_types
            .insert(OriginKey::from_origin(&expression.origin), actual.clone());
        Some(actual)
    }

    fn variable_type(&mut self, expression: &Spanned<ExpressionAst>) -> Option<ValueType> {
        let id = self.use_id(&expression.origin)?;
        self.local_types.get(&id).cloned().or_else(|| {
            self.diagnostics.push(Diagnostic::error(
                "TYPE_VALUE_UNAVAILABLE",
                format!("resolved value `{}` has no data type", id.0),
                Some(expression.origin.clone()),
            ));
            None
        })
    }

    fn record_type(
        &mut self,
        expression: &Spanned<ExpressionAst>,
        fields: &[Spanned<crate::source::RecordFieldAst>],
    ) -> Option<ValueType> {
        let type_id = self.use_id(&expression.origin)?;
        if self.opaque_types.contains(&type_id) {
            self.diagnostics.push(Diagnostic::error(
                "TYPE_OPAQUE_CONSTRUCTION",
                "opaque values cannot be constructed outside approved runtime operations",
                Some(expression.origin.clone()),
            ));
            return None;
        }
        let Some(shape) = self.records.get(&type_id).cloned() else {
            self.diagnostics.push(Diagnostic::error(
                "TYPE_EXPECTED_RECORD",
                format!("`{}` is not a record type", type_id.0),
                Some(expression.origin.clone()),
            ));
            return None;
        };
        let mut seen = BTreeSet::new();
        for field in fields {
            if !seen.insert(field.node.name.node.clone()) {
                self.diagnostics.push(Diagnostic::error(
                    "TYPE_DUPLICATE_FIELD",
                    format!("duplicate record field `{}`", field.node.name.node),
                    Some(field.node.name.origin.clone()),
                ));
                continue;
            }
            if let Some((_id, field_type)) = shape.fields.get(&field.node.name.node) {
                self.check_expression(&field.node.value, Some(field_type));
            }
        }
        let expected_fields: BTreeSet<_> = shape.fields.keys().cloned().collect();
        if seen != expected_fields {
            let missing: Vec<_> = expected_fields.difference(&seen).cloned().collect();
            self.diagnostics.push(Diagnostic::error(
                "TYPE_RECORD_FIELDS_INCOMPLETE",
                format!("record is missing fields: {}", missing.join(", ")),
                Some(expression.origin.clone()),
            ));
        }
        Some(ValueType::Named { id: type_id })
    }

    fn field_type(
        &mut self,
        expression: &Spanned<ExpressionAst>,
        target: &Spanned<ExpressionAst>,
        field: &str,
    ) -> Option<ValueType> {
        let target_type = self.check_expression(target, None)?;
        let ValueType::Named { id } = target_type else {
            self.diagnostics.push(Diagnostic::error(
                "TYPE_FIELD_TARGET_INVALID",
                "field access requires a record value",
                Some(expression.origin.clone()),
            ));
            return None;
        };
        if self.opaque_types.contains(&id) {
            self.diagnostics.push(Diagnostic::error(
                "TYPE_OPAQUE_INSPECTION",
                "opaque values cannot be inspected outside approved runtime operations",
                Some(expression.origin.clone()),
            ));
            return None;
        }
        let Some((field_id, field_type)) = self
            .records
            .get(&id)
            .and_then(|shape| shape.fields.get(field))
            .cloned()
        else {
            self.diagnostics.push(Diagnostic::error(
                "TYPE_UNKNOWN_FIELD",
                format!("record `{}` has no field `{field}`", id.0),
                Some(expression.origin.clone()),
            ));
            return None;
        };
        self.field_uses
            .insert(OriginKey::from_origin(&expression.origin), field_id);
        Some(field_type)
    }

    fn constructor_type(
        &mut self,
        expression: &Spanned<ExpressionAst>,
        value: &Spanned<ExpressionAst>,
        expected: Option<&ValueType>,
        is_ok: bool,
    ) -> Option<ValueType> {
        let Some(expected) = expected else {
            self.diagnostics.push(Diagnostic::error(
                "TYPE_RESULT_CONTEXT_REQUIRED",
                "result constructors require an expected result type",
                Some(expression.origin.clone()),
            ));
            return None;
        };
        let Some((ok, error)) = self.result_components(expected) else {
            self.diagnostics.push(Diagnostic::error(
                "TYPE_IMPOSSIBLE_CONSTRUCTOR",
                "result constructor cannot inhabit the expected non-result type",
                Some(expression.origin.clone()),
            ));
            return None;
        };
        self.check_expression(value, Some(if is_ok { &ok } else { &error }));
        Some(expected.clone())
    }

    fn call_type(
        &mut self,
        expression: &Spanned<ExpressionAst>,
        arguments: &[Spanned<ExpressionAst>],
    ) -> Option<ValueType> {
        let id = self.use_id(&expression.origin)?;
        let Some(signature) = self.signatures.get(&id).cloned() else {
            self.diagnostics.push(Diagnostic::error(
                "TYPE_CALLABLE_SIGNATURE_MISSING",
                format!("resolved callable `{}` has no signature", id.0),
                Some(expression.origin.clone()),
            ));
            return None;
        };
        for (argument, parameter_type) in arguments.iter().zip(&signature.parameters) {
            self.check_expression(argument, Some(parameter_type));
        }
        Some(signature.result)
    }

    #[allow(clippy::too_many_arguments)]
    fn match_type(
        &mut self,
        expression: &Spanned<ExpressionAst>,
        value: &Spanned<ExpressionAst>,
        ok_name: &Spanned<String>,
        ok_body: &Spanned<ExpressionAst>,
        error_name: &Spanned<String>,
        error_body: &Spanned<ExpressionAst>,
        expected: Option<&ValueType>,
    ) -> Option<ValueType> {
        let value_type = self.check_expression(value, None)?;
        let Some((ok_type, error_type)) = self.result_components(&value_type) else {
            self.diagnostics.push(Diagnostic::error(
                "TYPE_MATCH_EXPECTED_RESULT",
                "result match requires a result-typed value",
                Some(expression.origin.clone()),
            ));
            return None;
        };
        let ok_id = self
            .definition_at(&ok_name.origin, &[SymbolKind::Local])?
            .id
            .clone();
        self.local_types.insert(ok_id.clone(), ok_type);
        let ok_result = self.check_expression(ok_body, expected);
        self.local_types.remove(&ok_id);

        let error_id = self
            .definition_at(&error_name.origin, &[SymbolKind::Local])?
            .id
            .clone();
        self.local_types.insert(error_id.clone(), error_type);
        let branch_expected = expected.or(ok_result.as_ref());
        let error_result = self.check_expression(error_body, branch_expected);
        self.local_types.remove(&error_id);
        match (ok_result, error_result) {
            (Some(left), Some(right)) if left == right => Some(left),
            (Some(left), Some(right)) => {
                self.type_mismatch(&left, &right, &error_body.origin);
                None
            }
            _ => None,
        }
    }

    fn bind_parameters(
        &mut self,
        parameters: &[Spanned<crate::source::ParameterAst>],
        types: &[ValueType],
    ) {
        for (parameter, value_type) in parameters.iter().zip(types) {
            if let Some(definition_id) = self
                .definition_at(&parameter.node.name.origin, &[SymbolKind::Parameter])
                .map(|definition| definition.id.clone())
            {
                self.local_types.insert(definition_id, value_type.clone());
            }
        }
    }

    fn lower_type(&self, value_type: &Spanned<TypeAst>) -> Option<ValueType> {
        match &value_type.node {
            TypeAst::Primitive { name } => Some(match name {
                PrimitiveType::Int => ValueType::Int,
                PrimitiveType::Bool => ValueType::Bool,
                PrimitiveType::String => ValueType::String,
            }),
            TypeAst::Named { .. } => self
                .use_id(&value_type.origin)
                .map(|id| ValueType::Named { id }),
            TypeAst::Product { items } => Some(ValueType::Product {
                items: items
                    .iter()
                    .map(|item| self.lower_type(item))
                    .collect::<Option<Vec<_>>>()?,
            }),
            TypeAst::Result { ok, error } => Some(ValueType::Result {
                ok: Box::new(self.lower_type(ok)?),
                error: Box::new(self.lower_type(error)?),
            }),
        }
    }

    fn result_components(&self, value_type: &ValueType) -> Option<(ValueType, ValueType)> {
        match value_type {
            ValueType::Result { ok, error } => Some(((**ok).clone(), (**error).clone())),
            ValueType::Named { id } => self
                .results
                .get(id)
                .map(|shape| (shape.ok.clone(), shape.error.clone())),
            _ => None,
        }
    }

    fn type_mismatch(&mut self, expected: &ValueType, actual: &ValueType, origin: &Origin) {
        self.diagnostics.push(Diagnostic::error(
            "TYPE_MISMATCH",
            format!("expected `{expected:?}` but found `{actual:?}`"),
            Some(origin.clone()),
        ));
    }

    fn use_id(&self, origin: &Origin) -> Option<SymbolId> {
        self.resolved
            .symbols
            .uses
            .get(&OriginKey::from_origin(origin))
            .cloned()
    }

    fn definition_id(&self, origin: &Origin, kind: SymbolKind) -> Option<SymbolId> {
        self.definition_at(origin, &[kind])
            .map(|definition| definition.id.clone())
    }

    fn definition_at(&self, origin: &Origin, kinds: &[SymbolKind]) -> Option<&Definition> {
        self.resolved
            .symbols
            .definitions
            .values()
            .find(|definition| {
                OriginKey::from_origin(&definition.origin) == OriginKey::from_origin(origin)
                    && kinds.contains(&definition.kind)
            })
    }

    fn find_definition(
        &self,
        kind: SymbolKind,
        name: &str,
        near: Option<&Origin>,
    ) -> Option<&Definition> {
        self.resolved
            .symbols
            .definitions
            .values()
            .find(|definition| {
                definition.kind == kind
                    && definition.name == name
                    && near.is_none_or(|origin| definition.origin.source == origin.source)
            })
    }

    fn clear_locals(&mut self) {
        self.local_types.clear();
    }
}

#[cfg(test)]
mod tests {
    use super::check;
    use crate::diagnostic::Diagnostic;
    use crate::parser::parse;
    use crate::resolver::resolve;
    use crate::semantic::{SymbolId, ValueType};

    fn check_source(source: &str) -> Result<crate::semantic::CheckedModule, Vec<Diagnostic>> {
        let module = parse("types.alang", source).expect("test syntax must parse");
        let resolved = resolve(&module)?;
        check(resolved)
    }

    #[test]
    fn data_typing_checks_records_functions_results_lets_and_matches() {
        let checked = check_source(
            r#"
module Types version "alang-source-v1" {
  record Pair { left: Int, right: Int }
  result Number = ok Int | error String;
  fn sum(pair: Pair) -> Int = pair.left + pair.right;
  fn make(value: Int) -> Pair = Pair { left: value, right: value + 1 };
  fn choose(value: Number) -> Int = match value {
    ok(number) => let next = number + 1; next,
    error(reason) => 0
  };
}
"#,
        )
        .expect("well-typed source must pass");
        assert_eq!(
            checked
                .types
                .signatures
                .get(&SymbolId("function:Types.sum/1".to_owned()))
                .map(|signature| signature.result.clone()),
            Some(ValueType::Int)
        );
    }

    #[test]
    fn data_typing_rejects_mismatches_missing_fields_and_nonresult_matches() {
        let diagnostics = check_source(
            r#"
module BadTypes version "alang-source-v1" {
  record Pair { left: Int, right: Int }
  fn bad(value: Int) -> Bool = Pair { left: value };
  fn wrong(value: Int) -> Int = match value {
    ok(number) => number,
    error(reason) => 0
  };
}
"#,
        )
        .expect_err("ill-typed source must fail");
        let codes: Vec<_> = diagnostics.iter().map(|item| item.code.as_str()).collect();
        assert!(codes.contains(&"TYPE_RECORD_FIELDS_INCOMPLETE"));
        assert!(codes.contains(&"TYPE_MISMATCH"));
        assert!(codes.contains(&"TYPE_MATCH_EXPECTED_RESULT"));
    }

    #[test]
    fn data_typing_rejects_opaque_construction_and_inspection() {
        let diagnostics = check_source(
            r#"
module Opaque version "alang-source-v1" {
  opaque Grant;
  fn construct() -> Grant = Grant { value: 1 };
  fn inspect(grant: Grant) -> Int = grant.value;
}
"#,
        )
        .expect_err("opaque boundaries must fail");
        let codes: Vec<_> = diagnostics.iter().map(|item| item.code.as_str()).collect();
        assert!(codes.contains(&"TYPE_OPAQUE_CONSTRUCTION"));
        assert!(codes.contains(&"TYPE_OPAQUE_INSPECTION"));
    }
}
