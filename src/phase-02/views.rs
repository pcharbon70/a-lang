//! Nonexecuting semantic projections over validated typed task IR.

use crate::ir::{IrCallableKind, IrLiteral, IrNode, IrNodeKind, NodeId, TypedTaskIr};
use crate::semantic::{RequirementSet, SymbolId, ValueType};
use serde::{Deserialize, Serialize};
use std::collections::{BTreeMap, BTreeSet};

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
pub struct SemanticViews {
    pub dry_run: DryRunView,
    pub trace: TraceSkeletonView,
    pub capability_manifest: CapabilityManifestView,
    pub completion: CompletionChecklistView,
    pub explanation: ExplanationView,
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
pub struct DryRunStep {
    pub node: NodeId,
    pub owner: SymbolId,
    pub primitive: String,
    pub result_type: ValueType,
    pub action: String,
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
pub struct DryRunView {
    pub steps: Vec<DryRunStep>,
    pub covered_nodes: BTreeSet<NodeId>,
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
pub struct TraceSkeletonEntry {
    pub node: NodeId,
    pub owner: SymbolId,
    pub event: String,
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
pub struct TraceSkeletonView {
    pub events: Vec<TraceSkeletonEntry>,
    pub covered_nodes: BTreeSet<NodeId>,
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
pub struct TaskCapabilityManifest {
    pub task: SymbolId,
    pub effects: BTreeSet<SymbolId>,
    pub requirements: RequirementSet,
    pub effect_sites: BTreeMap<NodeId, SymbolId>,
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
pub struct CapabilityManifestView {
    pub tasks: BTreeMap<SymbolId, TaskCapabilityManifest>,
    pub covered_nodes: BTreeSet<NodeId>,
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
pub struct CompletionCheck {
    pub task: SymbolId,
    pub verifier_id: SymbolId,
    pub verifier_node: NodeId,
    pub predicate_node: NodeId,
    pub result_binding: SymbolId,
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
pub struct CompletionChecklistView {
    pub tasks: BTreeMap<SymbolId, CompletionCheck>,
    pub covered_nodes: BTreeSet<NodeId>,
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
pub struct ExplanationView {
    pub nodes: BTreeMap<NodeId, String>,
    pub covered_nodes: BTreeSet<NodeId>,
}

/// Derive five deterministic, nonexecuting semantic views from one validated
/// task IR graph. Every view records the complete node set it inspected.
#[must_use]
pub fn derive(ir: &TypedTaskIr) -> SemanticViews {
    let all_nodes: BTreeSet<_> = ir.nodes.keys().cloned().collect();
    let dry_run = DryRunView {
        steps: ir
            .nodes
            .values()
            .map(|node| DryRunStep {
                node: node.id.clone(),
                owner: node.owner.clone(),
                primitive: node.kind.tag().to_owned(),
                result_type: node.value_type.clone(),
                action: dry_run_action(node),
            })
            .collect(),
        covered_nodes: all_nodes.clone(),
    };
    let trace = TraceSkeletonView {
        events: ir
            .nodes
            .values()
            .map(|node| TraceSkeletonEntry {
                node: node.id.clone(),
                owner: node.owner.clone(),
                event: trace_event(node),
            })
            .collect(),
        covered_nodes: all_nodes.clone(),
    };
    let capability_manifest = capability_manifest(ir, all_nodes.clone());
    let completion = completion_checklist(ir, all_nodes.clone());
    let explanation = ExplanationView {
        nodes: ir
            .nodes
            .values()
            .map(|node| (node.id.clone(), explain(node)))
            .collect(),
        covered_nodes: all_nodes,
    };
    SemanticViews {
        dry_run,
        trace,
        capability_manifest,
        completion,
        explanation,
    }
}

fn capability_manifest(
    ir: &TypedTaskIr,
    covered_nodes: BTreeSet<NodeId>,
) -> CapabilityManifestView {
    let tasks = ir
        .callables
        .values()
        .filter(|callable| callable.kind == IrCallableKind::Task)
        .map(|callable| {
            let effect_sites = ir
                .nodes
                .values()
                .filter_map(|node| inspect_manifest_node(node, &callable.id))
                .collect();
            (
                callable.id.clone(),
                TaskCapabilityManifest {
                    task: callable.id.clone(),
                    effects: callable.effects.clone(),
                    requirements: callable.requirements.clone(),
                    effect_sites,
                },
            )
        })
        .collect();
    CapabilityManifestView {
        tasks,
        covered_nodes,
    }
}

fn inspect_manifest_node(node: &IrNode, owner: &SymbolId) -> Option<(NodeId, SymbolId)> {
    match &node.kind {
        IrNodeKind::EffectRequest { operation, .. } if &node.owner == owner => {
            Some((node.id.clone(), operation.clone()))
        }
        IrNodeKind::Constant { .. }
        | IrNodeKind::Input { .. }
        | IrNodeKind::RecordProduct { .. }
        | IrNodeKind::Project { .. }
        | IrNodeKind::Ok { .. }
        | IrNodeKind::Error { .. }
        | IrNodeKind::Apply { .. }
        | IrNodeKind::Bind { .. }
        | IrNodeKind::MatchResult { .. }
        | IrNodeKind::EffectRequest { .. }
        | IrNodeKind::Sequence { .. }
        | IrNodeKind::Add { .. }
        | IrNodeKind::Equal { .. }
        | IrNodeKind::Verify { .. } => None,
    }
}

fn completion_checklist(
    ir: &TypedTaskIr,
    covered_nodes: BTreeSet<NodeId>,
) -> CompletionChecklistView {
    let tasks = ir
        .callables
        .values()
        .filter(|callable| callable.kind == IrCallableKind::Task)
        .filter_map(|callable| {
            let verifier_node = callable.verifier.clone()?;
            let verifier_id = callable.verifier_id.clone()?;
            let result_binding = callable.result_binding.clone()?;
            let IrNodeKind::Verify { predicate } = &ir.nodes.get(&verifier_node)?.kind else {
                return None;
            };
            Some((
                callable.id.clone(),
                CompletionCheck {
                    task: callable.id.clone(),
                    verifier_id,
                    verifier_node,
                    predicate_node: predicate.clone(),
                    result_binding,
                },
            ))
        })
        .collect();
    CompletionChecklistView {
        tasks,
        covered_nodes,
    }
}

fn dry_run_action(node: &IrNode) -> String {
    match &node.kind {
        IrNodeKind::Constant { literal } => format!("produce {}", literal_description(literal)),
        IrNodeKind::Input { binding } => format!("read binding {}", binding.0),
        IrNodeKind::RecordProduct { type_id, fields } => {
            format!("construct {} from {} fields", type_id.0, fields.len())
        }
        IrNodeKind::Project { field, .. } => format!("project field {}", field.0),
        IrNodeKind::Ok { .. } => "construct ok result".to_owned(),
        IrNodeKind::Error { .. } => "construct error result".to_owned(),
        IrNodeKind::Apply { callable, .. } => format!("apply {}", callable.0),
        IrNodeKind::Bind { binding, .. } => format!("bind {} then continue", binding.0),
        IrNodeKind::MatchResult { .. } => "select one exhaustive result branch".to_owned(),
        IrNodeKind::EffectRequest { operation, .. } => {
            format!("request effect {} without executing it", operation.0)
        }
        IrNodeKind::Sequence { .. } => "evaluate first edge before second edge".to_owned(),
        IrNodeKind::Add { .. } => "add two integers".to_owned(),
        IrNodeKind::Equal { .. } => "compare two same-typed values".to_owned(),
        IrNodeKind::Verify { .. } => "evaluate the completion predicate".to_owned(),
    }
}

fn trace_event(node: &IrNode) -> String {
    match &node.kind {
        IrNodeKind::Constant { .. } => "value.constant".to_owned(),
        IrNodeKind::Input { .. } => "binding.read".to_owned(),
        IrNodeKind::RecordProduct { .. } => "product.construct".to_owned(),
        IrNodeKind::Project { .. } => "product.project".to_owned(),
        IrNodeKind::Ok { .. } => "result.ok".to_owned(),
        IrNodeKind::Error { .. } => "result.error".to_owned(),
        IrNodeKind::Apply { .. } => "arrow.apply".to_owned(),
        IrNodeKind::Bind { .. } => "composition.bind".to_owned(),
        IrNodeKind::MatchResult { .. } => "result.match".to_owned(),
        IrNodeKind::EffectRequest { .. } => "effect.request".to_owned(),
        IrNodeKind::Sequence { .. } => "composition.sequence".to_owned(),
        IrNodeKind::Add { .. } => "primitive.add".to_owned(),
        IrNodeKind::Equal { .. } => "primitive.equal".to_owned(),
        IrNodeKind::Verify { .. } => "completion.verify".to_owned(),
    }
}

fn explain(node: &IrNode) -> String {
    match &node.kind {
        IrNodeKind::Constant { literal } => format!(
            "{} deterministically yields {}.",
            node.id.0,
            literal_description(literal)
        ),
        IrNodeKind::Input { binding } => {
            format!("{} reads lexical binding {}.", node.id.0, binding.0)
        }
        IrNodeKind::RecordProduct { type_id, fields } => format!(
            "{} constructs product {} from {} ordered inputs.",
            node.id.0,
            type_id.0,
            fields.len()
        ),
        IrNodeKind::Project { field, .. } => {
            format!("{} projects field {} from a product.", node.id.0, field.0)
        }
        IrNodeKind::Ok { .. } => format!("{} injects a value into the ok branch.", node.id.0),
        IrNodeKind::Error { .. } => {
            format!("{} injects a value into the error branch.", node.id.0)
        }
        IrNodeKind::Apply { callable, .. } => {
            format!("{} applies typed arrow {}.", node.id.0, callable.0)
        }
        IrNodeKind::Bind { binding, .. } => format!(
            "{} evaluates a value, binds {}, then evaluates its body.",
            node.id.0, binding.0
        ),
        IrNodeKind::MatchResult { .. } => {
            format!(
                "{} eliminates a result through both alternatives.",
                node.id.0
            )
        }
        IrNodeKind::EffectRequest { operation, .. } => format!(
            "{} describes request {} but this view does not perform it.",
            node.id.0, operation.0
        ),
        IrNodeKind::Sequence { .. } => {
            format!("{} sequences two computations left to right.", node.id.0)
        }
        IrNodeKind::Add { .. } => format!("{} applies checked integer addition.", node.id.0),
        IrNodeKind::Equal { .. } => format!("{} compares two same-typed values.", node.id.0),
        IrNodeKind::Verify { .. } => {
            format!("{} checks the task completion predicate.", node.id.0)
        }
    }
}

fn literal_description(literal: &IrLiteral) -> String {
    match literal {
        IrLiteral::Integer { value } => format!("integer {value}"),
        IrLiteral::Boolean { value } => format!("Boolean {value}"),
        IrLiteral::String { value } => format!("string {value}"),
    }
}

#[cfg(test)]
mod tests {
    use super::derive;
    use crate::ir::tests::complete_ir;

    #[test]
    fn views_are_deterministic_and_each_covers_every_ir_primitive_instance() {
        let ir = complete_ir();
        let left = derive(&ir);
        let right = derive(&ir);
        assert_eq!(left, right);
        let expected: std::collections::BTreeSet<_> = ir.nodes.keys().cloned().collect();
        assert_eq!(left.dry_run.covered_nodes, expected);
        assert_eq!(left.trace.covered_nodes, expected);
        assert_eq!(left.capability_manifest.covered_nodes, expected);
        assert_eq!(left.completion.covered_nodes, expected);
        assert_eq!(left.explanation.covered_nodes, expected);
        assert_eq!(left.dry_run.steps.len(), ir.nodes.len());
        assert_eq!(left.trace.events.len(), ir.nodes.len());
        assert_eq!(left.explanation.nodes.len(), ir.nodes.len());
        assert_eq!(left.capability_manifest.tasks.len(), 1);
        assert_eq!(left.completion.tasks.len(), 1);
    }
}
