defmodule Ueberauth.Strategy.StackOverflow do
  @moduledoc """
  Provides an Ueberauth strategy for authenticating with StackOverflow.

  ### Setup

  Create an application in StackOverflow for you to use.

  Register a new application at: [your github developer page](https://github.com/settings/developers) and get the `client_id` and `client_secret`.

  Include the provider in your configuration for Ueberauth

      config :ueberauth, Ueberauth,
        providers: [
          github: { Ueberauth.Strategy.StackOverflow, [] }
        ]

  Then include the configuration for github.

      config :ueberauth, Ueberauth.Strategy.StackOverflow.OAuth,
        client_id: System.get_env("GITHUB_CLIENT_ID"),
        client_secret: System.get_env("GITHUB_CLIENT_SECRET")

  If you haven't already, create a pipeline and setup routes for your callback handler

      pipeline :auth do
        Ueberauth.plug "/auth"
      end

      scope "/auth" do
        pipe_through [:browser, :auth]

        get "/:provider/callback", AuthController, :callback
      end


  Create an endpoint for the callback where you will handle the `Ueberauth.Auth` struct

      defmodule MyApp.AuthController do
        use MyApp.Web, :controller

        def callback_phase(%{ assigns: %{ ueberauth_failure: fails } } = conn, _params) do
          # do things with the failure
        end

        def callback_phase(%{ assigns: %{ ueberauth_auth: auth } } = conn, params) do
          # do things with the auth
        end
      end

  You can edit the behaviour of the Strategy by including some options when you register your provider.

  To set the `uid_field`

      config :ueberauth, Ueberauth,
        providers: [
          github: { Ueberauth.Strategy.StackOverflow, [uid_field: :email] }
        ]

  Default is `:id`

  To set the default 'scopes' (permissions):

      config :ueberauth, Ueberauth,
        providers: [
          github: { Ueberauth.Strategy.StackOverflow, [default_scope: "user,public_repo"] }
        ]

  Default is "user,public_repo"
  """
  use Ueberauth.Strategy, uid_field: :id,
                          default_scope: "user,public_repo",
                          oauth2_module: Ueberauth.Strategy.StackOverflow.OAuth

  alias Ueberauth.Auth.Info
  alias Ueberauth.Auth.Credentials
  alias Ueberauth.Auth.Extra

  @doc """
  Handles the initial redirect to the github authentication page.

  To customize the scope (permissions) that are requested by github include them as part of your url:

      "/auth/github?scope=user,public_repo,gist"

  You can also include a `state` param that github will return to you.
  """
  def handle_request!(conn) do
    scopes = conn.params["scope"] || option(conn, :default_scope)
    send_redirect_uri = Keyword.get(options(conn), :send_redirect_uri, true)

    opts =
      if send_redirect_uri do
        [redirect_uri: callback_url(conn), scope: scopes]
      else
        [scope: scopes]
      end

    opts =
      if conn.params["state"], do: Keyword.put(opts, :state, conn.params["state"]), else: opts

    module = option(conn, :oauth2_module)
    redirect!(conn, apply(module, :authorize_url!, [opts]))
  end

  @doc """
  Handles the callback from StackOverflow. When there is a failure from StackOverflow the failure is included in the
  `ueberauth_failure` struct. Otherwise the information returned from StackOverflow is returned in the `Ueberauth.Auth` struct.
  """
  def handle_callback!(%Plug.Conn{params: %{"code" => code}} = conn) do
    module = option(conn, :oauth2_module)
    token = apply(module, :get_token!, [[code: code]])

    if token.access_token == nil do
      set_errors!(conn, [error(token.other_params["error"], token.other_params["error_description"])])
    else
      fetch_user(conn, token)
    end
  end

  @doc false
  def handle_callback!(conn) do
    set_errors!(conn, [error("missing_code", "No code received")])
  end

  @doc """
  Cleans up the private area of the connection used for passing the raw StackOverflow response around during the callback.
  """
  def handle_cleanup!(conn) do
    conn
    |> put_private(:stackoverflow_user, nil)
    |> put_private(:stackoverflow_token, nil)
  end

  @doc """
  Fetches the uid field from the StackOverflow response. This defaults to the option `account_id`
  """
  def uid(conn) do
    user = conn.private.stackoverflow_user

    #user_id is the "per site" user id (so StackOverflow would have a different user_id than superuser)
    #account_id is the whole/global Stack Exchange account id
    user["account_id"]
  end

  @doc """
  Includes the credentials from the StackOverflow response.
  """
  def credentials(conn) do
    IO.puts "+++ credentials/1"
    IO.inspect conn.private.stackoverflow_token

    token        = conn.private.stackoverflow_token
    scope_string = (token.other_params["scope"] || "")
    scopes       = String.split(scope_string, ",")

    %Credentials{
      token: token.access_token,
      refresh_token: token.refresh_token,
      expires_at: token.expires_at,
      token_type: token.token_type,
      expires: !!token.expires_at,
      scopes: scopes
    }
  end

  @doc """
  Fetches the fields to populate the info section of the `Ueberauth.Auth` struct.
  """
  def info(conn) do
    user = conn.private.stackoverflow_user

    %Info{
      name: user["display_name"],

      #We could parse out a name from the profile url, but I would rather not
      nickname: nil,

      #It sucks but email is not returned in the /user API calls
      email: nil,

      location: user["location"],
      image: user["profile_image"],
      urls: %{
        website_url: user["website_url"],
        link: user["link"]
      }
    }
  end

  @doc """
  Stores the raw information (including the token) obtained from the StackOverflow callback.
  """
  def extra(conn) do
    %Extra {
      raw_info: %{
        token: conn.private.stackoverflow_token,
        user: conn.private.stackoverflow_user
      }
    }
  end

  defp fetch_user(conn, token) do
    conn = put_private(conn, :stackoverflow_token, token)
    # Will be better with Elixir 1.3 with/else
    case Ueberauth.Strategy.StackOverflow.OAuth.get(token, "/2.2/me") do
      {:ok, %OAuth2.Response{status_code: 401, body: _body}} ->
        set_errors!(conn, [error("token", "unauthorized")])
      {:ok, %OAuth2.Response{status_code: status_code, body: user}} when status_code in 200..399 ->
        [ user | _ ] =  user["items"]
        put_private(conn, :stackoverflow_user, user)
      {:error, %OAuth2.Error{reason: reason}} ->
        set_errors!(conn, [error("OAuth2", reason)])
    end
  end

  defp option(conn, key) do
    Keyword.get(options(conn), key, Keyword.get(default_options(), key))
  end
end
