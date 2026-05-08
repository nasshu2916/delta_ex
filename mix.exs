defmodule DeltaEx.MixProject do
  use Mix.Project

  def project do
    [
      app: :delta_ex,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      description: description(),
      package: package(),
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps(),
      name: "DeltaEx",
      source_url: "https://github.com/nasshu2916/delta_ex",
      docs: [
        main: "DeltaEx",
        extras: ["README.md", "DEVELOPMENT.md", "LICENSE"]
      ],
      aliases: aliases(),
      elixirc_options: [warnings_as_errors: true],
      dialyzer: [
        plt_add_apps: [:ex_unit, :mix],
        flags: [:error_handling, :underspecs]
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp description do
    "DeltaEx is an Elixir wrapper for Delta Lake (delta-rs) using Rustler NIFs."
  end

  defp package do
    [
      name: "delta_ex",
      licenses: ["Apache-2.0"],
      maintainers: ["nasshu2916"],
      files: [
        "lib",
        "native/delta_ex_native/src",
        "native/delta_ex_native/Cargo.toml",
        "native/delta_ex_native/Cargo.lock",
        "native/delta_ex_native/.cargo",
        "mix.exs",
        "README.md",
        "DEVELOPMENT.md",
        "LICENSE"
      ],
      links: %{"GitHub" => "https://github.com/nasshu2916/delta_ex"}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:rustler, "~> 0.37.3"},
      {:telemetry, "~> 1.3"},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get", "cmd cd native/delta_ex_native && cargo fetch"],
      fix: ["format", "credo --strict", "cargo.fmt", "cargo.clippy.fix"],
      ci: ["fix", "dialyzer", "test"],
      "cargo.test": "cmd cd native/delta_ex_native && cargo test",
      "cargo.fmt": "cmd cd native/delta_ex_native && cargo fmt",
      "cargo.check": "cmd cd native/delta_ex_native && cargo check",
      "cargo.clippy": "cmd cd native/delta_ex_native && cargo clippy",
      "cargo.clippy.fix":
        "cmd cd native/delta_ex_native && cargo clippy --fix --allow-dirty --allow-staged"
    ]
  end
end
