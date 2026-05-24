defmodule ElixirPhoenixWeb.FacturaController do
  use ElixirPhoenixWeb, :controller
  alias ElixirPhoenix.Repo
  alias ElixirPhoenix.{Factura, Detalle}

  # Helper: Formatear respuesta
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
    import Ecto.Query

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

  # POST /api/facturas
  def create(conn, %{
        "num_factura" => num_factura,
        "customer" => customer,
        "employee" => employee,
        "detail" => detail_params
      }) do
    result =
      Repo.transaction(fn ->
        # 1. Insertar factura
        factura_changeset =
          Factura.changeset(%Factura{}, %{
            num_factura: num_factura,
            customer: customer,
            employee: employee
          })

        case Repo.insert(factura_changeset) do
          {:ok, factura} ->
            # 2. Insertar detalle
            detalle_changeset =
              Detalle.changeset(%Detalle{}, %{
                factura_id: factura.id,
                product: detail_params["product"],
                quantity: detail_params["quantity"],
                price: detail_params["price"],
                total: detail_params["total"]
              })

            case Repo.insert(detalle_changeset) do
              {:ok, detalle} ->
                {factura, detalle}

              {:error, changeset} ->
                Repo.rollback({:detalle_error, changeset})
            end

          {:error, changeset} ->
            Repo.rollback({:factura_error, changeset})
        end
      end)

    case result do
      {:ok, {factura, detalle}} ->
        conn
        |> put_status(:created)
        |> json(format_response(factura, detalle))

      {:error, {:factura_error, changeset}} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Error al crear factura: #{inspect(changeset.errors)}"})

      {:error, {:detalle_error, changeset}} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Error al crear detalle: #{inspect(changeset.errors)}"})
    end
  end

  # PUT /api/facturas/:id
  def update(conn, %{
        "id" => id,
        "num_factura" => num_factura,
        "customer" => customer,
        "employee" => employee,
        "detail" => detail_params
      }) do
    result =
      Repo.transaction(fn ->
        # 1. Buscar factura
        case Repo.get(Factura, id) do
          nil ->
            Repo.rollback(:not_found)

          factura ->
            # 2. Actualizar factura
            factura_changeset =
              Factura.changeset(factura, %{
                num_factura: num_factura,
                customer: customer,
                employee: employee
              })

            case Repo.update(factura_changeset) do
              {:ok, updated_factura} ->
                # 3. Buscar y actualizar detalle
                case Repo.get_by(Detalle, factura_id: id) do
                  nil ->
                    Repo.rollback(:detail_not_found)

                  detalle ->
                    detalle_changeset =
                      Detalle.changeset(detalle, %{
                        product: detail_params["product"],
                        quantity: detail_params["quantity"],
                        price: detail_params["price"],
                        total: detail_params["total"]
                      })

                    case Repo.update(detalle_changeset) do
                      {:ok, updated_detalle} ->
                        {updated_factura, updated_detalle}

                      {:error, changeset} ->
                        Repo.rollback({:detalle_error, changeset})
                    end
                end

              {:error, changeset} ->
                Repo.rollback({:factura_error, changeset})
            end
        end
      end)

    case result do
      {:ok, {factura, detalle}} ->
        json(conn, format_response(factura, detalle))

      :not_found ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Factura no encontrada"})

      :detail_not_found ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Detalle no encontrado para esta factura"})

      {:error, {:factura_error, changeset}} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Error al actualizar factura: #{inspect(changeset.errors)}"})

      {:error, {:detalle_error, changeset}} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Error al actualizar detalle: #{inspect(changeset.errors)}"})
    end
  end

  # DELETE /api/facturas/:id
  def delete(conn, %{"id" => id}) do
    import Ecto.Query

    # Genera una query filtrada por el ID
    query = from(f in Factura, where: f.id == ^id)

    # Borra directamente en la base de datos (Devuelve {cantidad_borrada, nil})
    case Repo.delete_all(query) do
      {1, _} ->
        json(conn, %{id: id, message: "Factura eliminada"})

      {0, _} ->
        conn |> put_status(:not_found) |> json(%{error: "Factura no encontrada"})
    end
  end
end
