use serde::{Deserialize, Serialize};

pub const SOURCE_VERSION: &str = "alang-source-v1";
pub const MAX_SOURCE_BYTES: usize = 1024 * 1024;
pub const MAX_IDENTIFIER_BYTES: usize = 64;
pub const MAX_COLLECTION_LENGTH: usize = 1024;
pub const MAX_NESTING_DEPTH: usize = 64;

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(deny_unknown_fields)]
pub struct Position {
    pub byte: u32,
    pub line: u32,
    pub column: u32,
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(deny_unknown_fields)]
pub struct Origin {
    pub source: String,
    pub start: Position,
    pub end: Position,
}

impl Origin {
    #[must_use]
    pub fn merge(left: &Self, right: &Self) -> Self {
        Self {
            source: left.source.clone(),
            start: left.start.clone(),
            end: right.end.clone(),
        }
    }

    #[must_use]
    pub fn synthetic(source: &str) -> Self {
        Self {
            source: source.to_owned(),
            start: Position {
                byte: 0,
                line: 1,
                column: 1,
            },
            end: Position {
                byte: 0,
                line: 1,
                column: 1,
            },
        }
    }
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(deny_unknown_fields)]
pub struct Spanned<T> {
    pub node: T,
    pub origin: Origin,
}

impl<T> Spanned<T> {
    pub fn new(node: T, origin: Origin) -> Self {
        Self { node, origin }
    }
}

pub type Identifier = String;

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(deny_unknown_fields)]
pub struct QualifiedName {
    pub namespace: Identifier,
    pub name: Identifier,
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(deny_unknown_fields)]
pub struct ModuleAst {
    pub version: String,
    pub name: Spanned<Identifier>,
    pub declarations: Vec<Spanned<DeclarationAst>>,
    pub origin: Origin,
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(tag = "kind", rename_all = "snake_case")]
pub enum DeclarationAst {
    Type(TypeDeclarationAst),
    Effect(EffectDeclarationAst),
    Function(FunctionDeclarationAst),
    Task(Box<TaskDeclarationAst>),
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(tag = "form", rename_all = "snake_case")]
pub enum TypeDeclarationAst {
    Opaque {
        name: Spanned<Identifier>,
    },
    Record {
        name: Spanned<Identifier>,
        fields: Vec<Spanned<FieldDeclarationAst>>,
    },
    Result {
        name: Spanned<Identifier>,
        ok: Spanned<TypeAst>,
        error: Spanned<TypeAst>,
    },
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(deny_unknown_fields)]
pub struct FieldDeclarationAst {
    pub name: Spanned<Identifier>,
    pub value_type: Spanned<TypeAst>,
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(deny_unknown_fields)]
pub struct EffectDeclarationAst {
    pub name: Spanned<Identifier>,
    pub operations: Vec<Spanned<OperationDeclarationAst>>,
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(deny_unknown_fields)]
pub struct OperationDeclarationAst {
    pub name: Spanned<Identifier>,
    pub parameters: Vec<Spanned<ParameterAst>>,
    pub result: Spanned<TypeAst>,
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(deny_unknown_fields)]
pub struct ParameterAst {
    pub name: Spanned<Identifier>,
    pub value_type: Spanned<TypeAst>,
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(deny_unknown_fields)]
pub struct FunctionDeclarationAst {
    pub name: Spanned<Identifier>,
    pub parameters: Vec<Spanned<ParameterAst>>,
    pub result: Spanned<TypeAst>,
    pub body: Spanned<ExpressionAst>,
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(deny_unknown_fields)]
pub struct TaskDeclarationAst {
    pub name: Spanned<Identifier>,
    pub parameters: Vec<Spanned<ParameterAst>>,
    pub result: Spanned<TypeAst>,
    pub effects: Vec<Spanned<QualifiedName>>,
    pub requirements: Vec<Spanned<RequirementAst>>,
    pub body: Spanned<ExpressionAst>,
    pub ensures: Spanned<ExpressionAst>,
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(tag = "kind", rename_all = "snake_case")]
pub enum TypeAst {
    Primitive {
        name: PrimitiveType,
    },
    Named {
        name: Identifier,
    },
    Product {
        items: Vec<Spanned<TypeAst>>,
    },
    Result {
        ok: Box<Spanned<TypeAst>>,
        error: Box<Spanned<TypeAst>>,
    },
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum PrimitiveType {
    Int,
    Bool,
    String,
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(deny_unknown_fields)]
pub struct RequirementAst {
    pub target: Spanned<QualifiedName>,
    #[serde(default)]
    pub constraints: Vec<Spanned<ConstraintAst>>,
    pub deadline_ms: Option<u64>,
    pub max_calls: Option<u32>,
    pub max_bytes: Option<u64>,
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(tag = "kind", rename_all = "snake_case")]
pub enum ConstraintAst {
    EqualsString { key: Identifier, value: String },
    EqualsInteger { key: Identifier, value: i64 },
    Prefix { key: Identifier, value: String },
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(tag = "kind", rename_all = "snake_case")]
pub enum ExpressionAst {
    Integer {
        value: i64,
    },
    Boolean {
        value: bool,
    },
    String {
        value: String,
    },
    Variable {
        name: Identifier,
    },
    Record {
        type_name: Identifier,
        fields: Vec<Spanned<RecordFieldAst>>,
    },
    Field {
        target: Box<Spanned<ExpressionAst>>,
        field: Identifier,
    },
    Ok {
        value: Box<Spanned<ExpressionAst>>,
    },
    Error {
        value: Box<Spanned<ExpressionAst>>,
    },
    Call {
        function: Identifier,
        arguments: Vec<Spanned<ExpressionAst>>,
    },
    Let {
        name: Spanned<Identifier>,
        value: Box<Spanned<ExpressionAst>>,
        body: Box<Spanned<ExpressionAst>>,
    },
    MatchResult {
        value: Box<Spanned<ExpressionAst>>,
        ok_name: Spanned<Identifier>,
        ok_body: Box<Spanned<ExpressionAst>>,
        error_name: Spanned<Identifier>,
        error_body: Box<Spanned<ExpressionAst>>,
    },
    Perform {
        operation: Spanned<QualifiedName>,
        arguments: Vec<Spanned<ExpressionAst>>,
    },
    Sequence {
        first: Box<Spanned<ExpressionAst>>,
        second: Box<Spanned<ExpressionAst>>,
    },
    Add {
        left: Box<Spanned<ExpressionAst>>,
        right: Box<Spanned<ExpressionAst>>,
    },
    Equal {
        left: Box<Spanned<ExpressionAst>>,
        right: Box<Spanned<ExpressionAst>>,
    },
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(deny_unknown_fields)]
pub struct RecordFieldAst {
    pub name: Spanned<Identifier>,
    pub value: Spanned<ExpressionAst>,
}
