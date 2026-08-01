//! Nondeployable, deterministic IR evaluator for tests and differential checks.
//!
//! This module has no filesystem, network, process, clock, randomness, or host
//! callback API. It consumes only explicit values and fixture effect results.
//! Production execution gates must reject its output as execution evidence.

use crate::ir::{IrCallable, IrCallableKind, IrLiteral, IrNodeKind, NodeId, TypedTaskIr};
use crate::semantic::{SymbolId, ValueType};
use serde::{Deserialize, Serialize};
use std::collections::BTreeMap;

pub const NONDEPLOYABLE_REFERENCE_EVALUATOR: bool = true;
pub const MAX_REFERENCE_STEPS: u64 = 100_000;

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(tag = "kind", rename_all = "snake_case")]
pub enum ReferenceValue {
    Integer {
        value: i64,
    },
    Boolean {
        value: bool,
    },
    String {
        value: String,
    },
    Opaque {
        type_id: SymbolId,
        value: String,
    },
    Record {
        type_id: SymbolId,
        fields: BTreeMap<SymbolId, ReferenceValue>,
    },
    Ok {
        value: Box<ReferenceValue>,
    },
    Error {
        value: Box<ReferenceValue>,
    },
}

#[derive(Clone, Debug, Default, Deserialize, Eq, PartialEq, Serialize)]
pub struct EffectFixture {
    pub results: BTreeMap<NodeId, Vec<ReferenceValue>>,
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(tag = "kind", rename_all = "snake_case")]
pub enum ReferenceObservation {
    EffectRequest {
        node: NodeId,
        operation: SymbolId,
        arguments: Vec<ReferenceValue>,
        fixture_result: ReferenceValue,
    },
    Verification {
        callable: SymbolId,
        verifier: NodeId,
        passed: bool,
    },
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
pub struct ReferenceOutcome {
    pub task: SymbolId,
    pub result: ReferenceValue,
    pub completion: bool,
    pub observations: Vec<ReferenceObservation>,
    pub steps: u64,
    pub nondeployable: bool,
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
pub struct ReferenceError {
    pub code: String,
    pub message: String,
    pub node: Option<NodeId>,
}

impl ReferenceError {
    fn new(code: &str, message: impl Into<String>, node: Option<NodeId>) -> Self {
        Self {
            code: code.to_owned(),
            message: message.into(),
            node,
        }
    }
}

/// Evaluate one task against explicit input and effect-result fixtures.
///
/// # Errors
///
/// Returns a bounded reference error for unknown identities, invalid inputs,
/// missing fixture results, failed primitive operations, or exhausted steps.
/// This API never performs a host effect and is not a production interpreter.
pub fn evaluate_task(
    ir: &TypedTaskIr,
    task: &SymbolId,
    arguments: Vec<ReferenceValue>,
    fixture: &EffectFixture,
    step_limit: u64,
) -> Result<ReferenceOutcome, ReferenceError> {
    if step_limit == 0 || step_limit > MAX_REFERENCE_STEPS {
        return Err(ReferenceError::new(
            "REFERENCE_STEP_LIMIT_INVALID",
            format!("step limit must be between 1 and {MAX_REFERENCE_STEPS}"),
            None,
        ));
    }
    let callable = ir.callables.get(task).ok_or_else(|| {
        ReferenceError::new(
            "REFERENCE_TASK_UNKNOWN",
            format!("unknown task `{}`", task.0),
            None,
        )
    })?;
    if callable.kind != IrCallableKind::Task {
        return Err(ReferenceError::new(
            "REFERENCE_TASK_REQUIRED",
            format!("`{}` is not a task", task.0),
            None,
        ));
    }
    let mut evaluator = Evaluator {
        ir,
        fixture,
        fixture_cursors: BTreeMap::new(),
        observations: Vec::new(),
        steps: 0,
        step_limit,
    };
    let (result, completion) = evaluator.eval_callable(callable, arguments)?;
    Ok(ReferenceOutcome {
        task: task.clone(),
        result,
        completion: completion.unwrap_or(false),
        observations: evaluator.observations,
        steps: evaluator.steps,
        nondeployable: NONDEPLOYABLE_REFERENCE_EVALUATOR,
    })
}

struct Evaluator<'a> {
    ir: &'a TypedTaskIr,
    fixture: &'a EffectFixture,
    fixture_cursors: BTreeMap<NodeId, usize>,
    observations: Vec<ReferenceObservation>,
    steps: u64,
    step_limit: u64,
}

impl Evaluator<'_> {
    fn eval_callable(
        &mut self,
        callable: &IrCallable,
        arguments: Vec<ReferenceValue>,
    ) -> Result<(ReferenceValue, Option<bool>), ReferenceError> {
        if arguments.len() != callable.parameters.len() {
            return Err(ReferenceError::new(
                "REFERENCE_ARITY_MISMATCH",
                format!(
                    "`{}` expects {} arguments but received {}",
                    callable.id.0,
                    callable.parameters.len(),
                    arguments.len()
                ),
                None,
            ));
        }
        let mut environment = BTreeMap::new();
        for (parameter, value) in callable.parameters.iter().zip(arguments) {
            if !value_matches_type(&value, &parameter.value_type) {
                return Err(ReferenceError::new(
                    "REFERENCE_INPUT_TYPE_MISMATCH",
                    format!("input for `{}` has the wrong type", parameter.id.0),
                    None,
                ));
            }
            environment.insert(parameter.id.clone(), value);
        }
        let result = self.eval_node(&callable.root, &mut environment)?;
        if !value_matches_type(&result, &callable.result) {
            return Err(ReferenceError::new(
                "REFERENCE_RESULT_TYPE_MISMATCH",
                format!("`{}` produced the wrong result type", callable.id.0),
                Some(callable.root.clone()),
            ));
        }
        let completion = if let (Some(verifier), Some(result_binding)) =
            (&callable.verifier, &callable.result_binding)
        {
            environment.insert(result_binding.clone(), result.clone());
            let verified = self.eval_node(verifier, &mut environment)?;
            let ReferenceValue::Boolean { value: passed } = verified else {
                return Err(ReferenceError::new(
                    "REFERENCE_VERIFIER_TYPE_MISMATCH",
                    "completion verifier did not produce Bool",
                    Some(verifier.clone()),
                ));
            };
            self.observations.push(ReferenceObservation::Verification {
                callable: callable.id.clone(),
                verifier: verifier.clone(),
                passed,
            });
            Some(passed)
        } else {
            None
        };
        Ok((result, completion))
    }

    #[allow(clippy::too_many_lines)]
    fn eval_node(
        &mut self,
        id: &NodeId,
        environment: &mut BTreeMap<SymbolId, ReferenceValue>,
    ) -> Result<ReferenceValue, ReferenceError> {
        self.tick(id)?;
        let node = self.ir.nodes.get(id).ok_or_else(|| {
            ReferenceError::new(
                "REFERENCE_NODE_UNKNOWN",
                format!("unknown node `{}`", id.0),
                Some(id.clone()),
            )
        })?;
        match &node.kind {
            IrNodeKind::Constant { literal } => Ok(match literal {
                IrLiteral::Integer { value } => ReferenceValue::Integer { value: *value },
                IrLiteral::Boolean { value } => ReferenceValue::Boolean { value: *value },
                IrLiteral::String { value } => ReferenceValue::String {
                    value: value.clone(),
                },
            }),
            IrNodeKind::Input { binding } => environment.get(binding).cloned().ok_or_else(|| {
                ReferenceError::new(
                    "REFERENCE_BINDING_UNAVAILABLE",
                    format!("binding `{}` has no value", binding.0),
                    Some(id.clone()),
                )
            }),
            IrNodeKind::RecordProduct { type_id, fields } => {
                let mut values = BTreeMap::new();
                for field in fields {
                    values.insert(
                        field.field.clone(),
                        self.eval_node(&field.value, environment)?,
                    );
                }
                Ok(ReferenceValue::Record {
                    type_id: type_id.clone(),
                    fields: values,
                })
            }
            IrNodeKind::Project { target, field } => {
                let value = self.eval_node(target, environment)?;
                let ReferenceValue::Record { fields, .. } = value else {
                    return Err(ReferenceError::new(
                        "REFERENCE_PROJECT_NONRECORD",
                        "projection target is not a record",
                        Some(id.clone()),
                    ));
                };
                fields.get(field).cloned().ok_or_else(|| {
                    ReferenceError::new(
                        "REFERENCE_FIELD_UNAVAILABLE",
                        format!("record field `{}` has no value", field.0),
                        Some(id.clone()),
                    )
                })
            }
            IrNodeKind::Ok { value } => Ok(ReferenceValue::Ok {
                value: Box::new(self.eval_node(value, environment)?),
            }),
            IrNodeKind::Error { value } => Ok(ReferenceValue::Error {
                value: Box::new(self.eval_node(value, environment)?),
            }),
            IrNodeKind::Apply {
                callable,
                arguments,
            } => {
                let arguments = self.eval_many(arguments, environment)?;
                let callable = self.ir.callables.get(callable).cloned().ok_or_else(|| {
                    ReferenceError::new(
                        "REFERENCE_CALLABLE_UNKNOWN",
                        "application target is unknown",
                        Some(id.clone()),
                    )
                })?;
                self.eval_callable(&callable, arguments)
                    .map(|(result, _completion)| result)
            }
            IrNodeKind::Bind {
                binding,
                value,
                body,
            } => {
                let value = self.eval_node(value, environment)?;
                let previous = environment.insert(binding.clone(), value);
                let result = self.eval_node(body, environment);
                restore(environment, binding, previous);
                result
            }
            IrNodeKind::MatchResult {
                value,
                ok_binding,
                ok_body,
                error_binding,
                error_body,
            } => match self.eval_node(value, environment)? {
                ReferenceValue::Ok { value } => {
                    let previous = environment.insert(ok_binding.clone(), *value);
                    let result = self.eval_node(ok_body, environment);
                    restore(environment, ok_binding, previous);
                    result
                }
                ReferenceValue::Error { value } => {
                    let previous = environment.insert(error_binding.clone(), *value);
                    let result = self.eval_node(error_body, environment);
                    restore(environment, error_binding, previous);
                    result
                }
                _ => Err(ReferenceError::new(
                    "REFERENCE_MATCH_NONRESULT",
                    "result match input is not a result value",
                    Some(id.clone()),
                )),
            },
            IrNodeKind::EffectRequest {
                operation,
                arguments,
            } => {
                let arguments = self.eval_many(arguments, environment)?;
                let cursor = self.fixture_cursors.entry(id.clone()).or_default();
                let result = self
                    .fixture
                    .results
                    .get(id)
                    .and_then(|values| values.get(*cursor))
                    .cloned()
                    .ok_or_else(|| {
                        ReferenceError::new(
                            "REFERENCE_EFFECT_FIXTURE_MISSING",
                            format!("effect node `{}` has no fixture result", id.0),
                            Some(id.clone()),
                        )
                    })?;
                *cursor += 1;
                if !value_matches_type(&result, &node.value_type) {
                    return Err(ReferenceError::new(
                        "REFERENCE_EFFECT_FIXTURE_TYPE_MISMATCH",
                        "effect fixture result has the wrong type",
                        Some(id.clone()),
                    ));
                }
                self.observations.push(ReferenceObservation::EffectRequest {
                    node: id.clone(),
                    operation: operation.clone(),
                    arguments,
                    fixture_result: result.clone(),
                });
                Ok(result)
            }
            IrNodeKind::Sequence { first, second } => {
                self.eval_node(first, environment)?;
                self.eval_node(second, environment)
            }
            IrNodeKind::Add { left, right } => {
                let left = self.eval_node(left, environment)?;
                let right = self.eval_node(right, environment)?;
                let (
                    ReferenceValue::Integer { value: left },
                    ReferenceValue::Integer { value: right },
                ) = (left, right)
                else {
                    return Err(ReferenceError::new(
                        "REFERENCE_ADD_NONINTEGER",
                        "addition operands are not integers",
                        Some(id.clone()),
                    ));
                };
                left.checked_add(right)
                    .map(|value| ReferenceValue::Integer { value })
                    .ok_or_else(|| {
                        ReferenceError::new(
                            "REFERENCE_INTEGER_OVERFLOW",
                            "integer addition overflowed",
                            Some(id.clone()),
                        )
                    })
            }
            IrNodeKind::Equal { left, right } => Ok(ReferenceValue::Boolean {
                value: self.eval_node(left, environment)? == self.eval_node(right, environment)?,
            }),
            IrNodeKind::Verify { predicate } => self.eval_node(predicate, environment),
        }
    }

    fn eval_many(
        &mut self,
        nodes: &[NodeId],
        environment: &mut BTreeMap<SymbolId, ReferenceValue>,
    ) -> Result<Vec<ReferenceValue>, ReferenceError> {
        nodes
            .iter()
            .map(|node| self.eval_node(node, environment))
            .collect()
    }

    fn tick(&mut self, node: &NodeId) -> Result<(), ReferenceError> {
        self.steps += 1;
        if self.steps > self.step_limit {
            Err(ReferenceError::new(
                "REFERENCE_STEP_LIMIT_EXCEEDED",
                format!("reference evaluation exceeded {} steps", self.step_limit),
                Some(node.clone()),
            ))
        } else {
            Ok(())
        }
    }
}

fn restore(
    environment: &mut BTreeMap<SymbolId, ReferenceValue>,
    binding: &SymbolId,
    previous: Option<ReferenceValue>,
) {
    if let Some(previous) = previous {
        environment.insert(binding.clone(), previous);
    } else {
        environment.remove(binding);
    }
}

fn value_matches_type(value: &ReferenceValue, value_type: &ValueType) -> bool {
    match (value, value_type) {
        (ReferenceValue::Integer { .. }, ValueType::Int)
        | (ReferenceValue::Boolean { .. }, ValueType::Bool)
        | (ReferenceValue::String { .. }, ValueType::String)
        | (ReferenceValue::Ok { .. } | ReferenceValue::Error { .. }, ValueType::Named { .. }) => {
            true
        }
        (
            ReferenceValue::Opaque { type_id, .. } | ReferenceValue::Record { type_id, .. },
            ValueType::Named { id },
        ) => type_id == id,
        (ReferenceValue::Ok { value }, ValueType::Result { ok, error: _error }) => {
            value_matches_type(value, ok)
        }
        (ReferenceValue::Error { value }, ValueType::Result { ok: _ok, error }) => {
            value_matches_type(value, error)
        }
        _ => false,
    }
}

#[cfg(test)]
mod tests {
    use super::{EffectFixture, ReferenceObservation, ReferenceValue, evaluate_task};
    use crate::ir::{IrCallableKind, IrNodeKind, tests::complete_ir};
    use std::collections::BTreeMap;

    #[test]
    fn reference_evaluator_is_bounded_deterministic_and_consumes_only_fixtures() {
        let ir = complete_ir();
        let task = ir
            .callables
            .values()
            .find(|callable| callable.kind == IrCallableKind::Task)
            .expect("task");
        let effect = ir
            .nodes
            .values()
            .find(|node| matches!(node.kind, IrNodeKind::EffectRequest { .. }))
            .expect("effect node");
        let fixture = EffectFixture {
            results: BTreeMap::from([(
                effect.id.clone(),
                vec![ReferenceValue::Boolean { value: true }],
            )]),
        };
        let run = || {
            evaluate_task(
                &ir,
                &task.id,
                vec![ReferenceValue::Integer { value: 41 }],
                &fixture,
                1_000,
            )
            .expect("reference evaluation must pass")
        };
        let left = run();
        let right = run();
        assert_eq!(left, right);
        assert_eq!(left.result, ReferenceValue::Integer { value: 42 });
        assert!(left.completion);
        assert!(left.nondeployable);
        assert!(
            left.observations.iter().any(|observation| matches!(
                observation,
                ReferenceObservation::EffectRequest { .. }
            ))
        );
    }

    #[test]
    fn reference_evaluator_rejects_invalid_and_exhausted_step_limits() {
        let ir = complete_ir();
        let task = ir
            .callables
            .values()
            .find(|callable| callable.kind == IrCallableKind::Task)
            .expect("task");
        let invalid = evaluate_task(
            &ir,
            &task.id,
            vec![ReferenceValue::Integer { value: 1 }],
            &EffectFixture::default(),
            0,
        )
        .expect_err("zero limit must fail");
        assert_eq!(invalid.code, "REFERENCE_STEP_LIMIT_INVALID");
        let exhausted = evaluate_task(
            &ir,
            &task.id,
            vec![ReferenceValue::Integer { value: 1 }],
            &EffectFixture::default(),
            1,
        )
        .expect_err("small limit must fail");
        assert_eq!(exhausted.code, "REFERENCE_STEP_LIMIT_EXCEEDED");
    }
}
