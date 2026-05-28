```diff
--- a/lux/mix.exs
+++ b/lux/mix.exs
@@ -1,4 +1,5 @@
 defmodule Lux.MixProject do
+  @moduledoc false
   use Mix.Project
 
   def project do
@@ -14,6 +15,7 @@ defmodule Lux.MixProject do
       deps: deps(),
       docs: docs(),
       package: package(),
+      compilers: [:rustler] ++ Mix.compilers(),
       aliases: aliases()
     ]
   end
@@ -37,6 +39,7 @@ defmodule Lux.MixProject do
       {:req, "~> 0.5"},
       {:nimble_options, "~> 1.1"},
       {:ex_doc, "~> 0.31", only: :dev, runtime: false},
+      {:rustler, "~> 0.32"},
       {:mimic, "~> 1.7", only: :test}
     ]
   end
--- /dev/null
+++ b/lux/priv/rust/.gitignore
@@ -0,0 +1,3 @@
+/target
+**/*.rs.bk
+Cargo.lock
--- /dev/null
+++ b/lux/priv/rust/Cargo.toml
@@ -0,0 +1,16 @@
+[package]
+name = "lux_rust"
+version = "0.1.0"
+edition = "2021"
+
+[lib]
+name = "lux_rust"
+crate-type = ["cdylib"]
+
+[dependencies]
+rustler = "0.32"
+thiserror = "1.0"
+
+[profile.release]
+opt-level = 3
+lto = true
--- /dev/null
+++ b/lux/priv/rust/src/lib.rs
@@ -0,0 +1,218 @@
+use rustler::{Atom, Encoder, Env, Error as RustlerError, NifResult, Term};
+use std::sync::Arc;
+
+mod atoms;
+mod conversion;
+mod error;
+
+use conversion::{from_elixir, to_elixir, ElixirTerm, RustTerm};
+use error::LuxError;
+
+/// Initialize the Rust NIF module
+rustler::init!("Elixir.Lux.RustCore", [add, multiply, process_term, safe_divide]);
+
+/// Adds two integers safely with overflow checking
+#[rustler::nif]
+fn add(a: i64, b: i64) -> NifResult<i64> {
+    a.checked_add(b)
+        .ok_or_else(|| LuxError::Overflow.into_rustler_error())
+}
+
+/// Multiplies two integers safely with overflow checking
+#[rustler::nif]
+fn multiply(a: i64, b: i64) -> NifResult<i64> {
+    a.checked_mul(b)
+        .ok_or_else(|| LuxError::Overflow.into_rustler_error())
+}
+
+/// Safely divides two numbers with zero division protection
+#[rustler::nif]
+fn safe_divide(a: f64, b: f64) -> NifResult<f64> {
+    if b == 0.0 {
+        return Err(LuxError::DivisionByZero.into_rustler_error());
+    }
+    Ok(a / b)
+}
+
+/// Processes an Elixir term and returns a transformed term
+#[rustler::nif]
+fn process_term<'a>(env: Env<'a>, term: Term<'a>) -> NifResult<Term<'a>> {
+    let elixir_term = from_elixir(term)?;
+    let rust_term = elixir_term.to_rust()?;
+    let result = rust_term.to_elixir(env)?;
+    Ok(result)
+}
+
+/// Trait for converting types between Elixir and Rust
+pub trait TypeConversion {
+    type RustType;
+    fn to_rust(self) -> Result<Self::RustType, LuxError>;
+    fn to_elixir<'a>(self, env: Env<'a>) -> Result<Term<'a>, LuxError>;
+}
+
+impl TypeConversion for ElixirTerm<'_> {
+    type RustType = RustTerm;
+
+    fn to_rust(self) -> Result<Self::RustType, LuxError> {
+        match self {
+            ElixirTerm::Integer(i) => Ok(RustTerm::Integer(i)),
+            ElixirTerm::Float(f) => Ok(RustTerm::Float(f)),
+            ElixirTerm::Atom(a) => Ok(RustTerm::Atom(a.to_string())),
+            ElixirTerm::Binary(s) => Ok(RustTerm::String(s)),
+            ElixirTerm::List(l) => {
+                let converted: Result<Vec<_>, _> = l.into_iter()
+                    .map(|item| item.to_rust())
+                    .collect();
+                Ok(RustTerm::List(converted?))
+            }
+            ElixirTerm::Map(m) => {
+                let mut map = std::collections::HashMap::new();
+                for (k, v) in m {
+                    map.insert(k.to_rust()?, v.to_rust()?);
+                }
+                Ok(RustTerm::Map(map))
+            }
+        }
+    }
+
+    fn to_elixir<'a>(self, env: Env<'a>) -> Result<Term<'a>, LuxError> {
+        match self {
+            ElixirTerm::Integer(i) => Ok(i.encode(env)),
+            ElixirTerm::Float(f) => Ok(f.encode(env)),
+            ElixirTerm::Atom(a) => Ok(a.encode(env)),
+            ElixirTerm::Binary(s) => Ok(s.encode(env)),
+            ElixirTerm::List(l) => {
+                let converted: Result<Vec<_>, _> = l.into_iter()
+                    .map(|item| item.to_elixir(env))
+                    .collect();
+                Ok(converted?.encode(env))
+            }
+            ElixirTerm::Map(m) => {
+                let converted: Result<Vec<_>, _> = m.into_iter()
+                    .map(|(k, v)| {
+                        let key = k.to_elixir(env)?;
+                        let val = v.to_elixir(env)?;
+                        Ok((key, val))
+                    })
+                    .collect();
+                Ok(converted?.encode(env))
+            }
+        }
+    }
+}
+
+impl TypeConversion for RustTerm {
+    type RustType = RustTerm;
+
+    fn to_rust(self) -> Result<Self::RustType, LuxError> {
+        Ok(self)
+    }
+
+    fn to_elixir<'a>(self, env: Env<'a>) -> Result<Term<'a>, LuxError> {
+        match self {
+            RustTerm::Integer(i) => Ok(i.encode(env)),
+            RustTerm::Float(f) => Ok(f.encode(env)),
+            RustTerm