defmodule Phoenix.Controller.Flash do
  import Plug.Conn

  @moduledoc """
  Helper module to fetch the flash message.

  This helper will look at the session for a "phoenix_flash"

  ## Examples

      plug :fetch_flash
  """

  @session_key "phoenix_flash"
  @session_atom :phoenix_flash

  @doc """
  Fetches the flash from server, or a signed message from the client

  We will look for a flash message in the `session_key`, and if none
  found then we will look in client cookie (under the name
  `__session_key___`)
  """
  def fetch_flash(conn, _opts \\ []) do
    found_flash = get_session(conn, @session_key)
    conn = persist_flash(conn, found_flash || %{})

    register_before_send conn, fn conn ->
      flash = conn.private.phoenix_flash
      flash_size = map_size(flash)

      cond do
        is_nil(found_flash) and flash_size == 0 ->
          conn
        flash_size > 0 and conn.status in 300..308 ->
          put_session(conn, @session_key, flash)
        true ->
          delete_session(conn, @session_key)
      end
    end
  end

  @doc """
  Clears all flash messages.
  """
  def clear_flash(conn) do
    persist_flash(conn, %{})
  end

  @doc false
  def flash_key(binary) when is_binary(binary), do: binary
  def flash_key(atom) when is_atom(atom), do: Atom.to_string(atom)

  @doc """
  Persists a value in flash.
  """
  def put_flash(conn, key, message) do
    persist_flash(conn, Map.put(get_flash(conn), flash_key(key), message))
  end

  @doc """
  Returns a map of previously set flash messages or an empty map.
  """
  def get_flash(conn) do
    Map.get(conn.private, @session_atom) ||
      raise ArgumentError, message: "flash not fetched, call fetch_flash/2"
  end

  @doc """
  Returns a message from flash by `key`.
  """
  def get_flash(conn, key) do
    get_flash(conn)[flash_key(key)]
  end

  defp persist_flash(conn, value) do
    put_private(conn, @session_atom, value)
  end

end
