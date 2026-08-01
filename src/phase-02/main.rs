use alang_phase2_compiler::beam_bridge::lower_counter_profile;
use alang_phase2_compiler::ir::IrCallableKind;
use alang_phase2_compiler::reference::{EffectFixture, ReferenceValue, evaluate_task};
use alang_phase2_compiler::{compile_ir, parse_text, views};
use serde::Serialize;
use std::fs;
use std::path::{Path, PathBuf};

fn main() {
    if let Err(message) = run() {
        eprintln!("phase_2_compiler_error {message}");
        std::process::exit(1);
    }
}

fn run() -> Result<(), String> {
    let mut arguments = std::env::args_os().skip(1);
    let source_path = arguments.next().map(PathBuf::from).ok_or_else(usage)?;
    let output_directory = arguments.next().map(PathBuf::from).ok_or_else(usage)?;
    if arguments.next().is_some() {
        return Err(usage());
    }
    let source = fs::read_to_string(&source_path)
        .map_err(|error| format!("cannot read {}: {error}", source_path.display()))?;
    let ast = parse_text("counter.alang", &source).map_err(render_diagnostics)?;
    let ir = compile_ir(&ast).map_err(render_diagnostics)?;
    let bridge = lower_counter_profile(&ir).map_err(render_diagnostics)?;
    let task = ir
        .callables
        .values()
        .find(|callable| callable.kind == IrCallableKind::Task)
        .ok_or_else(|| "compiled module has no task".to_owned())?;
    let outcome = evaluate_task(
        &ir,
        &task.id,
        vec![ReferenceValue::Integer { value: 41 }],
        &EffectFixture::default(),
        100,
    )
    .map_err(|error| format!("{}: {}", error.code, error.message))?;
    if outcome.result != (ReferenceValue::Integer { value: 42 }) || !outcome.completion {
        return Err(
            "counter reference outcome differs from result 42 with completion true".to_owned(),
        );
    }
    fs::create_dir_all(&output_directory).map_err(|error| {
        format!(
            "cannot create output directory {}: {error}",
            output_directory.display()
        )
    })?;
    write_json(&output_directory.join("canonical-source.json"), &ast)?;
    write_json(&output_directory.join("typed-task-ir.json"), &ir)?;
    write_json(
        &output_directory.join("semantic-views.json"),
        &views::derive(&ir),
    )?;
    write_json(&output_directory.join("reference-outcome.json"), &outcome)?;
    write_json(
        &output_directory.join("phase1-bridge-manifest.json"),
        &bridge.manifest,
    )?;
    write_bytes(
        &output_directory.join("phase1-semantic-fixture.config"),
        &bridge.fixture_bytes,
    )?;
    write_bytes(
        &output_directory.join("agreement.config"),
        agreement_config().as_bytes(),
    )?;
    println!(
        "phase_2_compile_ok task={} nodes={} output={}",
        task.id.0,
        ir.nodes.len(),
        output_directory.display()
    );
    Ok(())
}

fn write_json(path: &Path, value: &impl Serialize) -> Result<(), String> {
    let mut bytes = serde_json::to_vec_pretty(value)
        .map_err(|error| format!("cannot serialize {}: {error}", path.display()))?;
    bytes.push(b'\n');
    write_bytes(path, &bytes)
}

fn write_bytes(path: &Path, bytes: &[u8]) -> Result<(), String> {
    fs::write(path, bytes).map_err(|error| format!("cannot write {}: {error}", path.display()))
}

fn agreement_config() -> &'static str {
    r#"#{
  format => alang_phase2_agreement_v1,
  task => <<"task:Counter.successor/1">>,
  input => 41,
  reference_result => 42,
  reference_completion => true,
  reference_effects => [],
  manifest_effects => []
}.
"#
}

fn render_diagnostics(diagnostics: Vec<alang_phase2_compiler::diagnostic::Diagnostic>) -> String {
    diagnostics
        .into_iter()
        .map(|diagnostic| format!("{}: {}", diagnostic.code, diagnostic.message))
        .collect::<Vec<_>>()
        .join("; ")
}

fn usage() -> String {
    "usage: alang-phase2c <source.alang> <output-directory>".to_owned()
}
