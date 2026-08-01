use crate::source::Origin;
use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum Severity {
    Error,
    Warning,
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(deny_unknown_fields)]
pub struct Label {
    pub message: String,
    pub origin: Origin,
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(deny_unknown_fields)]
pub struct Diagnostic {
    pub code: String,
    pub severity: Severity,
    pub message: String,
    pub origin: Option<Origin>,
    #[serde(default)]
    pub labels: Vec<Label>,
}

impl Diagnostic {
    pub fn error(code: &str, message: impl Into<String>, origin: Option<Origin>) -> Self {
        Self {
            code: code.to_owned(),
            severity: Severity::Error,
            message: message.into(),
            origin,
            labels: Vec::new(),
        }
    }

    #[must_use]
    pub fn with_label(mut self, message: impl Into<String>, origin: Origin) -> Self {
        self.labels.push(Label {
            message: message.into(),
            origin,
        });
        self
    }
}

pub fn sort_diagnostics(diagnostics: &mut [Diagnostic]) {
    diagnostics.sort_by(|left, right| {
        let left_key = left
            .origin
            .as_ref()
            .map_or((String::new(), u32::MAX, u32::MAX), |origin| {
                (origin.source.clone(), origin.start.byte, origin.end.byte)
            });
        let right_key = right
            .origin
            .as_ref()
            .map_or((String::new(), u32::MAX, u32::MAX), |origin| {
                (origin.source.clone(), origin.start.byte, origin.end.byte)
            });
        left_key
            .cmp(&right_key)
            .then_with(|| left.code.cmp(&right.code))
            .then_with(|| left.message.cmp(&right.message))
    });
}
