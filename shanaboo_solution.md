```diff
--- /dev/null
+++ b/priv/rust/Cargo.toml
@@ -0,0 +1,15 @@
+[package]
+name = "lux_core"
+version = "0.1.0"
+edition = "2021"
+authors = ["Spectral Finance <team@spectral.finance>"]
+license = "MIT"
+description = "Core Rust integration for Lux framework"
+repository = "https://github.com/Spectral-Finance/lux"
+
+[lib]
+name = "lux_core"
+crate-type = ["cdylib"]
+
+[dependencies]
+rustler = "0.32.0"
+thiserror = "1.0"
+
--- /dev/null
+++ b	priv/rust/src/lib.rs
@@ -0,0 +1,18 @@
+mod types;
+mod error;
+mod nif;
+
+pub use types::*;
+pub use error::*;
+
+use rustler::Env;
+
+fn load(_env: Env, _term: rustler::Term) -> bool {
+    true
+}
+
+rustler::init!(
+    "lux_core",
+    [nif::add, nif::to_rust_string, nif::from_rust_string],
+    load = load
+);
+
--- /dev/null
+++		priv/rust/src/types.rs
@@ -0,0 +1,67 @@
+use rustler::{Decoder, Encoder, Env, Term};
+use std::collections::HashMap;
+
+/// Represents primitive types that can be converted between Elixir and Rust.
+#[derive(Debug, Clone, PartialEq)]
+pub enum LuxValue {
+    Integer(i64),
+    Float(f64),
+    Boolean(bool),
+    String(String),
+    List(Vec<LuxValue>),
+    Map(HashMap<String, LuxValue>),
+    Atom(String),
+    Binary(Vec<u8>),
+    Nil,
+}
+
+impl<'a> Encoder for LuxValue {
+    fn encode<'b>(&self, env: Env<'b>) -> Term<'b> {
+        match self {
+            LuxValue::Integer(i) => i.encode(env),
+            LuxValue::Float(f) => f.encode(env),
+            LuxValue::Boolean(b) => b.encode(env),
+            LuxValue::String(s) => s.encode(env),
+            LuxValue::List(l) => {
+                let encoded: Vec<Term> = l.iter().map(|v| v.encode(env)).collect();
+                encoded.encode(env)
+            }
+            LuxValue::Map(m) => {
+                let encoded: Vec<(Term, Term)> = m
+                    .iter()
+                    .map(|(k, v)| (k.encode(env), v.encode(env)))
+                    .collect();
+                encoded.encode(env)
+            }
+            LuxValue::Atom(a) => a.encode(env),
+            LuxValue::Binary(b) => b.encode(env),
+            LuxValue::Nil => ().encode(env),
+        }
+    }
+}
+
+impl<'a> Decoder<'a> for LuxValue {
+    fn decode(term: Term<'a>) -> Result<Self, rustler::Error> {
+        if let Ok(i) = term.decode::<i64>() {
+            return Ok(LuxValue::Integer(i));
+        }
+        if let Ok(f) = term.decode::<f64>() {
+            return Ok(LuxValue::Float(f));
+        }
+        if let Ok(b) = term.decode::<bool>() {
+            return Ok(LuxValue::Boolean(b));
+        }
+        if let Ok(s) = term.decode::<String>() {
+            return Ok(LuxValue::String(s));
+        }
+        if let Ok(l) = term.decode::<Vec<Term>>() {
+            let decoded: Result<Vec<LuxValue>, _> =
+                l.into_iter().map(|t| LuxValue::decode(t)).collect();
+            return Ok(LuxValue::List(decoded?));
+        }
+        if term.is_atom() {
+            let s: String = term.decode()?;
+            return Ok(LuxValue::Atom(s));
+        }
+        Ok(LuxValue::Nil)
+    }
+}
+
--- /dev/null
+++			priv/rust/src/error.rs
@@ -0,0 +1,32 @@
+use rustler::{Encoder, Env, Term};
+use thiserror::Error;
+
+/// Errors that can occur during Rust/Elixir interop.
+#[derive(Error, Debug, Clone)]
+pub enum LuxError {
+    #[error("Type conversion failed: {0}")]
+    TypeConversion(String),
+    #[error("Invalid argument: {0}")]
+    InvalidArgument(String),
+    #[error("FFI error: {0}")]
+    FfiError(String),
+    #[error("Memory safety violation: {0}")]
+    MemorySafety(String),
+    #[error("Unknown error")]
+    Unknown,
+}
+
+impl LuxError {
+    pub fn to_elixir<'a>(&self, env: Env<'a>) -> Term<'a> {
+        let atom = match self {
+            LuxError::TypeConversion(_) => "type_conversion_error",
+            LuxError::InvalidArgument(_) => "invalid_argument",
+            LuxError::FfiError(_) => "ffi_error",
+            LuxError::MemorySafety(_) => "memory_safety_error",
+            LuxError::Unknown => "unknown_error",
+        };
+        let msg = self.to_string();
+        (atom, msg).encode(env)
+    }
+}
+
--- /dev/null
+++				priv/rust/src/nif.rs
@@ -0,0 +1,22 @@
+use rustler::{Env, Term};
+
+/// Adds two integers safely.
+#[rustler::nif]
+fn add(a: i64, b: i64) -> i64 {
+    a + b
+}
+
+/// Converts an Elixir term to a Rust string and back.
+#[rustler::nif]
+fn to_rust_string(env: Env, term: Term) -> Result<String, rustler::Error> {
+    let s: String = term.decode()?;
+    Ok(s)
+}
+
+/// Returns a Rust string as an Elixir binary.
+#[rustler::nif]
+fn from_rust_string(env: Env, s: String) -> Term {
+    s.encode(env)
+}
+
--- /dev/null
+++					priv/rust/.gitignore
@@ -0,0 +1,2 @@
+/target
+Cargo.lock
+
--- /dev/null
+++						priv/rust/README.md
@@ -0,0 +1,45 @@
+# Lux Rust Core
+
+This crate provides the core Rust integration for the Lux framework, enabling high-performance native code execution via NIFs.
+
+## Structure
+
+- `src/lib.rs` — Entry point and NIF registration
+- `src