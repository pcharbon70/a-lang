pub mod diagnostic;
pub mod json_frontend;
pub mod lexer;
pub mod parser;
pub mod resolver;
pub mod semantic;
pub mod source;
pub mod type_checker;

use diagnostic::Diagnostic;
use semantic::CheckedModule;
use source::ModuleAst;

/// Decode the canonical JSON source representation.
///
/// # Errors
///
/// Returns stable diagnostics when the input exceeds its bound, violates the
/// JSON schema, uses an unsupported version, or contains an invalid AST value.
pub fn parse_json(source_name: &str, bytes: &[u8]) -> Result<ModuleAst, Vec<Diagnostic>> {
    json_frontend::decode(source_name, bytes)
}

/// Parse the native textual source representation.
///
/// # Errors
///
/// Returns all recoverable lexical and syntactic diagnostics and never returns
/// a partial accepted module.
pub fn parse_text(source_name: &str, text: &str) -> Result<ModuleAst, Vec<Diagnostic>> {
    parser::parse(source_name, text)
}

/// Resolve and data-type-check one parsed A-Lang module.
///
/// # Errors
///
/// Returns stable diagnostics for duplicate, unknown, wrong-namespace,
/// shadowed, arity, type, exhaustiveness, or opaque-boundary violations.
pub fn analyze_data(module: &ModuleAst) -> Result<CheckedModule, Vec<Diagnostic>> {
    let resolved = resolver::resolve(module)?;
    type_checker::check(resolved)
}
