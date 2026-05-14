defmodule ElixirPhoenix.Detalle do
  use Ecto.Schema
  import Ecto.Changeset

  schema "detalles" do
    field :product,    :string
    field :quantity,   :integer
    field :price,      :float
    field :total,      :float

    belongs_to :factura, ElixirPhoenix.Factura
  end

  def changeset(detalle, attrs) do
    detalle
    |> cast(attrs, [:product, :quantity, :price, :total, :factura_id])
    |> validate_required([:product, :quantity, :price, :total, :factura_id])
  end
end
