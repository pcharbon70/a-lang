use crate::diagnostic::{Diagnostic, sort_diagnostics};
use crate::requirements;
use crate::semantic::{
    AuthorizedModule, CheckedModule, EffectEnvironment, NormalizedRequirement, OriginKey,
    RequirementConstraint, RequirementSet, SymbolId, SymbolKind,
};
use crate::source::{DeclarationAst, ExpressionAst, Origin, RequirementAst, Spanned};
use std::collections::{BTreeMap, BTreeSet};

/// Infer closed effects and normalize each task's authority requirements.
///
/// # Errors
///
/// Returns stable diagnostics for recursion, effects escaping pure functions or
/// verifiers, inaccurate annotations, invalid requirements, uncovered effect
/// operations, and operation arguments outside declared authority.
pub fn check(data_checked: CheckedModule) -> Result<AuthorizedModule, Vec<Diagnostic>> {
    let (inferred, requirements, mut diagnostics) = {
        let mut effects = EffectChecker::new(&data_checked);
        effects.collect_callables();
        effects.reject_cycles();
        effects.infer_effects();
        effects.check_declarations();
        let requirements = effects.check_requirements();
        (effects.inferred, requirements, effects.diagnostics)
    };
    sort_diagnostics(&mut diagnostics);
    if diagnostics.is_empty() {
        Ok(AuthorizedModule {
            ast: data_checked.ast,
            symbols: data_checked.symbols,
            types: data_checked.types,
            effects: EffectEnvironment {
                callable_effects: inferred,
                task_requirements: requirements,
            },
        })
    } else {
        Err(diagnostics)
    }
}

#[derive(Clone, Copy, Eq, PartialEq)]
enum CallableKind {
    Function,
    Task,
}

#[derive(Clone)]
struct Callable<'a> {
    id: SymbolId,
    kind: CallableKind,
    name: &'a str,
    origin: &'a Origin,
    body: &'a Spanned<ExpressionAst>,
    ensures: Option<&'a Spanned<ExpressionAst>>,
    declared_effects: &'a [Spanned<crate::source::QualifiedName>],
    requirements: &'a [Spanned<RequirementAst>],
}

#[derive(Default)]
struct DirectEffects {
    operations: BTreeSet<SymbolId>,
    calls: BTreeSet<SymbolId>,
    sites: Vec<OperationSite>,
}

struct OperationSite {
    operation: SymbolId,
    arguments: Vec<Spanned<ExpressionAst>>,
    origin: Origin,
}

struct EffectChecker<'a> {
    checked: &'a CheckedModule,
    callables: BTreeMap<SymbolId, Callable<'a>>,
    direct: BTreeMap<SymbolId, DirectEffects>,
    inferred: BTreeMap<SymbolId, BTreeSet<SymbolId>>,
    diagnostics: Vec<Diagnostic>,
}

impl<'a> EffectChecker<'a> {
    fn new(checked: &'a CheckedModule) -> Self {
        Self {
            checked,
            callables: BTreeMap::new(),
            direct: BTreeMap::new(),
            inferred: BTreeMap::new(),
            diagnostics: Vec::new(),
        }
    }

    fn collect_callables(&mut self) {
        for declaration in &self.checked.ast.declarations {
            match &declaration.node {
                DeclarationAst::Function(function) => {
                    let Some(id) = self.definition_at(&function.name.origin, SymbolKind::Function)
                    else {
                        continue;
                    };
                    self.callables.insert(
                        id.clone(),
                        Callable {
                            id,
                            kind: CallableKind::Function,
                            name: &function.name.node,
                            origin: &function.name.origin,
                            body: &function.body,
                            ensures: None,
                            declared_effects: &[],
                            requirements: &[],
                        },
                    );
                }
                DeclarationAst::Task(task) => {
                    let Some(id) = self.definition_at(&task.name.origin, SymbolKind::Task) else {
                        continue;
                    };
                    self.callables.insert(
                        id.clone(),
                        Callable {
                            id,
                            kind: CallableKind::Task,
                            name: &task.name.node,
                            origin: &task.name.origin,
                            body: &task.body,
                            ensures: Some(&task.ensures),
                            declared_effects: &task.effects,
                            requirements: &task.requirements,
                        },
                    );
                }
                DeclarationAst::Type(_) | DeclarationAst::Effect(_) => {}
            }
        }
        for (id, callable) in &self.callables {
            let mut direct = DirectEffects::default();
            collect_direct(self.checked, callable.body, &mut direct);
            self.inferred.insert(id.clone(), direct.operations.clone());
            self.direct.insert(id.clone(), direct);
        }
    }

    fn reject_cycles(&mut self) {
        let mut active = BTreeSet::new();
        let mut finished = BTreeSet::new();
        let ids: Vec<_> = self.callables.keys().cloned().collect();
        for id in ids {
            self.visit_cycle(&id, &mut active, &mut finished);
        }
    }

    fn visit_cycle(
        &mut self,
        id: &SymbolId,
        active: &mut BTreeSet<SymbolId>,
        finished: &mut BTreeSet<SymbolId>,
    ) {
        if finished.contains(id) {
            return;
        }
        if !active.insert(id.clone()) {
            if let Some(callable) = self.callables.get(id) {
                self.diagnostics.push(Diagnostic::error(
                    "EFFECT_RECURSION_UNSUPPORTED",
                    format!(
                        "recursive callable `{}` is outside the closed Phase 2 effect system",
                        callable.name
                    ),
                    Some(callable.origin.clone()),
                ));
            }
            return;
        }
        let calls: Vec<_> = self
            .direct
            .get(id)
            .map_or_else(Vec::new, |direct| direct.calls.iter().cloned().collect());
        for callee in calls {
            self.visit_cycle(&callee, active, finished);
        }
        active.remove(id);
        finished.insert(id.clone());
    }

    fn infer_effects(&mut self) {
        for _ in 0..=self.callables.len() {
            let previous = self.inferred.clone();
            let mut changed = false;
            for (id, direct) in &self.direct {
                let mut effects = direct.operations.clone();
                for callee in &direct.calls {
                    if let Some(callee_effects) = previous.get(callee) {
                        effects.extend(callee_effects.iter().cloned());
                    }
                }
                if previous.get(id) != Some(&effects) {
                    self.inferred.insert(id.clone(), effects);
                    changed = true;
                }
            }
            if !changed {
                break;
            }
        }
    }

    fn check_declarations(&mut self) {
        let callables: Vec<_> = self.callables.values().cloned().collect();
        for callable in &callables {
            let inferred = self.inferred.get(&callable.id).cloned().unwrap_or_default();
            match callable.kind {
                CallableKind::Function if !inferred.is_empty() => {
                    self.diagnostics.push(Diagnostic::error(
                        "EFFECT_PURE_FUNCTION_ESCAPE",
                        format!(
                            "pure function `{}` reaches effects: {}",
                            callable.name,
                            display_ids(&inferred)
                        ),
                        Some(callable.origin.clone()),
                    ));
                }
                CallableKind::Task => self.check_task_annotation(callable, &inferred),
                CallableKind::Function => {}
            }
            if let Some(ensures) = callable.ensures {
                let mut direct = DirectEffects::default();
                collect_direct(self.checked, ensures, &mut direct);
                let mut verifier_effects = direct.operations;
                for callee in direct.calls {
                    if let Some(effects) = self.inferred.get(&callee) {
                        verifier_effects.extend(effects.iter().cloned());
                    }
                }
                if !verifier_effects.is_empty() {
                    self.diagnostics.push(Diagnostic::error(
                        "EFFECT_VERIFIER_ESCAPE",
                        format!(
                            "completion predicate for `{}` reaches effects: {}",
                            callable.name,
                            display_ids(&verifier_effects)
                        ),
                        Some(ensures.origin.clone()),
                    ));
                }
            }
        }
    }

    fn check_task_annotation(&mut self, callable: &Callable<'_>, inferred: &BTreeSet<SymbolId>) {
        let mut declared = BTreeSet::new();
        for effect in callable.declared_effects {
            if let Some(id) = self.use_at(&effect.origin)
                && !declared.insert(id.clone())
            {
                self.diagnostics.push(Diagnostic::error(
                    "EFFECT_DUPLICATE_ANNOTATION",
                    format!("effect `{}` is declared more than once", id.0),
                    Some(effect.origin.clone()),
                ));
            }
        }
        for missing in inferred.difference(&declared) {
            self.diagnostics.push(Diagnostic::error(
                "EFFECT_ANNOTATION_MISSING",
                format!("task `{}` is missing effect `{}`", callable.name, missing.0),
                Some(callable.origin.clone()),
            ));
        }
        for unexpected in declared.difference(inferred) {
            self.diagnostics.push(Diagnostic::error(
                "EFFECT_ANNOTATION_UNEXPECTED",
                format!(
                    "task `{}` declares unused effect `{}`",
                    callable.name, unexpected.0
                ),
                Some(callable.origin.clone()),
            ));
        }
    }

    fn check_requirements(&mut self) -> BTreeMap<SymbolId, RequirementSet> {
        let mut normalized = BTreeMap::new();
        let callables: Vec<_> = self.callables.values().cloned().collect();
        for callable in &callables {
            if callable.kind != CallableKind::Task {
                continue;
            }
            let operation_ids: BTreeMap<_, _> = callable
                .requirements
                .iter()
                .filter_map(|requirement| {
                    self.use_at(&requirement.node.target.origin).map(|id| {
                        (
                            format!(
                                "{}.{}",
                                requirement.node.target.node.namespace,
                                requirement.node.target.node.name
                            ),
                            id.clone(),
                        )
                    })
                })
                .collect();
            let requirements = match requirements::normalize(callable.requirements, &operation_ids)
            {
                Ok(requirements) => requirements,
                Err(mut diagnostics) => {
                    self.diagnostics.append(&mut diagnostics);
                    continue;
                }
            };
            let effects = self.inferred.get(&callable.id).cloned().unwrap_or_default();
            self.check_coverage(callable, &effects, &requirements);
            normalized.insert(callable.id.clone(), requirements);
        }
        normalized
    }

    fn check_coverage(
        &mut self,
        callable: &Callable<'_>,
        effects: &BTreeSet<SymbolId>,
        requirements: &RequirementSet,
    ) {
        for effect in effects {
            if !requirements
                .entries
                .iter()
                .any(|requirement| &requirement.operation == effect)
            {
                self.diagnostics.push(Diagnostic::error(
                    "REQUIREMENT_UNCOVERED_EFFECT",
                    format!(
                        "task `{}` has no requirement covering `{}`",
                        callable.name, effect.0
                    ),
                    Some(callable.origin.clone()),
                ));
            }
        }
        for requirement in &requirements.entries {
            if !effects.contains(&requirement.operation) {
                self.diagnostics.push(Diagnostic::error(
                    "REQUIREMENT_UNUSED_AUTHORITY",
                    format!(
                        "task `{}` requests unused authority for `{}`",
                        callable.name, requirement.operation.0
                    ),
                    Some(callable.origin.clone()),
                ));
            }
        }
        let Some(direct) = self.direct.get(&callable.id) else {
            return;
        };
        for site in &direct.sites {
            let candidates: Vec<_> = requirements
                .entries
                .iter()
                .filter(|requirement| requirement.operation == site.operation)
                .collect();
            if candidates.is_empty() {
                continue;
            }
            if site.operation.0 == "operation:workspace.write/v1"
                && !candidates
                    .iter()
                    .any(|requirement| workspace_path_is_covered(requirement, &site.arguments))
            {
                self.diagnostics.push(Diagnostic::error(
                    "REQUIREMENT_ARGUMENT_NOT_PROVEN",
                    "Workspace.write path is outside, or cannot be proven inside, the declared requirement",
                    Some(site.origin.clone()),
                ));
            }
        }
        let call_counts =
            direct
                .sites
                .iter()
                .fold(BTreeMap::<SymbolId, u32>::new(), |mut counts, site| {
                    *counts.entry(site.operation.clone()).or_default() += 1;
                    counts
                });
        for requirement in &requirements.entries {
            if let (Some(limit), Some(actual)) = (
                requirement.max_calls,
                call_counts.get(&requirement.operation),
            ) && *actual > limit
            {
                self.diagnostics.push(Diagnostic::error(
                    "REQUIREMENT_CALL_BUDGET_TOO_SMALL",
                    format!(
                        "requirement for `{}` permits {limit} calls but the task has {actual} direct sites",
                        requirement.operation.0
                    ),
                    Some(callable.origin.clone()),
                ));
            }
        }
    }

    fn definition_at(&self, origin: &Origin, kind: SymbolKind) -> Option<SymbolId> {
        self.checked
            .symbols
            .uses
            .get(&OriginKey::from_origin(origin))
            .filter(|id| {
                self.checked
                    .symbols
                    .definitions
                    .get(*id)
                    .is_some_and(|definition| definition.kind == kind)
            })
            .cloned()
            .or_else(|| {
                self.checked
                    .symbols
                    .definitions
                    .values()
                    .find(|definition| definition.kind == kind && definition.origin == *origin)
                    .map(|definition| definition.id.clone())
            })
    }

    fn use_at(&self, origin: &Origin) -> Option<&SymbolId> {
        self.checked
            .symbols
            .uses
            .get(&OriginKey::from_origin(origin))
    }
}

fn collect_direct(
    checked: &CheckedModule,
    expression: &Spanned<ExpressionAst>,
    direct: &mut DirectEffects,
) {
    match &expression.node {
        ExpressionAst::Integer { .. }
        | ExpressionAst::Boolean { .. }
        | ExpressionAst::String { .. }
        | ExpressionAst::Variable { .. } => {}
        ExpressionAst::Record { fields, .. } => {
            for field in fields {
                collect_direct(checked, &field.node.value, direct);
            }
        }
        ExpressionAst::Field { target, .. }
        | ExpressionAst::Ok { value: target }
        | ExpressionAst::Error { value: target } => collect_direct(checked, target, direct),
        ExpressionAst::Call { arguments, .. } => {
            if let Some(id) = checked
                .symbols
                .uses
                .get(&OriginKey::from_origin(&expression.origin))
            {
                direct.calls.insert(id.clone());
            }
            for argument in arguments {
                collect_direct(checked, argument, direct);
            }
        }
        ExpressionAst::Let { value, body, .. } => {
            collect_direct(checked, value, direct);
            collect_direct(checked, body, direct);
        }
        ExpressionAst::MatchResult {
            value,
            ok_body,
            error_body,
            ..
        } => {
            collect_direct(checked, value, direct);
            collect_direct(checked, ok_body, direct);
            collect_direct(checked, error_body, direct);
        }
        ExpressionAst::Perform {
            operation,
            arguments,
        } => {
            if let Some(id) = checked
                .symbols
                .uses
                .get(&OriginKey::from_origin(&operation.origin))
            {
                direct.operations.insert(id.clone());
                direct.sites.push(OperationSite {
                    operation: id.clone(),
                    arguments: arguments.clone(),
                    origin: operation.origin.clone(),
                });
            }
            for argument in arguments {
                collect_direct(checked, argument, direct);
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
            collect_direct(checked, first, direct);
            collect_direct(checked, second, direct);
        }
    }
}

fn workspace_path_is_covered(
    requirement: &NormalizedRequirement,
    arguments: &[Spanned<ExpressionAst>],
) -> bool {
    let path_constraints: Vec<_> = requirement
        .constraints
        .iter()
        .filter(|constraint| match constraint {
            RequirementConstraint::EqualsString { key, .. }
            | RequirementConstraint::Prefix { key, .. } => key == "path",
            RequirementConstraint::EqualsInteger { .. } => false,
        })
        .collect();
    if path_constraints.is_empty() {
        return true;
    }
    let Some(Spanned {
        node: ExpressionAst::String { value: path },
        ..
    }) = arguments.first()
    else {
        return false;
    };
    path_constraints.iter().any(|constraint| match constraint {
        RequirementConstraint::EqualsString { value, .. } => value == path,
        RequirementConstraint::Prefix { value, .. } => path.starts_with(value),
        RequirementConstraint::EqualsInteger { .. } => false,
    })
}

fn display_ids(ids: &BTreeSet<SymbolId>) -> String {
    ids.iter()
        .map(|id| id.0.as_str())
        .collect::<Vec<_>>()
        .join(", ")
}

#[cfg(test)]
mod tests {
    use super::check;
    use crate::semantic::{SymbolId, canonical_operation_id};
    use crate::{analyze_data, parse_text};

    fn authorize(
        source: &str,
    ) -> Result<crate::semantic::AuthorizedModule, Vec<crate::diagnostic::Diagnostic>> {
        let module = parse_text("effects.alang", source).expect("source must parse");
        let checked = analyze_data(&module).expect("data semantics must pass");
        check(checked)
    }

    #[test]
    fn effects_propagate_through_calls_and_require_exact_task_annotations() {
        let authorized = authorize(
            r#"
module Effects version "alang-source-v1" {
  effect Model { operation complete(prompt: String) -> String; }
  task inner(prompt: String) -> String
    effect [Model.complete]
    requires [Model.complete(model = "fixture", max_calls = 1)]
    = perform Model.complete(prompt)
    ensures true;
  task outer(prompt: String) -> String
    effect [Model.complete]
    requires [Model.complete(model = "fixture", max_calls = 1)]
    = inner(prompt)
    ensures true;
}
"#,
        )
        .expect("effects must pass");
        assert_eq!(
            authorized
                .effects
                .callable_effects
                .get(&SymbolId("task:Effects.outer/1".to_owned())),
            Some(&std::collections::BTreeSet::from([canonical_operation_id(
                "Model", "complete"
            )]))
        );
    }

    #[test]
    fn effects_reject_pure_escapes_missing_and_unexpected_annotations_and_recursion() {
        let source = r#"
module BadEffects version "alang-source-v1" {
  effect Model { operation complete(prompt: String) -> String; }
  task ask(prompt: String) -> String
    effect []
    requires []
    = perform Model.complete(prompt)
    ensures true;
  fn leak(prompt: String) -> String = ask(prompt);
  fn loop(value: Int) -> Int = loop(value);
}
"#;
        let diagnostics = authorize(source).expect_err("effect errors must fail");
        let codes: Vec<_> = diagnostics.iter().map(|item| item.code.as_str()).collect();
        assert!(codes.contains(&"EFFECT_ANNOTATION_MISSING"));
        assert!(codes.contains(&"EFFECT_PURE_FUNCTION_ESCAPE"));
        assert!(codes.contains(&"EFFECT_RECURSION_UNSUPPORTED"));
        assert!(codes.contains(&"REQUIREMENT_UNCOVERED_EFFECT"));
    }

    #[test]
    fn effects_reject_uncovered_widened_and_underbudgeted_workspace_operations() {
        let source = r#"
module WorkspaceEffects version "alang-source-v1" {
  effect Workspace { operation write(path: String, contents: String) -> Bool; }
  task publish(path: String) -> Bool
    effect [Workspace.write]
    requires [Workspace.write(path_prefix = "/safe/", max_calls = 1)]
    = perform Workspace.write(path, "one") >> perform Workspace.write("/unsafe/two", "two")
    ensures result == true;
}
"#;
        let diagnostics = authorize(source).expect_err("requirements must fail");
        let codes: Vec<_> = diagnostics.iter().map(|item| item.code.as_str()).collect();
        assert!(codes.contains(&"REQUIREMENT_ARGUMENT_NOT_PROVEN"));
        assert!(codes.contains(&"REQUIREMENT_CALL_BUDGET_TOO_SMALL"));
    }
}
