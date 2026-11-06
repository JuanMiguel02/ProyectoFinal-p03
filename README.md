# GestionEmergencias

**TODO: Add description**

Los constructores de las entidades generan internamente su identificador UUID;
el ID propio no se acepta como argumento. Los IDs de entidades relacionadas
(por ejemplo, `id_zona` o `id_usuario`) siguen siendo argumentos del constructor.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `gestion_emergencias` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:gestion_emergencias, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/gestion_emergencias>.
