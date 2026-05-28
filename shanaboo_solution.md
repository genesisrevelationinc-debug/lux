```diff
--- /dev/null
+++ b/priv/rust/.gitignore
@@ -0,0 +1,3 @@
+/target
+Cargo.lock
+*.so
\ No newline at end of file
--- /dev/null
+++ b/priv/rust/Cargo.toml
@@ -0,0 +1,22 @@
+[package]
+name = "lux_core"
+version = "0.1.0"
+edition = "2021"
+authors = ["Spectral Finance <dev@spectral.finance>"]
+description = "Core Rust integration for Lux - high-performance native code execution and FFI bindings"
+license = "MIT"
+repository = "https://github.com/Spectral-Finance/lux"
+
+[lib]
+name = "lux_core"
+crate-type = ["cdylib"]
+
+[dependencies]
+rustler = "0.32.0"
+thiserror = "1.0"
+serde = { version = "1.0", features = ["derive"] }
+serde_json = "1.0"
+
+[dev-dependencies]
+tokio = { version = "1.0", features = ["full"] }
+criterion = { version = "0.5", features = ["html_reports"] }
\ No newline at end of file
--- /dev/null
+++ b/priv/rust/src/lib.rs
@@ -0,0 +1,155 @@
+//! Lux Core - Rust integration for the Lux framework
+//!
+//! This crate provides high-performance native code execution
+//! and FFI bindings for the Lux Elixir framework.
+
+pub mod conversion;
+pub mod error;
+pub mod nif;
+
+use rustler::{Env, Term};
+
+/// Initialize the Lux Core NIF module
+#[rustler::nif]
+fn add(a: i64, b: i64) -> i64 {
+    a + b
+}
+
+/// Module initialization for the NIF
+fn load(_env: Env, _info: Term) -> bool {
+    true
+}
+
+rustler::init!("Elixir.Lux.Core.RustNif", [add], load = load);
+
+#[cfg(test)]
+mod tests {
+    use super::*;
+
+    #[test]
+    fn test_add() {
+        assert_eq!(add(2, 3), 5);
+    }
+}
--- /dev/null
+++ b/priv/rust/src/conversion.rs
@@ -0,0 +1,218 @@
+//! Type conversion between Elixir and Rust types
+//!
+//! This module provides safe bidirectional conversion between
+//! Elixir terms and Rust types, handling memory safety and
+//! proper error propagation.
+
+use rustler::{
+    types::{atom::nil, Atom, Binary, ListIterator, MapIterator},
+    Encoder, Env, Term,
+};
+use serde::{Deserialize, Serialize};
+use std::collections::HashMap;
+
+use crate::error::LuxError;
+
+/// Trait for types that can be converted from Elixir terms
+pub trait FromElixir<'a>: Sized {
+    fn from_elixir(term: Term<'a>) -> Result<Self, LuxError>;
+}
+
+/// Trait for types that can be converted to Elixir terms
+pub trait ToElixir<'a> {
+    fn to_elixir(self, env: Env<'a>) -> Term<'a>;
+}
+
+// Primitive type conversions
+
+impl<'a> FromElixir<'a> for i64 {
+    fn from_elixir(term: Term<'a>) -> Result<Self, LuxError> {
+        term.decode()
+            .map_err(|e| LuxError::ConversionError(format!("Failed to decode i64: {:?}", e)))
+    }
+}
+
+impl<'a> ToElixir<'a> for i64 {
+    fn to_elixir(self, env: Env<'a>) -> Term<'a> {
+        self.encode(env)
+    }
+}
+
+impl<'a> FromElixir<'a> for f64 {
+    fn from_elixir(term: Term<'a>) -> Result<Self, LuxError> {
+        term.decode()
+            .map_err(|e| LuxError::ConversionError(format!("Failed to decode f64: {:?}", e)))
+    }
+}
+
+impl<'a> ToElixir<'a> for f64 {
+    fn to_elixir(self, env: Env<'a>) -> Term<'a> {
+        self.encode(env)
+    }
+}
+
+impl<'a> FromElixir<'a> for String {
+    fn from_elixir(term: Term<'a>) -> Result<Self, LuxError> {
+        let binary: Binary = term
+            .decode()
+            .map_err(|e| LuxError::ConversionError(format!("Failed to decode string: {:?}", e)))?;
+        String::from_utf8(binary.as_slice().to_vec())
+            .map_err(|e| LuxError::ConversionError(format!("Invalid UTF-8: {:?}", e)))
+    }
+}
+
+impl<'a> ToElixir<'a> for String {
+    fn to_elixir(self, env: Env<'a>) -> Term<'a> {
+        self.encode(env)
+    }
+}
+
+impl<'a> FromElixir<'a> for bool {
+    fn from_elixir(term: Term<'a>) -> Result<Self, LuxError> {
+        term.decode()
+            .map_err(|e| LuxError::ConversionError(format!("Failed to decode bool: {:?}", e)))
+    }
+}
+
+impl<'a> ToElixir<'a> for bool {
+    fn to_elixir(self, env: Env<'a>) -> Term<'a> {
+        self.encode(env)
+    }
+}
+
+/// Generic vector conversion
+impl<'a, T> FromElixir<'a> for Vec<T>
+where
+    T: FromElixir<'a>,
+{
+    fn from_elixir(term: Term<'a>) -> Result<Self, LuxError> {
+        let list: ListIterator = term
+            .decode()
+            .map_err(|e| LuxError::ConversionError(format!("Failed to decode list: {:?}", e)))?;
+        list.map(|item| T::from_elixir(item)).collect()
+    }
+}
+
+impl<'a, T> ToElixir<'a> for Vec<T>
+where
+    T: ToElixir<'a>,
+{
+    fn to_elixir(self, env: Env<'a>) -> Term<'a> {
+        let terms: Vec<Term> = self.into_iter().map(|item| item.to_elixir(env)).collect();
+        terms.encode(env)
+    }
+}
+
+/// HashMap conversion for keyword lists and maps
+impl<'a, K, V> FromElixir<'a> for HashMap<K, V>
+where
+    K: