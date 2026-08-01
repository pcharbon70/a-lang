use crate::diagnostic::{Diagnostic, sort_diagnostics};
use crate::semantic::{
    NormalizedRequirement, RequirementConstraint, RequirementSet, SymbolId, canonical_resource_id,
};
use crate::source::{ConstraintAst, Origin, RequirementAst, Spanned};
use std::collections::{BTreeMap, BTreeSet};

impl RequirementSet {
    #[must_use]
    pub fn union(&self, other: &Self) -> Self {
        Self {
            entries: self.entries.union(&other.entries).cloned().collect(),
        }
    }

    #[must_use]
    pub fn subsumes(&self, other: &Self) -> bool {
        other.entries.iter().all(|required| {
            self.entries
                .iter()
                .any(|available| available.subsumes(required))
        })
    }

    /// Serialize a requirement set in its stable ordered JSON form.
    ///
    /// # Errors
    ///
    /// Returns a JSON serialization error if the serializer cannot encode the
    /// normalized requirement representation.
    pub fn canonical_bytes(&self) -> Result<Vec<u8>, serde_json::Error> {
        serde_json::to_vec(self)
    }
}

impl NormalizedRequirement {
    #[must_use]
    pub fn subsumes(&self, other: &Self) -> bool {
        self.resource == other.resource
            && self.operation == other.operation
            && optional_limit_subsumes(self.deadline_ms, other.deadline_ms)
            && optional_limit_subsumes(self.max_calls, other.max_calls)
            && optional_limit_subsumes(self.max_bytes, other.max_bytes)
            && self.constraints.iter().all(|available| {
                other
                    .constraints
                    .iter()
                    .any(|required| constraint_subsumes(available, required))
            })
    }
}

fn optional_limit_subsumes<T: Ord>(available: Option<T>, required: Option<T>) -> bool {
    match (available, required) {
        (None, _) => true,
        (Some(_), None) => false,
        (Some(available), Some(required)) => available >= required,
    }
}

fn constraint_subsumes(
    available: &RequirementConstraint,
    required: &RequirementConstraint,
) -> bool {
    match (available, required) {
        (
            RequirementConstraint::EqualsString {
                key: left_key,
                value: left_value,
            },
            RequirementConstraint::EqualsString {
                key: right_key,
                value: right_value,
            },
        ) => left_key == right_key && left_value == right_value,
        (
            RequirementConstraint::EqualsInteger {
                key: left_key,
                value: left_value,
            },
            RequirementConstraint::EqualsInteger {
                key: right_key,
                value: right_value,
            },
        ) => left_key == right_key && left_value == right_value,
        (
            RequirementConstraint::Prefix {
                key: left_key,
                value: left_value,
            },
            RequirementConstraint::Prefix {
                key: right_key,
                value: right_value,
            }
            | RequirementConstraint::EqualsString {
                key: right_key,
                value: right_value,
            },
        ) => left_key == right_key && right_value.starts_with(left_value),
        _ => false,
    }
}

/// Normalize one task's source requirements into an ordered authority set.
///
/// # Errors
///
/// Returns deterministic diagnostics for duplicate constraints, duplicate
/// requirement entries, and zero resource budgets.
pub fn normalize(
    requirements: &[Spanned<RequirementAst>],
    operation_ids: &BTreeMap<String, SymbolId>,
) -> Result<RequirementSet, Vec<Diagnostic>> {
    let mut entries = BTreeSet::new();
    let mut diagnostics = Vec::new();
    for requirement in requirements {
        let target_name = format!(
            "{}.{}",
            requirement.node.target.node.namespace, requirement.node.target.node.name
        );
        let Some(operation) = operation_ids.get(&target_name).cloned() else {
            diagnostics.push(Diagnostic::error(
                "REQUIREMENT_UNRESOLVED_OPERATION",
                format!("requirement target `{target_name}` has no resolved operation"),
                Some(requirement.node.target.origin.clone()),
            ));
            continue;
        };
        let normalized = normalize_one(&requirement.node, operation, &mut diagnostics);
        if !entries.insert(normalized) {
            diagnostics.push(Diagnostic::error(
                "REQUIREMENT_DUPLICATE",
                format!("duplicate normalized requirement for `{target_name}`"),
                Some(requirement.origin.clone()),
            ));
        }
    }
    sort_diagnostics(&mut diagnostics);
    if diagnostics.is_empty() {
        Ok(RequirementSet { entries })
    } else {
        Err(diagnostics)
    }
}

fn normalize_one(
    requirement: &RequirementAst,
    operation: SymbolId,
    diagnostics: &mut Vec<Diagnostic>,
) -> NormalizedRequirement {
    let mut constraints = BTreeSet::new();
    let mut keys = BTreeMap::<String, Origin>::new();
    for constraint in &requirement.constraints {
        let normalized = normalize_constraint(&constraint.node);
        let key = constraint_key(&normalized).to_owned();
        if let Some(first_origin) = keys.get(&key) {
            diagnostics.push(
                Diagnostic::error(
                    "REQUIREMENT_DUPLICATE_CONSTRAINT",
                    format!("requirement constraint `{key}` is declared more than once"),
                    Some(constraint.origin.clone()),
                )
                .with_label("first constraint is here", first_origin.clone()),
            );
            continue;
        }
        keys.insert(key, constraint.origin.clone());
        constraints.insert(normalized);
    }
    check_nonzero(
        "deadline_ms",
        requirement.deadline_ms,
        &requirement.target.origin,
        diagnostics,
    );
    check_nonzero(
        "max_calls",
        requirement.max_calls,
        &requirement.target.origin,
        diagnostics,
    );
    check_nonzero(
        "max_bytes",
        requirement.max_bytes,
        &requirement.target.origin,
        diagnostics,
    );
    NormalizedRequirement {
        resource: canonical_resource_id(&requirement.target.node.namespace),
        operation,
        constraints,
        deadline_ms: requirement.deadline_ms,
        max_calls: requirement.max_calls,
        max_bytes: requirement.max_bytes,
    }
}

fn normalize_constraint(constraint: &ConstraintAst) -> RequirementConstraint {
    match constraint {
        ConstraintAst::EqualsString { key, value } => RequirementConstraint::EqualsString {
            key: key.clone(),
            value: value.clone(),
        },
        ConstraintAst::EqualsInteger { key, value } => RequirementConstraint::EqualsInteger {
            key: key.clone(),
            value: *value,
        },
        ConstraintAst::Prefix { key, value } => RequirementConstraint::Prefix {
            key: key.strip_suffix("_prefix").unwrap_or(key).to_owned(),
            value: value.clone(),
        },
    }
}

fn constraint_key(constraint: &RequirementConstraint) -> &str {
    match constraint {
        RequirementConstraint::EqualsString { key, .. }
        | RequirementConstraint::EqualsInteger { key, .. }
        | RequirementConstraint::Prefix { key, .. } => key,
    }
}

fn check_nonzero<T>(
    name: &str,
    value: Option<T>,
    origin: &Origin,
    diagnostics: &mut Vec<Diagnostic>,
) where
    T: Default + PartialEq,
{
    if value.is_some_and(|item| item == T::default()) {
        diagnostics.push(Diagnostic::error(
            "REQUIREMENT_ZERO_BUDGET",
            format!("requirement `{name}` must be greater than zero"),
            Some(origin.clone()),
        ));
    }
}

#[cfg(test)]
mod tests {
    use super::normalize;
    use crate::parser::parse;
    use crate::semantic::{
        NormalizedRequirement, RequirementConstraint, RequirementSet, SymbolId,
        canonical_operation_id,
    };
    use crate::source::DeclarationAst;
    use std::collections::{BTreeMap, BTreeSet};

    fn requirement(
        constraints: BTreeSet<RequirementConstraint>,
        max_calls: Option<u32>,
    ) -> NormalizedRequirement {
        NormalizedRequirement {
            resource: SymbolId("resource:workspace/v1".to_owned()),
            operation: canonical_operation_id("Workspace", "write"),
            constraints,
            deadline_ms: Some(1_000),
            max_calls,
            max_bytes: Some(4_096),
        }
    }

    #[test]
    fn requirements_canonical_form_union_equality_subsumption_and_serialization_are_stable() {
        let broad = requirement(
            BTreeSet::from([RequirementConstraint::Prefix {
                key: "path".to_owned(),
                value: "/workspace/".to_owned(),
            }]),
            Some(3),
        );
        let narrow = requirement(
            BTreeSet::from([RequirementConstraint::EqualsString {
                key: "path".to_owned(),
                value: "/workspace/result.txt".to_owned(),
            }]),
            Some(1),
        );
        assert!(broad.subsumes(&narrow));
        assert!(!narrow.subsumes(&broad));
        let left = RequirementSet {
            entries: BTreeSet::from([broad.clone()]),
        };
        let right = RequirementSet {
            entries: BTreeSet::from([narrow.clone()]),
        };
        assert!(left.union(&right).subsumes(&right));
        assert_eq!(left, left.clone());
        assert_eq!(
            left.canonical_bytes().unwrap(),
            left.canonical_bytes().unwrap()
        );
    }

    #[test]
    fn requirements_normalization_rejects_duplicate_constraints_and_zero_budgets() {
        let module = parse(
            "requirements.alang",
            r#"
module Requirements version "alang-source-v1" {
  effect Workspace { operation write(path: String, contents: String) -> Bool; }
  task publish() -> Bool
    effect [Workspace.write]
    requires [Workspace.write(path = "/a", path = "/b", max_calls = 0)]
    = perform Workspace.write("/a", "x")
    ensures result == true;
}
"#,
        )
        .expect("source must parse");
        let task = module
            .declarations
            .iter()
            .find_map(|declaration| match &declaration.node {
                DeclarationAst::Task(task) => Some(task.as_ref()),
                _ => None,
            })
            .expect("task");
        let operations = BTreeMap::from([(
            "Workspace.write".to_owned(),
            canonical_operation_id("Workspace", "write"),
        )]);
        let diagnostics = normalize(&task.requirements, &operations).expect_err("must reject");
        let codes: Vec<_> = diagnostics.iter().map(|item| item.code.as_str()).collect();
        assert!(codes.contains(&"REQUIREMENT_DUPLICATE_CONSTRAINT"));
        assert!(codes.contains(&"REQUIREMENT_ZERO_BUDGET"));
    }
}
