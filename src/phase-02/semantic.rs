use crate::source::{ModuleAst, Origin};
use serde::{Deserialize, Serialize};
use std::collections::{BTreeMap, BTreeSet};

#[derive(Clone, Debug, Deserialize, Eq, Ord, PartialEq, PartialOrd, Serialize)]
pub struct SymbolId(pub String);

#[derive(Clone, Debug, Deserialize, Eq, Ord, PartialEq, PartialOrd, Serialize)]
pub struct OriginKey(pub String);

impl OriginKey {
    #[must_use]
    pub fn from_origin(origin: &Origin) -> Self {
        Self(format!(
            "{}:{}:{}",
            origin.source, origin.start.byte, origin.end.byte
        ))
    }
}

#[derive(Clone, Copy, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum SymbolKind {
    Module,
    Type,
    Constructor,
    Field,
    Function,
    Task,
    Effect,
    Operation,
    Parameter,
    Local,
    Resource,
    Verifier,
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
pub struct Definition {
    pub id: SymbolId,
    pub kind: SymbolKind,
    pub name: String,
    pub arity: Option<usize>,
    pub origin: Origin,
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
pub struct SymbolTable {
    pub module: SymbolId,
    pub definitions: BTreeMap<SymbolId, Definition>,
    pub uses: BTreeMap<OriginKey, SymbolId>,
    pub verifier_ids: BTreeMap<SymbolId, SymbolId>,
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(tag = "kind", rename_all = "snake_case")]
pub enum ValueType {
    Int,
    Bool,
    String,
    Named {
        id: SymbolId,
    },
    Product {
        items: Vec<ValueType>,
    },
    Result {
        ok: Box<ValueType>,
        error: Box<ValueType>,
    },
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
pub struct Signature {
    pub parameters: Vec<ValueType>,
    pub result: ValueType,
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
pub struct RecordShape {
    pub fields: BTreeMap<String, (SymbolId, ValueType)>,
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
pub struct ResultShape {
    pub ok: ValueType,
    pub error: ValueType,
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
pub struct TypeEnvironment {
    pub signatures: BTreeMap<SymbolId, Signature>,
    pub records: BTreeMap<SymbolId, RecordShape>,
    pub results: BTreeMap<SymbolId, ResultShape>,
    pub opaque_types: Vec<SymbolId>,
    pub expression_types: BTreeMap<OriginKey, ValueType>,
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
pub struct ResolvedModule {
    pub ast: ModuleAst,
    pub symbols: SymbolTable,
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
pub struct CheckedModule {
    pub ast: ModuleAst,
    pub symbols: SymbolTable,
    pub types: TypeEnvironment,
}

#[derive(Clone, Debug, Deserialize, Eq, Ord, PartialEq, PartialOrd, Serialize)]
#[serde(tag = "kind", rename_all = "snake_case")]
pub enum RequirementConstraint {
    EqualsString { key: String, value: String },
    EqualsInteger { key: String, value: i64 },
    Prefix { key: String, value: String },
}

#[derive(Clone, Debug, Deserialize, Eq, Ord, PartialEq, PartialOrd, Serialize)]
pub struct NormalizedRequirement {
    pub resource: SymbolId,
    pub operation: SymbolId,
    pub constraints: BTreeSet<RequirementConstraint>,
    pub deadline_ms: Option<u64>,
    pub max_calls: Option<u32>,
    pub max_bytes: Option<u64>,
}

#[derive(Clone, Debug, Default, Deserialize, Eq, PartialEq, Serialize)]
pub struct RequirementSet {
    pub entries: BTreeSet<NormalizedRequirement>,
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
pub struct EffectEnvironment {
    pub callable_effects: BTreeMap<SymbolId, BTreeSet<SymbolId>>,
    pub task_requirements: BTreeMap<SymbolId, RequirementSet>,
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
pub struct AuthorizedModule {
    pub ast: ModuleAst,
    pub symbols: SymbolTable,
    pub types: TypeEnvironment,
    pub effects: EffectEnvironment,
}

#[must_use]
pub fn canonical_operation_id(namespace: &str, name: &str) -> SymbolId {
    match (namespace, name) {
        ("Model", "complete") => SymbolId("operation:model.complete/v1".to_owned()),
        ("Workspace", "write") => SymbolId("operation:workspace.write/v1".to_owned()),
        ("Trace", "emit") => SymbolId("operation:trace.emit/v1".to_owned()),
        _ => SymbolId(format!(
            "operation:{}.{}",
            namespace.to_ascii_lowercase(),
            name.to_ascii_lowercase()
        )),
    }
}

#[must_use]
pub fn canonical_resource_id(namespace: &str) -> SymbolId {
    match namespace {
        "Model" => SymbolId("resource:model/v1".to_owned()),
        "Workspace" => SymbolId("resource:workspace/v1".to_owned()),
        "Trace" => SymbolId("resource:trace/v1".to_owned()),
        _ => SymbolId(format!("resource:{}", namespace.to_ascii_lowercase())),
    }
}
