defmodule ElixirPhoenixWeb.UserController do
  use ElixirPhoenixWeb, :controller
  alias ElixirPhoenix.Repo
  alias ElixirPhoenix.User

  # GET /api/users/:id
  def show(conn, %{"id" => id}) do
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

      {:error, changeset} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Error al crear usuario: #{inspect(changeset.errors)}"})
    end
  end

  # PUT /api/users/:id
  def update(conn, %{"id" => id, "email" => email, "password" => password}) do
    case Repo.get(User, id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Usuario no encontrado"})

      user ->
        changeset = User.changeset(user, %{email: email, password: password})

        case Repo.update(changeset) do
          {:ok, updated_user} ->
            json(conn, %{
              id: updated_user.id,
              email: updated_user.email,
              password: updated_user.password
            })

          {:error, changeset} ->
            conn
            |> put_status(:bad_request)
            |> json(%{error: "Error al actualizar: #{inspect(changeset.errors)}"})
        end
    end
  end

  # DELETE /api/users/:id
  def delete(conn, %{"id" => id}) do
    case Repo.get(User, id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Usuario no encontrado"})

      user ->
        case Repo.delete(user) do
          {:ok, deleted_user} ->
            json(conn, %{
              id: deleted_user.id,
              email: deleted_user.email,
              password: deleted_user.password,
              message: "Usuario eliminado"
            })

          {:error, changeset} ->
            conn
            |> put_status(:internal_server_error)
            |> json(%{error: "Error al eliminar: #{inspect(changeset.errors)}"})
        end
    end
  end
end
