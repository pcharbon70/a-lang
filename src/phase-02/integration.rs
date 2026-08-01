#[cfg(test)]
mod tests {
    use crate::beam_bridge::{PHASE1_FIXTURE_BYTES, lower_counter_profile};
    use crate::ir::IrCallableKind;
    use crate::reference::{EffectFixture, ReferenceValue, evaluate_task};
    use crate::{analyze, compile_ir, parse_json, parse_text, views};

    const COUNTER: &str = include_str!("fixtures/counter.alang");

    #[test]
    fn integration_paired_frontends_produce_identical_ast_semantics_and_ir() {
        for (name, source) in [
            ("counter.alang", COUNTER),
            ("ir.alang", crate::ir::tests::COMPLETE_SOURCE),
        ] {
            let textual = parse_text(name, source).expect("text must parse");
            let canonical_bytes = serde_json::to_vec(&textual).expect("AST must serialize");
            let canonical = parse_json(name, &canonical_bytes).expect("JSON must parse");
            assert_eq!(textual, canonical);
            assert_eq!(
                analyze(&textual).expect("text semantics"),
                analyze(&canonical).expect("JSON semantics")
            );
            let textual_ir = compile_ir(&textual).expect("text IR");
            let canonical_ir = compile_ir(&canonical).expect("JSON IR");
            assert_eq!(textual_ir, canonical_ir);
            assert_eq!(
                serde_json::to_vec(&textual_ir).unwrap(),
                serde_json::to_vec(&canonical_ir).unwrap()
            );
        }
    }

    #[test]
    fn integration_negative_programs_fail_before_backend_work_with_stable_codes() {
        let malformed = parse_text(
            "malformed.alang",
            "module Bad version \"alang-source-v1\" { fn broken( -> Int = 1; }",
        )
        .expect_err("syntax must fail");
        assert!(malformed.iter().any(|item| item.code.starts_with("PARSE_")));

        let cases = [
            (
                "unknown.alang",
                r#"module Unknown version "alang-source-v1" { fn f() -> Int = missing; }"#,
                "RESOLVE_UNKNOWN_NAME",
            ),
            (
                "type.alang",
                r#"module TypeBad version "alang-source-v1" { fn f() -> Int = true; }"#,
                "TYPE_MISMATCH",
            ),
            (
                "effect.alang",
                r#"
module EffectBad version "alang-source-v1" {
  effect Trace { operation emit(message: String) -> Bool; }
  task run() -> Bool effect [] requires []
    = perform Trace.emit("x") ensures true;
}
"#,
                "EFFECT_ANNOTATION_MISSING",
            ),
            (
                "requirement.alang",
                r#"
module RequirementBad version "alang-source-v1" {
  effect Trace { operation emit(message: String) -> Bool; }
  task run() -> Bool effect [Trace.emit] requires []
    = perform Trace.emit("x") ensures true;
}
"#,
                "REQUIREMENT_UNCOVERED_EFFECT",
            ),
        ];
        for (name, source, expected) in cases {
            let module = parse_text(name, source).expect("negative semantics source must parse");
            let diagnostics = compile_ir(&module).expect_err("semantics must fail");
            assert!(
                diagnostics.iter().any(|item| item.code == expected),
                "missing {expected}: {diagnostics:?}"
            );
        }

        let complete_match = parse_text(
            "match.alang",
            r#"
module Match version "alang-source-v1" {
  fn choose(value: Result<Int, String>) -> Int =
    match value { ok(number) => number, error(reason) => 0 };
}
"#,
        )
        .expect("complete match must parse");
        let mut json = serde_json::to_value(complete_match).unwrap();
        let match_node = &mut json["declarations"][0]["node"]["body"]["node"];
        match_node
            .as_object_mut()
            .expect("match object")
            .remove("error_body");
        let bytes = serde_json::to_vec(&json).unwrap();
        let diagnostics = parse_json("match.alang", &bytes).expect_err("partial match must fail");
        assert!(
            diagnostics
                .iter()
                .any(|item| item.code == "JSON_SCHEMA_INVALID")
        );
    }

    #[test]
    fn integration_reference_views_and_phase1_bridge_agree_on_counter_semantics() {
        let module = parse_text("counter.alang", COUNTER).expect("counter must parse");
        let ir = compile_ir(&module).expect("counter must compile");
        let task = ir
            .callables
            .values()
            .find(|callable| callable.kind == IrCallableKind::Task)
            .expect("counter task");
        let outcome = evaluate_task(
            &ir,
            &task.id,
            vec![ReferenceValue::Integer { value: 41 }],
            &EffectFixture::default(),
            100,
        )
        .expect("reference evaluation must pass");
        assert_eq!(outcome.result, ReferenceValue::Integer { value: 42 });
        assert!(outcome.completion);
        assert!(outcome.observations.len() == 1);
        let semantic_views = views::derive(&ir);
        let manifest = semantic_views
            .capability_manifest
            .tasks
            .get(&task.id)
            .expect("task manifest");
        assert!(manifest.effects.is_empty());
        assert!(manifest.requirements.entries.is_empty());
        assert!(manifest.effect_sites.is_empty());
        assert!(semantic_views.completion.tasks.contains_key(&task.id));
        let bridge = lower_counter_profile(&ir).expect("bridge must lower");
        assert_eq!(bridge.fixture_bytes, PHASE1_FIXTURE_BYTES);
        assert_eq!(bridge.manifest.lowered_nodes.len(), ir.nodes.len());
    }

    #[test]
    fn integration_frontend_fuzz_smoke_never_panics_and_is_deterministic() {
        let ast = parse_text("counter.alang", COUNTER).expect("counter must parse");
        let canonical = serde_json::to_vec(&ast).unwrap();
        let replacements = [b' ', b'{', b'}', b';', b'@', b'"'];
        for iteration in 0..256_usize {
            let mut text = COUNTER.as_bytes().to_vec();
            let text_index = (iteration * 37) % text.len();
            text[text_index] = replacements[iteration % replacements.len()];
            let mutated = String::from_utf8(text).expect("ASCII mutation");
            let first = std::panic::catch_unwind(|| parse_text("fuzz.alang", &mutated));
            let second = std::panic::catch_unwind(|| parse_text("fuzz.alang", &mutated));
            assert!(first.is_ok() && second.is_ok());
            assert_eq!(first.unwrap(), second.unwrap());

            let mut json = canonical.clone();
            let json_index = (iteration * 53) % json.len();
            json[json_index] = replacements[(iteration + 1) % replacements.len()];
            let first = std::panic::catch_unwind(|| parse_json("fuzz.alang", &json));
            let second = std::panic::catch_unwind(|| parse_json("fuzz.alang", &json));
            assert!(first.is_ok() && second.is_ok());
            assert_eq!(first.unwrap(), second.unwrap());
        }
    }
}
