defmodule ElixirPhoenixWeb.FacturaController do
  use ElixirPhoenixWeb, :controller
  alias ElixirPhoenix.Repo
  alias ElixirPhoenix.{Factura, Detalle}
  import Ecto.Query

  # Helper: Formatear respuesta idéntica a Express y Go
  defp format_response(factura, detalle) do
    %{
      id: factura.id,
      num_factura: factura.num_factura,
      customer: factura.customer,
      employee: factura.employee,
      detail: %{
        id: detalle.id,
        factura_id: detalle.factura_id,
        product: detalle.product,
        quantity: detalle.quantity,
        price: detalle.price,
        total: detalle.total
      }
    }
  end

  # GET /api/facturas/:id
  def show(conn, %{"id" => id}) do
    id = String.to_integer(id)

    query =
      from f in Factura,
        join: d in Detalle,
        on: d.factura_id == f.id,
        where: f.id == ^id,
        select: {f, d}

    case Repo.one(query) do
      nil ->
        conn |> put_status(:not_found) |> json(%{error: "Factura no encontrada"})

      {factura, detalle} ->
        json(conn, format_response(factura, detalle))
    end
  end

  # POST /api/facturas (Transaccional)
  def create(conn, %{
        "num_factura" => num_factura,
        "customer" => customer,
        "employee" => employee,
        "detail" => detail_params
      }) do
    result =
      Repo.transaction(fn ->
        factura_changeset = Factura.changeset(%Factura{}, %{
          num_factura: num_factura,
          customer: customer,
          employee: employee
        })

        case Repo.insert(factura_changeset) do
          {:ok, factura} ->
            detalle_changeset = Detalle.changeset(%Detalle{}, %{
              factura_id: factura.id,
              product: detail_params["product"],
              quantity: detail_params["quantity"],
              price: detail_params["price"],
              total: detail_params["total"]
            })

            case Repo.insert(detalle_changeset) do
              {:ok, detalle} -> {factura, detalle}
              {:error, _} -> Repo.rollback(:error_transaccional)
            end

          {:error, _} -> Repo.rollback(:error_transaccional)
        end
      end)

    case result do
      {:ok, {factura, detalle}} ->
        conn
        |> put_status(:created)
        |> json(format_response(factura, detalle))

      {:error, :error_transaccional} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Error al crear la factura transaccional"})
    end
  end

  # PUT /api/facturas/:id (Optimizado: Ejecución atómica sin SELECTs previos)
  def update(conn, %{
        "id" => id_param,
        "num_factura" => num_factura,
        "customer" => customer,
        "employee" => employee,
        "detail" => %{
          "product" => product,
          "quantity" => quantity,
          "price" => price,
          "total" => total
        }
      }) do
    id = String.to_integer(id_param)

    result =
      Repo.transaction(fn ->
        factura_query = from(f in Factura, where: f.id == ^id)

        case Repo.update_all(factura_query, set: [num_factura: num_factura, customer: customer, employee: employee]) do
          {0, _} ->
            Repo.rollback(:factura_not_found)

          {1, _} ->
            detalle_query = from(d in Detalle, where: d.factura_id == ^id)

            case Repo.update_all(detalle_query, set: [product: product, quantity: quantity, price: price, total: total]) do
              {0, _} ->
                Repo.rollback(:detail_not_found)

              {1, _} ->
                # Obtenemos el ID de forma atómica para armar el JSON de respuesta exacto
                detalle_id = Repo.one(from(d in Detalle, where: d.factura_id == ^id, select: d.id))

                factura_struct = %Factura{id: id, num_factura: num_factura, customer: customer, employee: employee}
                detalle_struct = %Detalle{id: detalle_id, factura_id: id, product: product, quantity: quantity, price: price, total: total}

                {factura_struct, detalle_struct}
            end
        end
      end)

    case result do
      {:ok, {factura, detalle}} ->
        json(conn, format_response(factura, detalle))

      {:error, :factura_not_found} ->
        conn |> put_status(:not_found) |> json(%{error: "Factura no encontrada"})

      {:error, :detail_not_found} ->
        conn |> put_status(:not_found) |> json(%{error: "Detalle no encontrado para esta factura"})

      {:error, _} ->
        conn |> put_status(:internal_server_error) |> json(%{error: "Error al actualizar la factura"})
    end
  end

  # DELETE /api/facturas/:id
  def delete(conn, %{"id" => id}) do
    id = String.to_integer(id)
    query = from(f in Factura, where: f.id == ^id)

    case Repo.delete_all(query) do
      {1, _} ->
        json(conn, %{message: "Factura eliminada correctamente"})

      {0, _} ->
        conn |> put_status(:not_found) |> json(%{error: "Factura no encontrada"})
    end
  end
end
