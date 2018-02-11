defmodule Ueberauth.Strategy.StackOverflow.OAuth do
  require Logger

  @moduledoc """
  An implementation of OAuth2 for StackOverflow.

  To add your `client_id` and `client_secret` include these values in your configuration.

      config :ueberauth, Ueberauth.Strategy.StackOverflow.OAuth,
        client_id: System.get_env("STACKOVERFLOW_CLIENT_ID"),
        client_secret: System.get_env("STACKOVERFLOW_CLIENT_SECRET")

  Following is a full list of the possible options:

      config :ueberauth, Ueberauth.Strategy.StackOverflow.OAuth,
        client_id: System.get_env("STACKOVERFLOW_CLIENT_ID"),
        client_secret: System.get_env("STACKOVERFLOW_CLIENT_SECRET")

        filter: "!9YdnSA07B",
        server_url: "https://api.stackexchange.com",
        authorize_url: "https://stackexchange.com/oauth",
        token_url: "https://stackexchange.com/oauth/access_token",
        redirect_uri: "http://localhost:4000/auth/stackoverflow/callback"
  """
  use OAuth2.Strategy

  #"site" is used by the OAuth2 Client for url resolution
  #Stack Exchange also uses a site param, and uses of this library
  #might be more knowledgable about Stack Exchange's usage rather than
  #the OAuth2 usage. So "site" here is for Stack Exchange and "server_url"
  #is renamed in client/1 to "site"
  @defaults [
    strategy: __MODULE__,
    stackexchange_site: "stackoverflow",
    filter: "!9YdnSA07B",
    server_url: "https://api.stackexchange.com",
    authorize_url: "https://stackexchange.com/oauth",
    token_url: "https://stackexchange.com/oauth/access_token",
    redirect_uri: "http://localhost:4000/auth/stackoverflow/callback"
  ]

  @doc """
  Construct a client for requests to StackOverflow.

  Optionally include any OAuth2 options here to be merged with the defaults.

      Ueberauth.Strategy.StackOverflow.OAuth.client(redirect_uri: "http://localhost:4000/auth/stackoverflow/callback")

  This will be setup automatically for you in `Ueberauth.Strategy.StackOverflow`.
  These options are only useful for usage outside the normal callback phase of Ueberauth.
  """
  def client(opts \\ []) do
    config = config(opts)
    client_opts = config
      |> Keyword.put(:site, Keyword.get(config, :server_url))

    OAuth2.Client.new(client_opts)
  end

  def config(opts \\ []) do
    config = :ueberauth
      |> Application.fetch_env!(__MODULE__)
      |> check_config_key_exists(:api_key)
      |> check_config_key_exists(:client_id)
      |> check_config_key_exists(:client_secret)

    @defaults
      |> Keyword.merge(config)
      |> Keyword.merge(opts)
  end

  @doc """
  Provides the authorize url for the request phase of Ueberauth. No need to call this usually.
  """
  def authorize_url!(params \\ [], opts \\ []) do
    opts
    |> client
    |> OAuth2.Client.authorize_url!(params)
  end

  def get(token, url, headers \\ [], opts \\ []) do
    config = config(opts)

    #&access_token=" <> token.access_token
    query_params = %{
      "site" => "stackoverflow",
      "key" => Keyword.get(config, :api_key),
      "filter" => "!9YdnSA07B",
      "access_token" => token.access_token
    }

    #This cause me lots of headaches. It took me a long while to finally
    #figure out that hackney does not have any support for passing in a map
    #for the query params to use for a "get" request.
    #The OAuth2 library gets around this by tacking it on to the URL for us.
    #But you have to pass it in to opts[:params]
    opts = Keyword.put(opts, :params, query_params)

    client = client([token: token])

    #:hackney_trace.enable(:max, :io)

    #IO.puts "+++ using this client"
    #IO.inspect client

    OAuth2.Client.get(client, url, headers, opts)
  end

  def get_token!(params \\ [], options \\ []) do
    headers        = Keyword.get(options, :headers, [])
    options        = Keyword.get(options, :options, [])
    client_options = Keyword.get(options, :client_options, [])
    client         = OAuth2.Client.get_token!(client(client_options), params, headers, options)
    client.token
  end

  # Strategy Callbacks

  def authorize_url(client, params) do
    OAuth2.Strategy.AuthCode.authorize_url(client, params)
  end

  def get_token(client, params, headers) do
    client
    |> put_param("client_secret", client.client_secret)
    |> put_header("Accept", "application/json")
    |> OAuth2.Strategy.AuthCode.get_token(params, headers)
  end

  defp check_config_key_exists(config, key) when is_list(config) do
    unless Keyword.has_key?(config, key) do
      raise "#{inspect (key)} missing from config :ueberauth, Ueberauth.Strategy.StackOverflow"
    end
    config
  end
  defp check_config_key_exists(_, _) do
    raise "Config :ueberauth, Ueberauth.Strategy.StackOverflow is not a keyword list, as expected"
  end
end
