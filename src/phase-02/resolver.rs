use crate::diagnostic::{Diagnostic, sort_diagnostics};
use crate::semantic::{
    Definition, OriginKey, ResolvedModule, SymbolId, SymbolKind, SymbolTable,
    canonical_operation_id, canonical_resource_id,
};
use crate::source::{
    DeclarationAst, ExpressionAst, ModuleAst, Origin, ParameterAst, Spanned, TypeAst,
    TypeDeclarationAst,
};
use std::collections::{BTreeMap, BTreeSet};

/// Resolve all definitions and uses into stable semantic identities.
///
/// # Errors
///
/// Returns deterministic diagnostics for duplicate or shadowed definitions,
/// unknown names, wrong namespaces, and call or operation arity mismatches.
pub fn resolve(module: &ModuleAst) -> Result<ResolvedModule, Vec<Diagnostic>> {
    let mut resolver = Resolver::new(module);
    resolver.collect_top_level(module);
    resolver.resolve_bodies(module);
    sort_diagnostics(&mut resolver.diagnostics);
    if resolver.diagnostics.is_empty() {
        Ok(ResolvedModule {
            ast: module.clone(),
            symbols: SymbolTable {
                module: resolver.module_id,
                definitions: resolver.definitions,
                uses: resolver.uses,
                verifier_ids: resolver.verifier_ids,
            },
        })
    } else {
        Err(resolver.diagnostics)
    }
}

#[derive(Clone)]
struct Callable {
    id: SymbolId,
    arity: usize,
}

#[derive(Clone)]
struct Operation {
    id: SymbolId,
    arity: usize,
}

struct Resolver {
    module_name: String,
    module_id: SymbolId,
    definitions: BTreeMap<SymbolId, Definition>,
    uses: BTreeMap<OriginKey, SymbolId>,
    verifier_ids: BTreeMap<SymbolId, SymbolId>,
    types: BTreeMap<String, SymbolId>,
    callables: BTreeMap<String, Callable>,
    effects: BTreeMap<String, BTreeMap<String, Operation>>,
    fields: BTreeMap<(SymbolId, String), SymbolId>,
    record_types: BTreeSet<SymbolId>,
    scopes: Vec<BTreeMap<String, SymbolId>>,
    diagnostics: Vec<Diagnostic>,
}

impl Resolver {
    fn new(module: &ModuleAst) -> Self {
        let module_id = SymbolId(format!("module:{}", module.name.node));
        let mut definitions = BTreeMap::new();
        definitions.insert(
            module_id.clone(),
            Definition {
                id: module_id.clone(),
                kind: SymbolKind::Module,
                name: module.name.node.clone(),
                arity: None,
                origin: module.name.origin.clone(),
            },
        );
        Self {
            module_name: module.name.node.clone(),
            module_id,
            definitions,
            uses: BTreeMap::new(),
            verifier_ids: BTreeMap::new(),
            types: BTreeMap::new(),
            callables: BTreeMap::new(),
            effects: BTreeMap::new(),
            fields: BTreeMap::new(),
            record_types: BTreeSet::new(),
            scopes: Vec::new(),
            diagnostics: Vec::new(),
        }
    }

    fn collect_top_level(&mut self, module: &ModuleAst) {
        for declaration in &module.declarations {
            match &declaration.node {
                DeclarationAst::Type(type_declaration) => {
                    self.collect_type(type_declaration, &declaration.origin);
                }
                DeclarationAst::Effect(effect) => {
                    let effect_id = SymbolId(format!("effect:{}", effect.name.node));
                    if self.insert_named_definition(
                        "effect",
                        &effect.name,
                        effect_id.clone(),
                        SymbolKind::Effect,
                        None,
                        self.effects.contains_key(&effect.name.node),
                    ) {
                        let resource_id = canonical_resource_id(&effect.name.node);
                        self.insert_definition(Definition {
                            id: resource_id,
                            kind: SymbolKind::Resource,
                            name: effect.name.node.clone(),
                            arity: None,
                            origin: effect.name.origin.clone(),
                        });
                        let mut operations = BTreeMap::<String, Operation>::new();
                        for operation in &effect.operations {
                            let operation_id = canonical_operation_id(
                                &effect.name.node,
                                &operation.node.name.node,
                            );
                            if let Some(previous) = operations.get(&operation.node.name.node) {
                                self.duplicate(
                                    "operation",
                                    &operation.node.name.node,
                                    &operation.node.name.origin,
                                    &previous.id,
                                );
                                continue;
                            }
                            self.insert_definition(Definition {
                                id: operation_id.clone(),
                                kind: SymbolKind::Operation,
                                name: format!("{}.{}", effect.name.node, operation.node.name.node),
                                arity: Some(operation.node.parameters.len()),
                                origin: operation.node.name.origin.clone(),
                            });
                            operations.insert(
                                operation.node.name.node.clone(),
                                Operation {
                                    id: operation_id,
                                    arity: operation.node.parameters.len(),
                                },
                            );
                        }
                        self.effects.insert(effect.name.node.clone(), operations);
                    }
                }
                DeclarationAst::Function(function) => {
                    self.collect_callable(
                        "function",
                        &function.name,
                        function.parameters.len(),
                        SymbolKind::Function,
                    );
                }
                DeclarationAst::Task(task) => {
                    self.collect_callable(
                        "task",
                        &task.name,
                        task.parameters.len(),
                        SymbolKind::Task,
                    );
                }
            }
        }
    }

    fn collect_type(&mut self, declaration: &TypeDeclarationAst, origin: &Origin) {
        let name = match declaration {
            TypeDeclarationAst::Opaque { name }
            | TypeDeclarationAst::Record { name, .. }
            | TypeDeclarationAst::Result { name, .. } => name,
        };
        let type_id = SymbolId(format!("type:{}.{}", self.module_name, name.node));
        if !self.insert_named_definition(
            "type",
            name,
            type_id.clone(),
            SymbolKind::Type,
            None,
            self.types.contains_key(&name.node),
        ) {
            return;
        }
        self.types.insert(name.node.clone(), type_id.clone());
        match declaration {
            TypeDeclarationAst::Record { fields, .. } => {
                self.record_types.insert(type_id.clone());
                let mut names = BTreeMap::<String, SymbolId>::new();
                for field in fields {
                    let field_id =
                        SymbolId(format!("field:{}.{}", type_id.0, field.node.name.node));
                    if let Some(previous) = names.get(&field.node.name.node) {
                        self.duplicate(
                            "field",
                            &field.node.name.node,
                            &field.node.name.origin,
                            previous,
                        );
                        continue;
                    }
                    self.insert_definition(Definition {
                        id: field_id.clone(),
                        kind: SymbolKind::Field,
                        name: field.node.name.node.clone(),
                        arity: None,
                        origin: field.node.name.origin.clone(),
                    });
                    names.insert(field.node.name.node.clone(), field_id.clone());
                    self.fields
                        .insert((type_id.clone(), field.node.name.node.clone()), field_id);
                }
            }
            TypeDeclarationAst::Result { .. } => {
                for constructor in ["ok", "error"] {
                    let constructor_id =
                        SymbolId(format!("constructor:{}.{}", type_id.0, constructor));
                    self.insert_definition(Definition {
                        id: constructor_id,
                        kind: SymbolKind::Constructor,
                        name: constructor.to_owned(),
                        arity: Some(1),
                        origin: origin.clone(),
                    });
                }
            }
            TypeDeclarationAst::Opaque { .. } => {}
        }
    }

    fn collect_callable(
        &mut self,
        description: &str,
        name: &Spanned<String>,
        arity: usize,
        kind: SymbolKind,
    ) {
        let id = SymbolId(format!(
            "{}:{}.{}/{}",
            description, self.module_name, name.node, arity
        ));
        let duplicate = self.callables.contains_key(&name.node);
        if self.insert_named_definition(description, name, id.clone(), kind, Some(arity), duplicate)
        {
            self.callables
                .insert(name.node.clone(), Callable { id, arity });
        }
    }

    fn resolve_bodies(&mut self, module: &ModuleAst) {
        for declaration in &module.declarations {
            match &declaration.node {
                DeclarationAst::Type(type_declaration) => {
                    self.resolve_type_declaration(type_declaration);
                }
                DeclarationAst::Effect(effect) => {
                    for operation in &effect.operations {
                        let owner =
                            canonical_operation_id(&effect.name.node, &operation.node.name.node);
                        self.begin_scope();
                        self.define_parameters(&owner, &operation.node.parameters);
                        for parameter in &operation.node.parameters {
                            self.resolve_type(&parameter.node.value_type);
                        }
                        self.resolve_type(&operation.node.result);
                        self.end_scope();
                    }
                }
                DeclarationAst::Function(function) => {
                    if let Some(callable) = self.callables.get(&function.name.node).cloned() {
                        self.begin_scope();
                        self.define_parameters(&callable.id, &function.parameters);
                        for parameter in &function.parameters {
                            self.resolve_type(&parameter.node.value_type);
                        }
                        self.resolve_type(&function.result);
                        self.resolve_expression(&callable.id, &function.body);
                        self.end_scope();
                    }
                }
                DeclarationAst::Task(task) => {
                    if let Some(callable) = self.callables.get(&task.name.node).cloned() {
                        self.begin_scope();
                        self.define_parameters(&callable.id, &task.parameters);
                        for parameter in &task.parameters {
                            self.resolve_type(&parameter.node.value_type);
                        }
                        self.resolve_type(&task.result);
                        for effect in &task.effects {
                            self.resolve_operation(&effect.node, &effect.origin, None);
                        }
                        for requirement in &task.requirements {
                            self.resolve_operation(
                                &requirement.node.target.node,
                                &requirement.node.target.origin,
                                None,
                            );
                        }
                        self.resolve_expression(&callable.id, &task.body);
                        self.define_local(
                            &callable.id,
                            &Spanned::new("result".to_owned(), task.ensures.origin.clone()),
                            SymbolKind::Local,
                            None,
                        );
                        let verifier_id = SymbolId(format!("verifier:{}", callable.id.0));
                        self.insert_definition(Definition {
                            id: verifier_id.clone(),
                            kind: SymbolKind::Verifier,
                            name: format!("{}.ensures", task.name.node),
                            arity: Some(1),
                            origin: task.ensures.origin.clone(),
                        });
                        self.verifier_ids.insert(callable.id.clone(), verifier_id);
                        self.resolve_expression(&callable.id, &task.ensures);
                        self.end_scope();
                    }
                }
            }
        }
    }

    fn resolve_type_declaration(&mut self, declaration: &TypeDeclarationAst) {
        match declaration {
            TypeDeclarationAst::Opaque { .. } => {}
            TypeDeclarationAst::Record { fields, .. } => {
                for field in fields {
                    self.resolve_type(&field.node.value_type);
                }
            }
            TypeDeclarationAst::Result { ok, error, .. } => {
                self.resolve_type(ok);
                self.resolve_type(error);
            }
        }
    }

    fn define_parameters(&mut self, owner: &SymbolId, parameters: &[Spanned<ParameterAst>]) {
        for (index, parameter) in parameters.iter().enumerate() {
            self.define_local(
                owner,
                &parameter.node.name,
                SymbolKind::Parameter,
                Some(index),
            );
        }
    }

    fn resolve_type(&mut self, value_type: &Spanned<TypeAst>) {
        match &value_type.node {
            TypeAst::Primitive { .. } => {}
            TypeAst::Named { name } => {
                if let Some(id) = self.types.get(name).cloned() {
                    self.record_use(&value_type.origin, id);
                } else {
                    self.unknown_or_wrong_namespace("type", name, &value_type.origin);
                }
            }
            TypeAst::Product { items } => {
                for item in items {
                    self.resolve_type(item);
                }
            }
            TypeAst::Result { ok, error } => {
                self.resolve_type(ok);
                self.resolve_type(error);
            }
        }
    }

    #[allow(clippy::too_many_lines)]
    fn resolve_expression(&mut self, owner: &SymbolId, expression: &Spanned<ExpressionAst>) {
        match &expression.node {
            ExpressionAst::Integer { .. }
            | ExpressionAst::Boolean { .. }
            | ExpressionAst::String { .. } => {}
            ExpressionAst::Variable { name } => {
                if let Some(id) = self.lookup_local(name) {
                    self.record_use(&expression.origin, id);
                } else {
                    self.unknown_or_wrong_namespace("value", name, &expression.origin);
                }
            }
            ExpressionAst::Record { type_name, fields } => {
                if let Some(type_id) = self.types.get(type_name).cloned() {
                    self.record_use(&expression.origin, type_id.clone());
                    for field in fields {
                        if self.record_types.contains(&type_id) {
                            if let Some(field_id) = self
                                .fields
                                .get(&(type_id.clone(), field.node.name.node.clone()))
                                .cloned()
                            {
                                self.record_use(&field.node.name.origin, field_id);
                            } else {
                                self.diagnostics.push(Diagnostic::error(
                                    "RESOLVE_UNKNOWN_FIELD",
                                    format!(
                                        "record `{type_name}` has no field `{}`",
                                        field.node.name.node
                                    ),
                                    Some(field.node.name.origin.clone()),
                                ));
                            }
                        }
                        self.resolve_expression(owner, &field.node.value);
                    }
                } else {
                    self.unknown_or_wrong_namespace("type", type_name, &expression.origin);
                }
            }
            ExpressionAst::Field { target, .. } => self.resolve_expression(owner, target),
            ExpressionAst::Ok { value } | ExpressionAst::Error { value } => {
                self.resolve_expression(owner, value);
            }
            ExpressionAst::Call {
                function,
                arguments,
            } => {
                if let Some(callable) = self.callables.get(function).cloned() {
                    self.record_use(&expression.origin, callable.id);
                    if callable.arity != arguments.len() {
                        self.arity_mismatch(
                            function,
                            callable.arity,
                            arguments.len(),
                            &expression.origin,
                        );
                    }
                } else {
                    self.unknown_or_wrong_namespace(
                        "function or task",
                        function,
                        &expression.origin,
                    );
                }
                for argument in arguments {
                    self.resolve_expression(owner, argument);
                }
            }
            ExpressionAst::Let { name, value, body } => {
                self.resolve_expression(owner, value);
                self.begin_scope();
                self.define_local(owner, name, SymbolKind::Local, None);
                self.resolve_expression(owner, body);
                self.end_scope();
            }
            ExpressionAst::MatchResult {
                value,
                ok_name,
                ok_body,
                error_name,
                error_body,
            } => {
                self.resolve_expression(owner, value);
                self.begin_scope();
                self.define_local(owner, ok_name, SymbolKind::Local, None);
                self.resolve_expression(owner, ok_body);
                self.end_scope();
                self.begin_scope();
                self.define_local(owner, error_name, SymbolKind::Local, None);
                self.resolve_expression(owner, error_body);
                self.end_scope();
            }
            ExpressionAst::Perform {
                operation,
                arguments,
            } => {
                self.resolve_operation(&operation.node, &operation.origin, Some(arguments.len()));
                for argument in arguments {
                    self.resolve_expression(owner, argument);
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
                self.resolve_expression(owner, first);
                self.resolve_expression(owner, second);
            }
        }
    }

    fn resolve_operation(
        &mut self,
        name: &crate::source::QualifiedName,
        origin: &Origin,
        actual_arity: Option<usize>,
    ) {
        if let Some(operations) = self.effects.get(&name.namespace) {
            if let Some(operation) = operations.get(&name.name).cloned() {
                self.record_use(origin, operation.id);
                if let Some(actual) = actual_arity
                    && actual != operation.arity
                {
                    self.arity_mismatch(
                        &format!("{}.{}", name.namespace, name.name),
                        operation.arity,
                        actual,
                        origin,
                    );
                }
            } else {
                self.diagnostics.push(Diagnostic::error(
                    "RESOLVE_UNKNOWN_OPERATION",
                    format!(
                        "effect `{}` has no operation `{}`",
                        name.namespace, name.name
                    ),
                    Some(origin.clone()),
                ));
            }
        } else {
            self.unknown_or_wrong_namespace("effect", &name.namespace, origin);
        }
    }

    fn define_local(
        &mut self,
        owner: &SymbolId,
        name: &Spanned<String>,
        kind: SymbolKind,
        index: Option<usize>,
    ) {
        if let Some(previous) = self.lookup_local(&name.node) {
            self.duplicate("local binding", &name.node, &name.origin, &previous);
            return;
        }
        let suffix = index.map_or_else(
            || format!("@{}", name.origin.start.byte),
            |value| format!("#{value}"),
        );
        let id = SymbolId(format!(
            "{}:{}:{}{}",
            kind_name(kind),
            owner.0,
            name.node,
            suffix
        ));
        self.insert_definition(Definition {
            id: id.clone(),
            kind,
            name: name.node.clone(),
            arity: None,
            origin: name.origin.clone(),
        });
        self.current_scope_mut().insert(name.node.clone(), id);
    }

    fn insert_named_definition(
        &mut self,
        description: &str,
        name: &Spanned<String>,
        id: SymbolId,
        kind: SymbolKind,
        arity: Option<usize>,
        duplicate: bool,
    ) -> bool {
        if duplicate {
            let previous = self
                .definitions
                .values()
                .find(|definition| definition.kind == kind && definition.name == name.node)
                .map(|definition| definition.id.clone());
            if let Some(previous) = previous {
                self.duplicate(description, &name.node, &name.origin, &previous);
            }
            return false;
        }
        self.insert_definition(Definition {
            id,
            kind,
            name: name.node.clone(),
            arity,
            origin: name.origin.clone(),
        });
        true
    }

    fn insert_definition(&mut self, definition: Definition) {
        self.definitions.insert(definition.id.clone(), definition);
    }

    fn duplicate(&mut self, description: &str, name: &str, origin: &Origin, previous: &SymbolId) {
        let diagnostic = Diagnostic::error(
            "RESOLVE_DUPLICATE_DEFINITION",
            format!("duplicate {description} `{name}`"),
            Some(origin.clone()),
        );
        let diagnostic = self
            .definitions
            .get(previous)
            .map_or(diagnostic.clone(), |definition| {
                diagnostic.with_label("first definition is here", definition.origin.clone())
            });
        self.diagnostics.push(diagnostic);
    }

    fn unknown_or_wrong_namespace(&mut self, expected: &str, name: &str, origin: &Origin) {
        let exists_elsewhere = self.types.contains_key(name)
            || self.callables.contains_key(name)
            || self.effects.contains_key(name)
            || self.lookup_local(name).is_some();
        let (code, message) = if exists_elsewhere {
            (
                "RESOLVE_WRONG_NAMESPACE",
                format!("`{name}` does not name a {expected}"),
            )
        } else {
            (
                "RESOLVE_UNKNOWN_NAME",
                format!("unknown {expected} `{name}`"),
            )
        };
        self.diagnostics
            .push(Diagnostic::error(code, message, Some(origin.clone())));
    }

    fn arity_mismatch(&mut self, name: &str, expected: usize, actual: usize, origin: &Origin) {
        self.diagnostics.push(Diagnostic::error(
            "RESOLVE_ARITY_MISMATCH",
            format!("`{name}` expects {expected} arguments but received {actual}"),
            Some(origin.clone()),
        ));
    }

    fn record_use(&mut self, origin: &Origin, id: SymbolId) {
        self.uses.insert(OriginKey::from_origin(origin), id);
    }

    fn begin_scope(&mut self) {
        self.scopes.push(BTreeMap::new());
    }

    fn end_scope(&mut self) {
        self.scopes.pop();
    }

    fn current_scope_mut(&mut self) -> &mut BTreeMap<String, SymbolId> {
        self.scopes
            .last_mut()
            .expect("resolver must establish a scope before defining locals")
    }

    fn lookup_local(&self, name: &str) -> Option<SymbolId> {
        self.scopes
            .iter()
            .rev()
            .find_map(|scope| scope.get(name).cloned())
    }
}

fn kind_name(kind: SymbolKind) -> &'static str {
    match kind {
        SymbolKind::Parameter => "parameter",
        SymbolKind::Local => "local",
        _ => "symbol",
    }
}

#[cfg(test)]
mod tests {
    use super::resolve;
    use crate::parser::parse;
    use crate::semantic::{SymbolId, canonical_operation_id};

    #[test]
    fn resolution_assigns_stable_definition_operation_and_verifier_ids() {
        let module = parse(
            "resolve.alang",
            r#"
module Resolve version "alang-source-v1" {
  effect Model { operation complete(prompt: String) -> String; }
  fn identity(value: String) -> String = value;
  task ask(prompt: String) -> String
    effect [Model.complete]
    requires [Model.complete(max_calls = 1)]
    = perform Model.complete(prompt)
    ensures true;
}
"#,
        )
        .expect("source must parse");
        let resolved = resolve(&module).expect("source must resolve");
        assert!(
            resolved
                .symbols
                .definitions
                .contains_key(&SymbolId("function:Resolve.identity/1".to_owned()))
        );
        assert!(
            resolved
                .symbols
                .definitions
                .contains_key(&canonical_operation_id("Model", "complete"))
        );
        assert_eq!(
            resolved.symbols.verifier_ids.values().next(),
            Some(&SymbolId("verifier:task:Resolve.ask/1".to_owned()))
        );
    }

    #[test]
    fn resolution_rejects_duplicates_shadowing_unknown_names_and_arity() {
        let module = parse(
            "bad-resolve.alang",
            r#"
module Bad version "alang-source-v1" {
  opaque Item;
  opaque Item;
  fn one(value: Int) -> Int = let value = missing; one();
}
"#,
        )
        .expect("syntax must parse");
        let diagnostics = resolve(&module).expect_err("resolution must fail");
        let codes: Vec<_> = diagnostics.iter().map(|item| item.code.as_str()).collect();
        assert!(codes.contains(&"RESOLVE_DUPLICATE_DEFINITION"));
        assert!(codes.contains(&"RESOLVE_UNKNOWN_NAME"));
        assert!(codes.contains(&"RESOLVE_ARITY_MISMATCH"));
    }

    #[test]
    fn resolution_rejects_wrong_namespaces() {
        let module = parse(
            "namespace.alang",
            r#"
module Namespace version "alang-source-v1" {
  opaque Thing;
  fn f(value: Thing) -> Thing = Thing(value);
}
"#,
        )
        .expect("syntax must parse");
        let diagnostics = resolve(&module).expect_err("wrong namespace must fail");
        assert!(
            diagnostics
                .iter()
                .any(|item| item.code == "RESOLVE_WRONG_NAMESPACE")
        );
    }
}
