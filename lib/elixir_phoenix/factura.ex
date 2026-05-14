defmodule ElixirPhoenix.Factura do
  use Ecto.Schema
  import Ecto.Changeset

  schema "facturas" do
    field :num_factura, :string
    field :customer, :string
    field :employee, :string

    has_one :detalle, ElixirPhoenix.Detalle
  end

  def changeset(factura, attrs) do
    factura
    |> cast(attrs, [:num_factura, :customer, :employee])
    |> validate_required([:num_factura, :customer, :employee])
  end
end
