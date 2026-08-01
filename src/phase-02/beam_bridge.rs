use crate::diagnostic::{Diagnostic, sort_diagnostics};
use crate::ir::{IrCallableKind, IrLiteral, IrNodeKind, NodeId, TypedTaskIr};
use crate::semantic::{SymbolId, ValueType};
use serde::{Deserialize, Serialize};
use std::collections::BTreeMap;

pub const PHASE1_FIXTURE_BYTES: &[u8] = include_bytes!("../phase-01/semantic-fixture.config");

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
pub struct Phase1BridgeManifest {
    pub format: String,
    pub source_ir_version: String,
    pub target_profile: String,
    pub module: SymbolId,
    pub task: SymbolId,
    pub lowered_nodes: BTreeMap<NodeId, String>,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct Phase1BridgeOutput {
    pub fixture_bytes: Vec<u8>,
    pub manifest: Phase1BridgeManifest,
}

/// Lower the closed Phase 2 successor demo profile to the exact typed Phase 1
/// semantic fixture consumed by the OTP 29 Abstract Format adapter.
///
/// # Errors
///
/// Rejects any graph outside the closed profile, including additional
/// callables, effects, requirements, nodes, operands, or verifier semantics.
pub fn lower_counter_profile(ir: &TypedTaskIr) -> Result<Phase1BridgeOutput, Vec<Diagnostic>> {
    let mut diagnostics = Vec::new();
    if ir.module != SymbolId("module:Counter".to_owned()) {
        bridge_error(
            &mut diagnostics,
            "the Phase 1 bridge accepts only module Counter",
            None,
        );
    }
    let task_id = SymbolId("task:Counter.successor/1".to_owned());
    let Some(task) = ir.callables.get(&task_id) else {
        bridge_error(
            &mut diagnostics,
            "the Phase 1 bridge requires task Counter.successor/1",
            None,
        );
        return Err(diagnostics);
    };
    if ir.callables.len() != 1
        || task.kind != IrCallableKind::Task
        || task.parameters.len() != 1
        || task.parameters[0].value_type != ValueType::Int
        || task.result != ValueType::Int
        || !task.effects.is_empty()
        || !task.requirements.entries.is_empty()
    {
        bridge_error(
            &mut diagnostics,
            "successor task signature or authority differs from the closed bridge profile",
            Some(task.origin.clone()),
        );
    }
    let parameter = task.parameters.first().map(|binding| binding.id.clone());
    if let Some(parameter) = &parameter {
        validate_successor_expression(ir, &task.root, parameter, &mut diagnostics);
    }
    if let (Some(verifier), Some(result_binding), Some(parameter)) =
        (&task.verifier, &task.result_binding, &parameter)
    {
        validate_successor_verifier(ir, verifier, result_binding, parameter, &mut diagnostics);
    } else {
        bridge_error(
            &mut diagnostics,
            "successor task is missing its completion verifier identities",
            Some(task.origin.clone()),
        );
    }
    let reachable = reachable_nodes(ir, &task.root, task.verifier.as_ref());
    let owner_nodes: Vec<_> = ir
        .nodes
        .values()
        .filter(|node| node.owner == task.id)
        .map(|node| node.id.clone())
        .collect();
    if reachable.len() != owner_nodes.len()
        || owner_nodes.iter().any(|node| !reachable.contains_key(node))
    {
        bridge_error(
            &mut diagnostics,
            "successor task contains unreachable or unlowered nodes",
            Some(task.origin.clone()),
        );
    }
    sort_diagnostics(&mut diagnostics);
    if diagnostics.is_empty() {
        Ok(Phase1BridgeOutput {
            fixture_bytes: PHASE1_FIXTURE_BYTES.to_vec(),
            manifest: Phase1BridgeManifest {
                format: "alang-phase1-bridge-v1".to_owned(),
                source_ir_version: ir.version.clone(),
                target_profile: "phase1_counter_v1".to_owned(),
                module: ir.module.clone(),
                task: task_id,
                lowered_nodes: reachable,
            },
        })
    } else {
        Err(diagnostics)
    }
}

fn validate_successor_expression(
    ir: &TypedTaskIr,
    root: &NodeId,
    parameter: &SymbolId,
    diagnostics: &mut Vec<Diagnostic>,
) {
    let Some(node) = ir.nodes.get(root) else {
        bridge_error(diagnostics, "successor root is dangling", None);
        return;
    };
    let IrNodeKind::Add { left, right } = &node.kind else {
        bridge_error(
            diagnostics,
            "successor body must be integer addition",
            Some(node.origin.clone()),
        );
        return;
    };
    if !is_input(ir, left, parameter) || !is_integer(ir, right, 1) {
        bridge_error(
            diagnostics,
            "successor body must add literal 1 to its input",
            Some(node.origin.clone()),
        );
    }
}

fn validate_successor_verifier(
    ir: &TypedTaskIr,
    verifier: &NodeId,
    result_binding: &SymbolId,
    parameter: &SymbolId,
    diagnostics: &mut Vec<Diagnostic>,
) {
    let Some(verifier_node) = ir.nodes.get(verifier) else {
        bridge_error(diagnostics, "successor verifier is dangling", None);
        return;
    };
    let IrNodeKind::Verify { predicate } = &verifier_node.kind else {
        bridge_error(
            diagnostics,
            "successor verifier must use the verify primitive",
            Some(verifier_node.origin.clone()),
        );
        return;
    };
    let Some(predicate_node) = ir.nodes.get(predicate) else {
        bridge_error(diagnostics, "successor predicate is dangling", None);
        return;
    };
    let IrNodeKind::Equal { left, right } = &predicate_node.kind else {
        bridge_error(
            diagnostics,
            "successor predicate must compare its result",
            Some(predicate_node.origin.clone()),
        );
        return;
    };
    if !is_input(ir, left, result_binding) {
        bridge_error(
            diagnostics,
            "successor predicate must read the reserved result binding",
            Some(predicate_node.origin.clone()),
        );
    }
    let Some(add_node) = ir.nodes.get(right) else {
        bridge_error(
            diagnostics,
            "successor predicate expected value is dangling",
            None,
        );
        return;
    };
    let IrNodeKind::Add {
        left: add_left,
        right: add_right,
    } = &add_node.kind
    else {
        bridge_error(
            diagnostics,
            "successor predicate must compare with input plus one",
            Some(add_node.origin.clone()),
        );
        return;
    };
    if !is_input(ir, add_left, parameter) || !is_integer(ir, add_right, 1) {
        bridge_error(
            diagnostics,
            "successor predicate expected value must be input plus one",
            Some(add_node.origin.clone()),
        );
    }
}

fn is_input(ir: &TypedTaskIr, node: &NodeId, binding: &SymbolId) -> bool {
    ir.nodes.get(node).is_some_and(
        |node| matches!(&node.kind, IrNodeKind::Input { binding: actual } if actual == binding),
    )
}

fn is_integer(ir: &TypedTaskIr, node: &NodeId, expected: i64) -> bool {
    ir.nodes.get(node).is_some_and(|node| {
        matches!(
            node.kind,
            IrNodeKind::Constant {
                literal: IrLiteral::Integer { value }
            } if value == expected
        )
    })
}

fn reachable_nodes(
    ir: &TypedTaskIr,
    root: &NodeId,
    verifier: Option<&NodeId>,
) -> BTreeMap<NodeId, String> {
    let mut reachable = BTreeMap::new();
    visit(ir, root, &mut reachable);
    if let Some(verifier) = verifier {
        visit(ir, verifier, &mut reachable);
    }
    reachable
}

fn visit(ir: &TypedTaskIr, id: &NodeId, reachable: &mut BTreeMap<NodeId, String>) {
    let Some(node) = ir.nodes.get(id) else {
        return;
    };
    if reachable
        .insert(id.clone(), phase1_lowering_name(&node.kind).to_owned())
        .is_some()
    {
        return;
    }
    match &node.kind {
        IrNodeKind::Constant { .. } | IrNodeKind::Input { .. } => {}
        IrNodeKind::Add { left, right } | IrNodeKind::Equal { left, right } => {
            visit(ir, left, reachable);
            visit(ir, right, reachable);
        }
        IrNodeKind::Verify { predicate } => visit(ir, predicate, reachable),
        IrNodeKind::RecordProduct { fields, .. } => {
            for field in fields {
                visit(ir, &field.value, reachable);
            }
        }
        IrNodeKind::Project { target, .. }
        | IrNodeKind::Ok { value: target }
        | IrNodeKind::Error { value: target } => visit(ir, target, reachable),
        IrNodeKind::Apply { arguments, .. } | IrNodeKind::EffectRequest { arguments, .. } => {
            for argument in arguments {
                visit(ir, argument, reachable);
            }
        }
        IrNodeKind::Bind { value, body, .. } => {
            visit(ir, value, reachable);
            visit(ir, body, reachable);
        }
        IrNodeKind::MatchResult {
            value,
            ok_body,
            error_body,
            ..
        } => {
            visit(ir, value, reachable);
            visit(ir, ok_body, reachable);
            visit(ir, error_body, reachable);
        }
        IrNodeKind::Sequence { first, second } => {
            visit(ir, first, reachable);
            visit(ir, second, reachable);
        }
    }
}

fn phase1_lowering_name(kind: &IrNodeKind) -> &'static str {
    match kind {
        IrNodeKind::Constant { .. } => "abstract_literal",
        IrNodeKind::Input { .. } => "abstract_variable",
        IrNodeKind::Add { .. } => "abstract_integer_add",
        IrNodeKind::Equal { .. } => "abstract_exact_comparison",
        IrNodeKind::Verify { .. } => "runtime_success_contract",
        IrNodeKind::RecordProduct { .. }
        | IrNodeKind::Project { .. }
        | IrNodeKind::Ok { .. }
        | IrNodeKind::Error { .. }
        | IrNodeKind::Apply { .. }
        | IrNodeKind::Bind { .. }
        | IrNodeKind::MatchResult { .. }
        | IrNodeKind::EffectRequest { .. }
        | IrNodeKind::Sequence { .. } => "outside_phase1_counter_profile",
    }
}

fn bridge_error(
    diagnostics: &mut Vec<Diagnostic>,
    message: &str,
    origin: Option<crate::source::Origin>,
) {
    diagnostics.push(Diagnostic::error(
        "BEAM_BRIDGE_PROFILE_UNSUPPORTED",
        message,
        origin,
    ));
}

#[cfg(test)]
mod tests {
    use super::{PHASE1_FIXTURE_BYTES, lower_counter_profile};
    use crate::{compile_ir, parse_text};

    pub(crate) fn counter_ir() -> crate::ir::TypedTaskIr {
        let module = parse_text("counter.alang", include_str!("fixtures/counter.alang"))
            .expect("counter source must parse");
        compile_ir(&module).expect("counter source must compile")
    }

    #[test]
    fn beam_bridge_lowers_every_counter_node_to_the_exact_phase1_fixture() {
        let ir = counter_ir();
        let output = lower_counter_profile(&ir).expect("counter profile must lower");
        assert_eq!(output.fixture_bytes, PHASE1_FIXTURE_BYTES);
        assert_eq!(output.manifest.lowered_nodes.len(), ir.nodes.len());
        assert!(
            output
                .manifest
                .lowered_nodes
                .values()
                .all(|lowering| lowering != "outside_phase1_counter_profile")
        );
    }

    #[test]
    fn beam_bridge_rejects_semantic_drift_before_backend_output() {
        let mut ir = counter_ir();
        let task = ir.callables.values_mut().next().expect("task");
        task.effects
            .insert(crate::semantic::SymbolId("operation:drift".to_owned()));
        let diagnostics = lower_counter_profile(&ir).expect_err("drift must fail");
        assert!(
            diagnostics
                .iter()
                .all(|item| item.code == "BEAM_BRIDGE_PROFILE_UNSUPPORTED")
        );
    }
}
