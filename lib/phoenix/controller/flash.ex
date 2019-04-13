defmodule Phoenix.Controller.Flash do
  import Plug.Conn

  @moduledoc """
  Helper module to fetch the flash message.

  This helper will look at the session for a "phoenix_flash"
  If none found, then it will look for a signed cookie named
  "__phoenix_flash___"

  ## Examples

      plug :fetch_flash

  By default, the signing salt for the token is pulled from
  your endpoint's LiveView config, for example:

      config :my_app, MyAppWeb.Endpoint,
        ...,
        live_view: [signing_salt: ...]

  The `:signing_salt` option may also be passed via the `opts`
  """

  @session_key "phoenix_flash"
  @client_key "__phoenix_flash___"
  @session_atom :phoenix_flash
  @salt_length 8

  @doc """
  Fetches the flash from server, or a signed message from the client

  We will look for a flash message in the `session_key`, and if none
  found then we will look in client cookie (under the name
  `__session_key___`)
  """
  def fetch_flash(conn, opts \\ []) do
    case get_cookie(conn, salt(conn, opts)) do
      {conn, nil} -> fetch_from_session(conn, opts)
      {conn, flash} ->
        conn
        |> put_session(@session_key, flash)
        |> fetch_from_session(opts)
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

  defp fetch_from_session(conn, _opts) do
    session_flash = get_session(conn, @session_key)
    conn = persist_flash(conn, session_flash || %{})

    register_before_send conn, fn conn ->
      flash = conn.private[@session_atom]
      flash_size = map_size(flash)

      cond do
        is_nil(session_flash) and flash_size == 0 ->
          conn
        flash_size > 0 and conn.status in 300..308 ->
          put_session(conn, @session_key, flash)
        true ->
          delete_session(conn, @session_key)
      end
    end
  end

  defp get_cookie(conn, opts) do
    IO.puts "GET COOKIE 3"

    conn.cookies
    |> IO.inspect()
    |> Map.get(@client_key)
    |> case do
      nil -> nil
      token -> case Phoenix.Token.verify(conn, salt(conn, opts), token, max_age: 60_000) do
        {:ok, json_flash} -> IO.puts("TOKEN: #{token}") ; Phoenix.json_library().decode!(json_flash)
        {:error, reason} -> IO.puts("ERROR: #{reason}") ; nil
      end
    end
    |> case do
      nil -> {conn, nil}
      found -> {Plug.Conn.delete_resp_cookie(conn, @client_key), found}
    end
  end

  defp salt(conn, opts) do
    endpoint = Phoenix.Controller.endpoint_module(conn)

    salt_base = opts[:signing_salt] || configured_liveview_salt!(endpoint)
    computed_salt(salt_base)
  end

  defp computed_salt(salt_base), do: salt_base <> "flash"

  def configured_liveview_salt!(endpoint) when is_atom(endpoint) do
    endpoint.config(:live_view)[:signing_salt] ||
      raise ArgumentError, """
      no signing salt found for #{inspect(endpoint)}.

      Add the following LiveView configuration to your config/config.exs:

          config :my_app, MyApp.Endpoint,
              ...,
              live_view: [signing_salt: "#{random_signing_salt()}"]

      """
  end

  @doc false
  def sign_token(endpoint_mod, salt_base, %{} = flash) do
    salt = computed_salt(salt_base)
    Phoenix.Token.sign(endpoint_mod, salt, Phoenix.json_library().encode!(flash))
  end

  defp random_signing_salt do
    @salt_length
    |> :crypto.strong_rand_bytes()
    |> Base.encode64()
    |> binary_part(0, @salt_length)
  end

end
