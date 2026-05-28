```diff
--- a/lux/mix.exs
+++ b/lux/mix.exs
@@ -1,4 +1,5 @@
 defmodule Lux.MixProject do
+  @moduledoc false
   use Mix.Project
 
   def project do
@@ -6,7 +7,8 @@ defmodule Lux.MixProject do
       app: :lux,
       version: "0.1.0",
       elixir: "~> 1.18",
-      start_permanent: Mix.env() == :prod,
+      elixirc_paths: elixirc_paths(Mix.env()),
+      compilers: [:rustler] ++ Mix.compilers(),
       deps: deps()
     ]
   end
@@ -21,7 +23,12 @@ defmodule Lux.MixProject do
   defp deps do
     [
       {:jason, "~> 1.4"},
-      {:ex_doc, "~> 0.31", only: :dev, runtime: false}
+      {:ex_doc, "~> 0.31", only: :dev, runtime: false},
+      {:rustler, "~> 0.32.0"}
     ]
   end
+
+  defp elixirc_paths(:test), do: ["lib", "test/support"]
+  defp elixirc_paths(_), do: ["lib"]
 end
--- /dev/null
+++ b/lux/lib/lux/rust.ex
@@ -0,0 +1,76 @@
+defmodule Lux.Rust do
+  @moduledoc """
+  Core Rust integration module for Lux.
+
+  Provides NIF-based bindings to Rust code for high-performance operations.
+  """
+
+  alias Lux.Rust.Converter
+
+  @doc """
+  Converts an Elixir term to its Rust representation.
+
+  ## Examples
+
+      iex> Lux.Rust.to_rust(42)
+      {:ok, 42}
+
+      iex> Lux.Rust.to_rust("hello")
+      {:ok, "hello"}
+  """
+  @spec to_rust(term()) :: {:ok, term()} | {:error, term()}
+  def to_rust(term) do
+    Converter.to_rust(term)
+  end
+
+  @doc """
+  Converts a Rust term back to Elixir.
+
+  ## Examples
+
+      iex> Lux.Rust.to_elixir(42)
+      {:ok, 42}
+  """
+  @spec to_elixir(term()) :: {:ok, term()} | {:error, term()}
+  def to_elixir(term) do
+    Converter.to_elixir(term)
+  end
+
+  @doc """
+  Executes a Rust function with the given arguments.
+
+  ## Examples
+
+      iex> Lux.Rust.call("math", "add", [1, 2])
+      {:ok, 3}
+
+      iex> Lux.Rust.call("math", "divide", [1, 0])
+      {:error, "division by zero"}
+  """
+  @spec call(String.t(), String.t(), list()) :: {:ok, term()} | {:error, term()}
+  def call(module, function, args) do
+    try do
+      Lux.Rust.Nif.call(module, function, args)
+    rescue
+      error -> {:error, Exception.message(error)}
+    end
+  end
+
+  @doc """
+  Returns version information for the Rust NIF.
+  """
+  @spec version() :: String.t()
+  def version do
+    Lux.Rust.Nif.version()
+  end
+end
--- /dev/null
+++ b/lux/lib/lux/rust/converter.ex
@@ -0,0 +1,85 @@
+defmodule Lux.Rust.Converter do
+  @moduledoc """
+  Handles type conversion between Elixir and Rust types.
+
+  Supports primitive types, collections, and custom structs.
+  """
+
+  @doc """
+  Converts an Elixir term to a Rust-compatible representation.
+
+  ## Supported types
+
+  - Integers (i32, i64)
+  - Floats (f64)
+  - Strings (String)
+  - Booleans (bool)
+  - Lists (Vec<T>)
+  - Maps (HashMap<K, V>)
+  - Tuples (up to 4 elements)
+  - nil -> Option::None
+  """
+  @spec to_rust(term()) :: {:ok, term()} | {:error, term()}
+  def to_rust(nil), do: {:ok, :none}
+  def to_rust(true), do: {:ok, true}
+  def to_rust(false), do: {:ok, false}
+
+  def to_rust(term) when is_integer(term) do
+    {:ok, term}
+  end
+
+  def to_rust(term) when is_float(term) do
+    {:ok, term}
+  end
+
+  def to_rust(term) when is_binary(term) do
+    {:ok, term}
+  end
+
+  def to_rust(term) when is_list(term) do
+    result =
+      Enum.reduce_while(term, {:ok, []}, fn item, {:ok, acc} ->
+        case to_rust(item) do
+          {:ok, converted} -> {:cont, {:ok, [converted | acc]}}
+          {:error, reason} -> {:halt, {:error, reason}}
+        end
+      end)
+
+    case result do
+      {:ok, list} -> {:ok, Enum.reverse(list)}
+      error -> error
+    end
+  end
+
+  def to_rust(term) when is_map(term) do
+    result =
+      Enum.reduce_while(term, {:ok, %{}}, fn {key, value}, {:ok, acc} ->
+        with {:ok, rust_key} <- to_rust(key),
+              {:ok, rust_value} <- to_rust(value) do
+          {:cont, {:ok, Map.put(acc, rust_key, rust_value)}}
+        else
+          {:error, reason} -> {:halt, {:error, reason}}
+        end
+      end)
+
+    case result do
+      {:ok, map} -> {:ok, map}
+      error -> error
+    end
+  end
+
+  def to_rust(term) when is_tuple(term) do
+    to_rust(Tuple.to_list(term))
+  end
+
+  def to_rust(_term) do
+    {:error, :unsupported_type}
+  end
+
+  @doc """
+  Converts a Rust term back to Elixir. Currently a pass-through for supported types.
+  """
+ 