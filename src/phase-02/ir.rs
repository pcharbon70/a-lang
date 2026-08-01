use crate::diagnostic::{Diagnostic, sort_diagnostics};
use crate::semantic::{
    AuthorizedModule, OriginKey, RequirementSet, Signature, SymbolId, SymbolKind, ValueType,
};
use crate::source::{DeclarationAst, ExpressionAst, Origin, ParameterAst, Spanned};
use serde::{Deserialize, Serialize};
use std::collections::{BTreeMap, BTreeSet};

pub const TASK_IR_VERSION: &str = "alang-task-ir-v1";

#[derive(Clone, Debug, Deserialize, Eq, Ord, PartialEq, PartialOrd, Serialize)]
pub struct NodeId(pub String);

#[derive(Clone, Copy, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum IrCallableKind {
    PureArrow,
    Task,
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
pub struct IrBinding {
    pub id: SymbolId,
    pub value_type: ValueType,
    pub origin: Origin,
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
pub struct IrCallable {
    pub id: SymbolId,
    pub kind: IrCallableKind,
    pub parameters: Vec<IrBinding>,
    pub result: ValueType,
    pub root: NodeId,
    pub effects: BTreeSet<SymbolId>,
    pub requirements: RequirementSet,
    pub verifier: Option<NodeId>,
    pub verifier_id: Option<SymbolId>,
    pub result_binding: Option<SymbolId>,
    pub origin: Origin,
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
pub struct TypedTaskIr {
    pub version: String,
    pub module: SymbolId,
    pub callables: BTreeMap<SymbolId, IrCallable>,
    pub nodes: BTreeMap<NodeId, IrNode>,
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
pub struct IrNode {
    pub id: NodeId,
    pub owner: SymbolId,
    pub value_type: ValueType,
    pub kind: IrNodeKind,
    pub origin: Origin,
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
pub struct IrRecordField {
    pub field: SymbolId,
    pub value: NodeId,
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(tag = "kind", rename_all = "snake_case")]
pub enum IrLiteral {
    Integer { value: i64 },
    Boolean { value: bool },
    String { value: String },
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(tag = "kind", rename_all = "snake_case")]
pub enum IrNodeKind {
    Constant {
        literal: IrLiteral,
    },
    Input {
        binding: SymbolId,
    },
    RecordProduct {
        type_id: SymbolId,
        fields: Vec<IrRecordField>,
    },
    Project {
        target: NodeId,
        field: SymbolId,
    },
    Ok {
        value: NodeId,
    },
    Error {
        value: NodeId,
    },
    Apply {
        callable: SymbolId,
        arguments: Vec<NodeId>,
    },
    Bind {
        binding: SymbolId,
        value: NodeId,
        body: NodeId,
    },
    MatchResult {
        value: NodeId,
        ok_binding: SymbolId,
        ok_body: NodeId,
        error_binding: SymbolId,
        error_body: NodeId,
    },
    EffectRequest {
        operation: SymbolId,
        arguments: Vec<NodeId>,
    },
    Sequence {
        first: NodeId,
        second: NodeId,
    },
    Add {
        left: NodeId,
        right: NodeId,
    },
    Equal {
        left: NodeId,
        right: NodeId,
    },
    Verify {
        predicate: NodeId,
    },
}

impl IrNodeKind {
    #[must_use]
    pub fn tag(&self) -> &'static str {
        match self {
            Self::Constant { .. } => "constant",
            Self::Input { .. } => "input",
            Self::RecordProduct { .. } => "record_product",
            Self::Project { .. } => "project",
            Self::Ok { .. } => "ok",
            Self::Error { .. } => "error",
            Self::Apply { .. } => "apply",
            Self::Bind { .. } => "bind",
            Self::MatchResult { .. } => "match_result",
            Self::EffectRequest { .. } => "effect_request",
            Self::Sequence { .. } => "sequence",
            Self::Add { .. } => "add",
            Self::Equal { .. } => "equal",
            Self::Verify { .. } => "verify",
        }
    }
}

/// Lower an authorized source module into normalized typed task IR.
///
/// # Errors
///
/// Returns deterministic internal-semantic diagnostics if an expected resolved
/// identity or expression type is missing, or if the resulting graph violates
/// an IR invariant.
pub fn lower(module: &AuthorizedModule) -> Result<TypedTaskIr, Vec<Diagnostic>> {
    let mut lowering = Lowering::new(module);
    lowering.lower_callables();
    sort_diagnostics(&mut lowering.diagnostics);
    if !lowering.diagnostics.is_empty() {
        return Err(lowering.diagnostics);
    }
    let ir = TypedTaskIr {
        version: TASK_IR_VERSION.to_owned(),
        module: module.symbols.module.clone(),
        callables: lowering.callables,
        nodes: lowering.nodes,
    };
    validate(
        &ir,
        &module.types.signatures,
        &module.types.records,
        &module.types.results,
    )?;
    Ok(ir)
}

struct Lowering<'a> {
    module: &'a AuthorizedModule,
    callables: BTreeMap<SymbolId, IrCallable>,
    nodes: BTreeMap<NodeId, IrNode>,
    next_node: BTreeMap<SymbolId, u32>,
    diagnostics: Vec<Diagnostic>,
}

impl<'a> Lowering<'a> {
    fn new(module: &'a AuthorizedModule) -> Self {
        Self {
            module,
            callables: BTreeMap::new(),
            nodes: BTreeMap::new(),
            next_node: BTreeMap::new(),
            diagnostics: Vec::new(),
        }
    }

    fn lower_callables(&mut self) {
        for declaration in &self.module.ast.declarations {
            match &declaration.node {
                DeclarationAst::Function(function) => {
                    let Some(id) = self.definition_at(&function.name.origin, SymbolKind::Function)
                    else {
                        self.missing("function identity", &function.name.origin);
                        continue;
                    };
                    let Some(signature) = self.module.types.signatures.get(&id).cloned() else {
                        self.missing("function signature", &function.name.origin);
                        continue;
                    };
                    let parameters = self.lower_parameters(&function.parameters, &signature);
                    if let Some(root) = self.lower_expression(&id, &function.body) {
                        self.callables.insert(
                            id.clone(),
                            IrCallable {
                                id: id.clone(),
                                kind: IrCallableKind::PureArrow,
                                parameters,
                                result: signature.result,
                                root,
                                effects: self.effects_for(&id),
                                requirements: RequirementSet::default(),
                                verifier: None,
                                verifier_id: None,
                                result_binding: None,
                                origin: declaration.origin.clone(),
                            },
                        );
                    }
                }
                DeclarationAst::Task(task) => {
                    let Some(id) = self.definition_at(&task.name.origin, SymbolKind::Task) else {
                        self.missing("task identity", &task.name.origin);
                        continue;
                    };
                    let Some(signature) = self.module.types.signatures.get(&id).cloned() else {
                        self.missing("task signature", &task.name.origin);
                        continue;
                    };
                    let parameters = self.lower_parameters(&task.parameters, &signature);
                    let root = self.lower_expression(&id, &task.body);
                    let result_binding = self
                        .definition_at(&task.ensures.origin, SymbolKind::Local)
                        .or_else(|| {
                            self.module
                                .symbols
                                .definitions
                                .values()
                                .find(|definition| {
                                    definition.kind == SymbolKind::Local
                                        && definition.name == "result"
                                        && definition.id.0.contains(&id.0)
                                })
                                .map(|definition| definition.id.clone())
                        });
                    let verifier_id = self.module.symbols.verifier_ids.get(&id).cloned();
                    let verifier = self.lower_verifier(&id, &task.ensures);
                    if let (Some(root), Some(verifier)) = (root, verifier) {
                        self.callables.insert(
                            id.clone(),
                            IrCallable {
                                id: id.clone(),
                                kind: IrCallableKind::Task,
                                parameters,
                                result: signature.result,
                                root,
                                effects: self.effects_for(&id),
                                requirements: self
                                    .module
                                    .effects
                                    .task_requirements
                                    .get(&id)
                                    .cloned()
                                    .unwrap_or_default(),
                                verifier: Some(verifier),
                                verifier_id,
                                result_binding,
                                origin: declaration.origin.clone(),
                            },
                        );
                    }
                }
                DeclarationAst::Type(_) | DeclarationAst::Effect(_) => {}
            }
        }
    }

    fn lower_parameters(
        &mut self,
        parameters: &[Spanned<ParameterAst>],
        signature: &Signature,
    ) -> Vec<IrBinding> {
        parameters
            .iter()
            .zip(&signature.parameters)
            .filter_map(|(parameter, value_type)| {
                self.definition_at(&parameter.node.name.origin, SymbolKind::Parameter)
                    .map(|id| IrBinding {
                        id,
                        value_type: value_type.clone(),
                        origin: parameter.origin.clone(),
                    })
                    .or_else(|| {
                        self.missing("parameter identity", &parameter.node.name.origin);
                        None
                    })
            })
            .collect()
    }

    fn lower_verifier(
        &mut self,
        owner: &SymbolId,
        expression: &Spanned<ExpressionAst>,
    ) -> Option<NodeId> {
        let id = self.allocate(owner);
        let predicate = self.lower_expression(owner, expression)?;
        self.nodes.insert(
            id.clone(),
            IrNode {
                id: id.clone(),
                owner: owner.clone(),
                value_type: ValueType::Bool,
                kind: IrNodeKind::Verify { predicate },
                origin: expression.origin.clone(),
            },
        );
        Some(id)
    }

    #[allow(clippy::too_many_lines)]
    fn lower_expression(
        &mut self,
        owner: &SymbolId,
        expression: &Spanned<ExpressionAst>,
    ) -> Option<NodeId> {
        let value_type = self
            .module
            .types
            .expression_types
            .get(&OriginKey::from_origin(&expression.origin))
            .cloned();
        let Some(value_type) = value_type else {
            self.missing("expression type", &expression.origin);
            return None;
        };
        let id = self.allocate(owner);
        let kind = match &expression.node {
            ExpressionAst::Integer { value } => IrNodeKind::Constant {
                literal: IrLiteral::Integer { value: *value },
            },
            ExpressionAst::Boolean { value } => IrNodeKind::Constant {
                literal: IrLiteral::Boolean { value: *value },
            },
            ExpressionAst::String { value } => IrNodeKind::Constant {
                literal: IrLiteral::String {
                    value: value.clone(),
                },
            },
            ExpressionAst::Variable { .. } => IrNodeKind::Input {
                binding: self.use_at(&expression.origin)?.clone(),
            },
            ExpressionAst::Record { fields, .. } => {
                let ValueType::Named { id: type_id } = &value_type else {
                    self.missing("record type identity", &expression.origin);
                    return None;
                };
                let fields: Option<Vec<_>> = fields
                    .iter()
                    .map(|field| {
                        Some(IrRecordField {
                            field: self.use_at(&field.node.name.origin)?.clone(),
                            value: self.lower_expression(owner, &field.node.value)?,
                        })
                    })
                    .collect();
                IrNodeKind::RecordProduct {
                    type_id: type_id.clone(),
                    fields: fields?,
                }
            }
            ExpressionAst::Field { target, .. } => IrNodeKind::Project {
                target: self.lower_expression(owner, target)?,
                field: self.use_at(&expression.origin)?.clone(),
            },
            ExpressionAst::Ok { value } => IrNodeKind::Ok {
                value: self.lower_expression(owner, value)?,
            },
            ExpressionAst::Error { value } => IrNodeKind::Error {
                value: self.lower_expression(owner, value)?,
            },
            ExpressionAst::Call { arguments, .. } => IrNodeKind::Apply {
                callable: self.use_at(&expression.origin)?.clone(),
                arguments: self.lower_many(owner, arguments)?,
            },
            ExpressionAst::Let { name, value, body } => IrNodeKind::Bind {
                binding: self.definition_or_missing(&name.origin, SymbolKind::Local)?,
                value: self.lower_expression(owner, value)?,
                body: self.lower_expression(owner, body)?,
            },
            ExpressionAst::MatchResult {
                value,
                ok_name,
                ok_body,
                error_name,
                error_body,
            } => IrNodeKind::MatchResult {
                value: self.lower_expression(owner, value)?,
                ok_binding: self.definition_or_missing(&ok_name.origin, SymbolKind::Local)?,
                ok_body: self.lower_expression(owner, ok_body)?,
                error_binding: self.definition_or_missing(&error_name.origin, SymbolKind::Local)?,
                error_body: self.lower_expression(owner, error_body)?,
            },
            ExpressionAst::Perform {
                operation,
                arguments,
            } => IrNodeKind::EffectRequest {
                operation: self.use_at(&operation.origin)?.clone(),
                arguments: self.lower_many(owner, arguments)?,
            },
            ExpressionAst::Sequence { first, second } => IrNodeKind::Sequence {
                first: self.lower_expression(owner, first)?,
                second: self.lower_expression(owner, second)?,
            },
            ExpressionAst::Add { left, right } => IrNodeKind::Add {
                left: self.lower_expression(owner, left)?,
                right: self.lower_expression(owner, right)?,
            },
            ExpressionAst::Equal { left, right } => IrNodeKind::Equal {
                left: self.lower_expression(owner, left)?,
                right: self.lower_expression(owner, right)?,
            },
        };
        self.nodes.insert(
            id.clone(),
            IrNode {
                id: id.clone(),
                owner: owner.clone(),
                value_type,
                kind,
                origin: expression.origin.clone(),
            },
        );
        Some(id)
    }

    fn lower_many(
        &mut self,
        owner: &SymbolId,
        expressions: &[Spanned<ExpressionAst>],
    ) -> Option<Vec<NodeId>> {
        expressions
            .iter()
            .map(|expression| self.lower_expression(owner, expression))
            .collect()
    }

    fn allocate(&mut self, owner: &SymbolId) -> NodeId {
        let next = self.next_node.entry(owner.clone()).or_default();
        let id = NodeId(format!("node:{}:{next:04}", owner.0));
        *next += 1;
        id
    }

    fn effects_for(&self, owner: &SymbolId) -> BTreeSet<SymbolId> {
        self.module
            .effects
            .callable_effects
            .get(owner)
            .cloned()
            .unwrap_or_default()
    }

    fn definition_at(&self, origin: &Origin, kind: SymbolKind) -> Option<SymbolId> {
        self.module
            .symbols
            .definitions
            .values()
            .find(|definition| definition.kind == kind && definition.origin == *origin)
            .map(|definition| definition.id.clone())
    }

    fn definition_or_missing(&mut self, origin: &Origin, kind: SymbolKind) -> Option<SymbolId> {
        let result = self.definition_at(origin, kind);
        if result.is_none() {
            self.missing("binding identity", origin);
        }
        result
    }

    fn use_at(&mut self, origin: &Origin) -> Option<&SymbolId> {
        let result = self
            .module
            .symbols
            .uses
            .get(&OriginKey::from_origin(origin));
        if result.is_none() {
            self.missing("resolved use", origin);
        }
        result
    }

    fn missing(&mut self, item: &str, origin: &Origin) {
        self.diagnostics.push(Diagnostic::error(
            "IR_LOWERING_IDENTITY_MISSING",
            format!("authorized source is missing {item}"),
            Some(origin.clone()),
        ));
    }
}

/// Validate all structural and typed invariants of normalized task IR.
///
/// # Errors
///
/// Returns deterministic diagnostics for version, identity, ownership,
/// dangling-edge, typing, effect, verifier, and requirement violations.
pub fn validate(
    ir: &TypedTaskIr,
    signatures: &BTreeMap<SymbolId, Signature>,
    records: &BTreeMap<SymbolId, crate::semantic::RecordShape>,
    results: &BTreeMap<SymbolId, crate::semantic::ResultShape>,
) -> Result<(), Vec<Diagnostic>> {
    let mut diagnostics = Vec::new();
    if ir.version != TASK_IR_VERSION {
        diagnostics.push(Diagnostic::error(
            "IR_VERSION_UNSUPPORTED",
            format!("unsupported task IR version `{}`", ir.version),
            None,
        ));
    }
    for (id, callable) in &ir.callables {
        if id != &callable.id {
            invalid(
                &mut diagnostics,
                "callable map key does not match its identity",
                &callable.origin,
            );
        }
        validate_callable(ir, callable, &mut diagnostics);
    }
    for (id, node) in &ir.nodes {
        if id != &node.id {
            invalid(
                &mut diagnostics,
                "node map key does not match its identity",
                &node.origin,
            );
        }
        if !ir.callables.contains_key(&node.owner) {
            invalid(
                &mut diagnostics,
                "node owner is not a declared callable",
                &node.origin,
            );
        }
        validate_node(ir, node, signatures, records, results, &mut diagnostics);
    }
    sort_diagnostics(&mut diagnostics);
    if diagnostics.is_empty() {
        Ok(())
    } else {
        Err(diagnostics)
    }
}

fn validate_callable(ir: &TypedTaskIr, callable: &IrCallable, diagnostics: &mut Vec<Diagnostic>) {
    validate_edge(ir, callable, &callable.root, "callable root", diagnostics);
    match callable.kind {
        IrCallableKind::PureArrow => {
            if callable.verifier.is_some()
                || callable.verifier_id.is_some()
                || callable.result_binding.is_some()
                || !callable.effects.is_empty()
                || !callable.requirements.entries.is_empty()
            {
                invalid(
                    diagnostics,
                    "pure arrow contains task-only state",
                    &callable.origin,
                );
            }
        }
        IrCallableKind::Task => {
            if let Some(verifier) = &callable.verifier {
                validate_edge(ir, callable, verifier, "task verifier", diagnostics);
                if ir
                    .nodes
                    .get(verifier)
                    .is_some_and(|node| !matches!(node.kind, IrNodeKind::Verify { .. }))
                {
                    invalid(
                        diagnostics,
                        "task verifier edge is not a verifier node",
                        &callable.origin,
                    );
                }
            } else {
                invalid(diagnostics, "task has no verifier node", &callable.origin);
            }
            if callable.verifier_id.is_none() || callable.result_binding.is_none() {
                invalid(
                    diagnostics,
                    "task has incomplete verifier identities",
                    &callable.origin,
                );
            }
            validate_requirement_canonicality(callable, diagnostics);
            for effect in &callable.effects {
                if !callable
                    .requirements
                    .entries
                    .iter()
                    .any(|requirement| &requirement.operation == effect)
                {
                    invalid(
                        diagnostics,
                        "task effect has no canonical requirement",
                        &callable.origin,
                    );
                }
            }
        }
    }
    if ir
        .nodes
        .get(&callable.root)
        .is_some_and(|node| node.value_type != callable.result)
    {
        invalid(
            diagnostics,
            "callable root type differs from its result",
            &callable.origin,
        );
    }
    let owner_nodes: Vec<_> = ir
        .nodes
        .values()
        .filter(|node| node.owner == callable.id)
        .map(|node| node.id.clone())
        .collect();
    for (index, node) in owner_nodes.iter().enumerate() {
        let expected = NodeId(format!("node:{}:{index:04}", callable.id.0));
        if node != &expected {
            invalid(
                diagnostics,
                "callable node identities are not contiguous canonical ordinals",
                &callable.origin,
            );
        }
    }
}

fn validate_requirement_canonicality(callable: &IrCallable, diagnostics: &mut Vec<Diagnostic>) {
    for requirement in &callable.requirements.entries {
        let mut keys = BTreeSet::new();
        for constraint in &requirement.constraints {
            let key = match constraint {
                crate::semantic::RequirementConstraint::EqualsString { key, .. }
                | crate::semantic::RequirementConstraint::EqualsInteger { key, .. }
                | crate::semantic::RequirementConstraint::Prefix { key, .. } => key,
            };
            if key.ends_with("_prefix") || !keys.insert(key) {
                invalid(
                    diagnostics,
                    "task requirement is not canonical",
                    &callable.origin,
                );
            }
        }
        if !callable.effects.contains(&requirement.operation) {
            invalid(
                diagnostics,
                "task requirement names an undeclared effect",
                &callable.origin,
            );
        }
    }
}

#[allow(clippy::too_many_lines)]
fn validate_node(
    ir: &TypedTaskIr,
    node: &IrNode,
    signatures: &BTreeMap<SymbolId, Signature>,
    records: &BTreeMap<SymbolId, crate::semantic::RecordShape>,
    results: &BTreeMap<SymbolId, crate::semantic::ResultShape>,
    diagnostics: &mut Vec<Diagnostic>,
) {
    let owner_callable = ir.callables.get(&node.owner);
    match &node.kind {
        IrNodeKind::Constant { literal } => {
            let literal_type = match literal {
                IrLiteral::Integer { .. } => ValueType::Int,
                IrLiteral::Boolean { .. } => ValueType::Bool,
                IrLiteral::String { .. } => ValueType::String,
            };
            expect_type(node, &literal_type, diagnostics);
        }
        IrNodeKind::Input { binding } => {
            if !ir.callables.values().any(|owner| {
                owner
                    .parameters
                    .iter()
                    .any(|parameter| &parameter.id == binding)
                    || owner.result_binding.as_ref() == Some(binding)
            }) && !binding_declared(ir, binding)
            {
                invalid(
                    diagnostics,
                    "input references an unknown binding",
                    &node.origin,
                );
            }
        }
        IrNodeKind::RecordProduct { type_id, fields } => {
            let Some(shape) = records.get(type_id) else {
                invalid(
                    diagnostics,
                    "record product names an unknown record",
                    &node.origin,
                );
                return;
            };
            let actual: BTreeSet<_> = fields.iter().map(|field| &field.field).collect();
            let expected: BTreeSet<_> = shape.fields.values().map(|(id, _)| id).collect();
            if actual != expected {
                invalid(
                    diagnostics,
                    "record product fields are incomplete",
                    &node.origin,
                );
            }
            for field in fields {
                validate_edge_node(ir, node, &field.value, diagnostics);
                if let Some((_, expected_type)) = shape
                    .fields
                    .values()
                    .find(|(field_id, _)| field_id == &field.field)
                {
                    expect_edge_type(ir, node, &field.value, expected_type, diagnostics);
                }
            }
            expect_type(
                node,
                &ValueType::Named {
                    id: type_id.clone(),
                },
                diagnostics,
            );
        }
        IrNodeKind::Project { target, field } => {
            validate_edge_node(ir, node, target, diagnostics);
            if !records.values().any(|shape| {
                shape.fields.values().any(|(field_id, value_type)| {
                    field_id == field && value_type == &node.value_type
                })
            }) {
                invalid(
                    diagnostics,
                    "projection names an invalid typed field",
                    &node.origin,
                );
            }
        }
        IrNodeKind::Ok { value } | IrNodeKind::Error { value } => {
            validate_edge_node(ir, node, value, diagnostics);
            let Some((ok_type, error_type)) = result_components(&node.value_type, results) else {
                invalid(
                    diagnostics,
                    "result constructor has a non-result type",
                    &node.origin,
                );
                return;
            };
            let expected = if matches!(node.kind, IrNodeKind::Ok { .. }) {
                ok_type
            } else {
                error_type
            };
            expect_edge_type(ir, node, value, &expected, diagnostics);
        }
        IrNodeKind::Apply {
            callable,
            arguments,
        }
        | IrNodeKind::EffectRequest {
            operation: callable,
            arguments,
        } => {
            validate_arguments(ir, node, callable, arguments, signatures, diagnostics);
            if let IrNodeKind::Apply {
                callable: callee, ..
            } = &node.kind
                && let (Some(owner), Some(callee)) = (owner_callable, ir.callables.get(callee))
                && !callee.effects.is_subset(&owner.effects)
            {
                invalid(
                    diagnostics,
                    "application effects escape the owner effect set",
                    &node.origin,
                );
            }
            if let IrNodeKind::EffectRequest { operation, .. } = &node.kind
                && owner_callable.is_none_or(|owner| !owner.effects.contains(operation))
            {
                invalid(
                    diagnostics,
                    "effect request is not declared by its owner",
                    &node.origin,
                );
            }
        }
        IrNodeKind::Bind { value, body, .. } => {
            validate_edge_node(ir, node, value, diagnostics);
            validate_edge_node(ir, node, body, diagnostics);
            expect_same_as_edge(ir, node, body, diagnostics);
        }
        IrNodeKind::MatchResult {
            value,
            ok_body,
            error_body,
            ..
        } => {
            validate_edge_node(ir, node, value, diagnostics);
            validate_edge_node(ir, node, ok_body, diagnostics);
            validate_edge_node(ir, node, error_body, diagnostics);
            if ir.nodes.get(value).is_some_and(|value_node| {
                result_components(&value_node.value_type, results).is_none()
            }) {
                invalid(diagnostics, "match input is not a result", &node.origin);
            }
            expect_same_as_edge(ir, node, ok_body, diagnostics);
            expect_same_as_edge(ir, node, error_body, diagnostics);
        }
        IrNodeKind::Sequence { first, second } => {
            validate_edge_node(ir, node, first, diagnostics);
            validate_edge_node(ir, node, second, diagnostics);
            expect_same_as_edge(ir, node, second, diagnostics);
        }
        IrNodeKind::Add { left, right } => {
            validate_edge_node(ir, node, left, diagnostics);
            validate_edge_node(ir, node, right, diagnostics);
            expect_edge_type(ir, node, left, &ValueType::Int, diagnostics);
            expect_edge_type(ir, node, right, &ValueType::Int, diagnostics);
            expect_type(node, &ValueType::Int, diagnostics);
        }
        IrNodeKind::Equal { left, right } => {
            validate_edge_node(ir, node, left, diagnostics);
            validate_edge_node(ir, node, right, diagnostics);
            if let (Some(left), Some(right)) = (ir.nodes.get(left), ir.nodes.get(right))
                && left.value_type != right.value_type
            {
                invalid(
                    diagnostics,
                    "equality operands have different types",
                    &node.origin,
                );
            }
            expect_type(node, &ValueType::Bool, diagnostics);
        }
        IrNodeKind::Verify { predicate } => {
            validate_edge_node(ir, node, predicate, diagnostics);
            expect_edge_type(ir, node, predicate, &ValueType::Bool, diagnostics);
            expect_type(node, &ValueType::Bool, diagnostics);
        }
    }
}

fn validate_arguments(
    ir: &TypedTaskIr,
    node: &IrNode,
    target: &SymbolId,
    arguments: &[NodeId],
    signatures: &BTreeMap<SymbolId, Signature>,
    diagnostics: &mut Vec<Diagnostic>,
) {
    let Some(signature) = signatures.get(target) else {
        invalid(
            diagnostics,
            "application target has no signature",
            &node.origin,
        );
        return;
    };
    if arguments.len() != signature.parameters.len() {
        invalid(
            diagnostics,
            "application arity differs from its signature",
            &node.origin,
        );
    }
    for (argument, expected) in arguments.iter().zip(&signature.parameters) {
        validate_edge_node(ir, node, argument, diagnostics);
        expect_edge_type(ir, node, argument, expected, diagnostics);
    }
    expect_type(node, &signature.result, diagnostics);
}

fn validate_edge(
    ir: &TypedTaskIr,
    callable: &IrCallable,
    edge: &NodeId,
    description: &str,
    diagnostics: &mut Vec<Diagnostic>,
) {
    match ir.nodes.get(edge) {
        Some(node) if node.owner == callable.id => {}
        Some(_) => invalid(
            diagnostics,
            &format!("{description} belongs to another callable"),
            &callable.origin,
        ),
        None => invalid(
            diagnostics,
            &format!("{description} is dangling"),
            &callable.origin,
        ),
    }
}

fn validate_edge_node(
    ir: &TypedTaskIr,
    owner: &IrNode,
    edge: &NodeId,
    diagnostics: &mut Vec<Diagnostic>,
) {
    match ir.nodes.get(edge) {
        Some(node) if node.owner == owner.owner => {}
        Some(_) => invalid(
            diagnostics,
            "node edge crosses callable ownership",
            &owner.origin,
        ),
        None => invalid(diagnostics, "node contains a dangling edge", &owner.origin),
    }
}

fn expect_same_as_edge(
    ir: &TypedTaskIr,
    node: &IrNode,
    edge: &NodeId,
    diagnostics: &mut Vec<Diagnostic>,
) {
    if ir
        .nodes
        .get(edge)
        .is_some_and(|child| child.value_type != node.value_type)
    {
        invalid(
            diagnostics,
            "node type differs from its result edge",
            &node.origin,
        );
    }
}

fn expect_edge_type(
    ir: &TypedTaskIr,
    node: &IrNode,
    edge: &NodeId,
    expected: &ValueType,
    diagnostics: &mut Vec<Diagnostic>,
) {
    if ir
        .nodes
        .get(edge)
        .is_some_and(|child| &child.value_type != expected)
    {
        invalid(diagnostics, "node edge has the wrong type", &node.origin);
    }
}

fn expect_type(node: &IrNode, expected: &ValueType, diagnostics: &mut Vec<Diagnostic>) {
    if &node.value_type != expected {
        invalid(diagnostics, "node has the wrong result type", &node.origin);
    }
}

fn result_components(
    value_type: &ValueType,
    results: &BTreeMap<SymbolId, crate::semantic::ResultShape>,
) -> Option<(ValueType, ValueType)> {
    match value_type {
        ValueType::Result { ok, error } => Some(((**ok).clone(), (**error).clone())),
        ValueType::Named { id } => results
            .get(id)
            .map(|shape| (shape.ok.clone(), shape.error.clone())),
        ValueType::Int | ValueType::Bool | ValueType::String | ValueType::Product { .. } => None,
    }
}

fn binding_declared(ir: &TypedTaskIr, binding: &SymbolId) -> bool {
    ir.nodes.values().any(|node| match &node.kind {
        IrNodeKind::Bind {
            binding: declared, ..
        } => declared == binding,
        IrNodeKind::MatchResult {
            ok_binding,
            error_binding,
            ..
        } => ok_binding == binding || error_binding == binding,
        IrNodeKind::Constant { .. }
        | IrNodeKind::Input { .. }
        | IrNodeKind::RecordProduct { .. }
        | IrNodeKind::Project { .. }
        | IrNodeKind::Ok { .. }
        | IrNodeKind::Error { .. }
        | IrNodeKind::Apply { .. }
        | IrNodeKind::EffectRequest { .. }
        | IrNodeKind::Sequence { .. }
        | IrNodeKind::Add { .. }
        | IrNodeKind::Equal { .. }
        | IrNodeKind::Verify { .. } => false,
    })
}

fn invalid(diagnostics: &mut Vec<Diagnostic>, message: &str, origin: &Origin) {
    diagnostics.push(Diagnostic::error(
        "IR_INVARIANT_VIOLATION",
        message,
        Some(origin.clone()),
    ));
}

#[cfg(test)]
pub(crate) mod tests {
    use super::{IrNodeKind, lower, validate};
    use crate::{analyze, parse_text};

    pub(crate) const COMPLETE_SOURCE: &str = r#"
module IrDemo version "alang-source-v1" {
  record Pair { left: Int, right: Int }
  effect Trace { operation emit(message: String) -> Bool; }
  fn classify(value: Int) -> Result<Int, String> = ok(value);
  fn fail(value: Int) -> Result<Int, String> = error("failed");
  fn always() -> Bool = true;
  task compute(value: Int) -> Int
    effect [Trace.emit]
    requires [Trace.emit(max_calls = 1)]
    = perform Trace.emit("start") >> let pair = Pair { left: value, right: 1 }; match classify(pair.left) { ok(number) => number + pair.right, error(reason) => 0 }
    ensures result == value + 1;
}
"#;

    pub(crate) fn complete_ir() -> super::TypedTaskIr {
        let module = parse_text("ir.alang", COMPLETE_SOURCE).expect("source must parse");
        let authorized = analyze(&module).expect("source must be authorized");
        lower(&authorized).expect("IR must lower")
    }

    #[test]
    fn ir_lowering_is_deterministic_and_covers_all_promoted_nodes() {
        let left = complete_ir();
        let right = complete_ir();
        assert_eq!(left, right);
        let kinds: std::collections::BTreeSet<_> =
            left.nodes.values().map(|node| node.kind.tag()).collect();
        assert_eq!(kinds.len(), 14);
        assert!(
            left.nodes
                .values()
                .any(|node| matches!(node.kind, IrNodeKind::Verify { .. }))
        );
    }

    #[test]
    fn ir_validation_rejects_dangling_edges_and_missing_verifiers() {
        let mut ir = complete_ir();
        let task_id = ir
            .callables
            .values()
            .find(|callable| callable.kind == super::IrCallableKind::Task)
            .expect("task")
            .id
            .clone();
        ir.callables.get_mut(&task_id).unwrap().verifier = None;
        let root = ir.callables.get(&task_id).unwrap().root.clone();
        ir.nodes.remove(&root);
        let signatures = std::collections::BTreeMap::new();
        let diagnostics = validate(
            &ir,
            &signatures,
            &std::collections::BTreeMap::new(),
            &std::collections::BTreeMap::new(),
        )
        .expect_err("invalid graph must fail");
        assert!(
            diagnostics
                .iter()
                .all(|item| item.code == "IR_INVARIANT_VIOLATION")
        );
    }
}
