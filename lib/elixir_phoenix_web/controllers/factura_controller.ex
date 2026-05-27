defmodule ElixirPhoenixWeb.FacturaController do
  use ElixirPhoenixWeb, :controller
  alias ElixirPhoenix.Repo
  alias ElixirPhoenix.{Factura, Detalle}
  import Ecto.Query

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
    # 1. Validar e idéntico parseo de ID (Igual que en Express y Go)
    case Integer.parse(id_param) do
      {id, ""} ->
        # 2. Iniciar la transacción nativa en bloque (Equivalente a BEGIN)
        result =
          Repo.transaction(fn ->
            factura_query = from(f in Factura, where: f.id == ^id)

            # UPDATE directo de la cabecera (Primer viaje de escritura)
            case Repo.update_all(factura_query,
                   set: [num_factura: num_factura, customer: customer, employee: employee]
                 ) do
              {0, _} ->
                # Si afectó 0 filas, la factura no existía. Gatilla ROLLBACK automático.
                Repo.rollback(:factura_not_found)

              {1, _} ->
                # UPDATE directo del detalle (Segundo viaje de escritura)
                detalle_query = from(d in Detalle, where: d.factura_id == ^id)

                case Repo.update_all(detalle_query,
                       set: [product: product, quantity: quantity, price: price, total: total]
                     ) do
                  {0, _} ->
                    Repo.rollback(:detail_not_found)

                  {1, _} ->
                    # Obtenemos el ID del detalle de forma atómica dentro de la transacción
                    detalle_id =
                      Repo.one(from(d in Detalle, where: d.factura_id == ^id, select: d.id))

                    # Construimos las estructuras al vuelo usando los datos que ya validó la BD
                    # Esto evita los SELECT innecesarios antes de los updates.
                    factura_struct = %Factura{
                      id: id,
                      num_factura: num_factura,
                      customer: customer,
                      employee: employee
                    }

                    detalle_struct = %Detalle{
                      id: detalle_id,
                      factura_id: id,
                      product: product,
                      quantity: quantity,
                      # Casteamos a tipo decimal para respetar el formato original del changeset
                      price: Ecto.Type.cast!(:decimal, price),
                      total: Ecto.Type.cast!(:decimal, total)
                    }

                    {factura_struct, detalle_struct}
                end
            end
          end)

        # 3. Procesar el resultado de la transacción
        case result do
          {:ok, {factura, detalle}} ->
            # Si llegó aquí, la base de datos aplicó el COMMIT automáticamente
            json(conn, format_response(factura, detalle))

          {:error, :factura_not_found} ->
            conn |> put_status(:not_found) |> json(%{error: "Factura no encontrada"})

          {:error, :detail_not_found} ->
            conn
            |> put_status(:not_found)
            |> json(%{error: "Detalle no encontrado para esta factura"})

          {:error, _reason} ->
            conn
            |> put_status(:internal_server_error)
            |> json(%{error: "Error al actualizar la factura"})
        end

      _ ->
        conn |> put_status(:bad_request) |> json(%{error: "ID inválido"})
    end
  end

  def update(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "Todos los campos son requeridos"})
  end

  # DELETE /api/facturas/:id
  def delete(conn, %{"id" => id}) do
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
