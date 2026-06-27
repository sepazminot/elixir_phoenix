defmodule ElixirPhoenixWeb.UserController do
  use ElixirPhoenixWeb, :controller
  alias ElixirPhoenix.Repo
  alias ElixirPhoenix.User
  import Ecto.Query

  # GET /api/users/:id
  def show(conn, %{"id" => id}) do
    id = String.to_integer(id)

    case Repo.get(User, id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Usuario no encontrado"})

      user ->
        json(conn, %{
          id: user.id,
          email: user.email,
          password: user.password
        })
    end
  end

  # POST /api/users
  def create(conn, %{"email" => email, "password" => password}) do
    changeset = User.changeset(%User{}, %{email: email, password: password})

    case Repo.insert(changeset) do
      {:ok, user} ->
        conn
        |> put_status(:created)
        |> json(%{
          id: user.id,
          email: user.email,
          password: user.password
        })

      {:error, _changeset} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Error al crear el usuario"})
    end
  end

  # PUT /api/users/:id (Optimizado: Sin SELECT previo, un solo viaje a la BD)
  def update(conn, %{"id" => id, "email" => email, "password" => password}) do
    id = String.to_integer(id)
    query = from(u in User, where: u.id == ^id)

    case Repo.update_all(query, set: [email: email, password: password]) do
      {0, _} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Usuario no encontrado"})

      {1, _} ->
        json(conn, %{
          id: id,
          email: email,
          password: password
        })
    end
  end

  # DELETE /api/users/:id (Optimizado: Eliminación directa)
  def delete(conn, %{"id" => id}) do
    id = String.to_integer(id)
    query = from(u in User, where: u.id == ^id)

    case Repo.delete_all(query) do
      {1, _} ->
        json(conn, %{message: "Usuario eliminado"})

      {0, _} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Usuario no encontrado"})
    end
  end
end
