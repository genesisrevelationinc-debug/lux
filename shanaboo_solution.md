 ```diff
--- a/lux/mix.exs
+++ b/lux/mix.exs
@@ -1,4 +1,5 @@
 defmodule Lux.MixProject do
+  @moduledoc false
   use Mix.Project
 
   def project do
@@ -7,7 +8,8 @@ defmodule Lux.MixProject do
       version: "0.1.0",
       elixir: "~> 1.14",
       start_permanent: Mix.env() == :prod,
-      deps: deps()
+      deps: deps(),
+      compilers: [:rustler] ++ Mix.compilers()
     ]
   end
 
@@ -21,7 +23,8 @@ defmodule Lux.MixProject do
   # Run "mix help deps" to learn about dependencies.
   defp deps do
     [
-      # {:dep_from_hexpm, "~> 0.3.0"},
+      {:rustler, "~> 0.30.0", runtime: false},
+      {:rustler_precompiled, "~> 0.7"}
       # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
     ]
   end
--- /dev/null
+++ b/lux/lib/lux/rust.ex
@@ -0,0 +1,85 @@
+defmodule Lux.Rust do
+  @moduledoc """
+  Core Rust integration module for Lux.
+
+  Provides FFI bindings to Rust NIFs for high-performance operations.
+  """
+
+  alias Lux.Rust.Native
+
+  @doc """
+  Adds two integers using Rust.
+
+  ## Examples
+
+      iex> Lux.Rust.add(1, 2)
+  3
+
+  """
+  @spec add(integer(), integer()) :: integer()
+  def add(a, b) do
+    Native.add(a, b)
+  end
+
+  @doc """
+  Converts an Elixir string to uppercase using Rust.
+
+  ## Examples
+
+      iex> Lux.Rust.to_uppercase("hello")
+  "HELLO"
+
+  """
+  @spec to_uppercase(String.t()) :: String.t()
+  def to_uppercase(str) do
+    Native.to_uppercase(str)
+  end
+
+  @doc """
+  Computes the length of a list using Rust.
+
+  ## Examples
+
+      iex> Lux.Rust.list_length([1, 2, 3])
+  3
+
+  """
+  @spec list_length(list()) :: non_neg_integer()
+  def list_length(list) do
+    Native.list_length(list)
+  end
+
+  @doc """
+  Converts a map to a JSON string using Rust.
+
+  ## Examples
+
+      iex> Lux.Rust.map_to_json(%{"key" => "value"})
+  ~s({"key":"value"})
+
+  """
+  @spec map_to_json(map()) :: String.t()
+  def map_to_json(map) do
+    Native.map_to_json(map)
+  end
+
+  @doc """
+  Parses a JSON string to a map using Rust.
+
+  ## Examples
+
+      iex> Lux.Rust.json_to_map(~s({"key":"value"}))
+  %{"key" => "value"}
+
+  """
+  @spec json_to_map(String.t()) :: {:ok, map()} | {:error, String.t()}
+  def json_to_map(json) do
+    case Native.json_to_map(json) do
+      {:ok, map} -> {:ok, map}
+      {:error, reason} -> {:error, reason}
+      other -> other
+    end
+  end
+end
--- /dev/null
+++ b/lux/lib/lux/rust/native.ex
@@ -0,0 +1,24 @@
+defmodule Lux.Rust.Native do
+  @moduledoc """
+  NIF bindings for the Rust core.
+
+  This module uses Rustler to load the native implementation.
+  """
+
+  use Rustler,
+    otp_app: :lux,
+    crate: "lux_rust",
+    base_metadata: "lux_rust"
+
+  # NIF functions are defined here with their signatures
+  def add(_a, _b), do: :erlang.nif_error(:nif_not_loaded)
+
+  def to_uppercase(_str), do: :erlang.nif_error(:nif_not_loaded)
+
+  def list_length(_list), do: :erlang.nif_error(:nif_not_loaded)
+
+  def map_to_json(_map), do: :erlang.nif_error(:nif_not_loaded)
+
+  def json_to_map(_json), do: :erlang.nif_error(:nif_not_loaded)
+
+  def echo(_term), do: :erlang.nif_error(:nif_not_loaded)
+end
--- /dev/null
+++ b/lux/lib/lux/rust/error.ex
@@ -0,0 +1,40 @@
+defmodule Lux.Rust.Error do
+  @moduledoc """
+  Error handling for Rust NIF operations.
+
+  Provides structured error types for FFI boundary failures.
+  """
+
+  defexception [:message, :type, :source]
+
+  @type t :: %__MODULE__{
+          message: String.t(),
+          type: atom(),
+          source: term() | nil
+        }
+
+  @doc """
+  Creates a new Rust error.
+  """
+  @spec new(String.t(), atom(), term() | nil) :: t()
+  def new(message, type \\ :unknown, source \\ nil) do
+    %__MODULE__{
+      message: message,
+      type: type,
+      source: source
+    }
+  end
+
+  @doc """
+  Converts a Rust error to a string representation.
+  """
+  @spec to_string(t()) :: String.t()
+  def to_string(%__MODULE__{} = error) do
+    "Rust Error [#{error.type}]: #{error.message}"
+  end
+
+  defimpl String.Chars do
+    def to_string(error) do
+      Lux.Rust.Error.to_string(error)
+    end
+  end
+end
--- /dev/null
+++ b/lux/lib/lux/rust/type_conversion.ex
@@ -0,0 +1,85 @@
+defmodule Lux.Rust.TypeConversion do
+  @moduledoc """
+  Type conversion utilities between Elixir and Rust types.
+
+  Handles safe conversion of primitive types across the FFI boundary.
+  """
+
+  @doc """
+  Converts an Elixir term to a Rust-compatible representation.
+
+  ## Examples
+
+