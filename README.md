# A Couple Quick Notes
This is not ready for public consumption yet. This is in
alpha stage and there are some issues that need to be sorted out before it will
be ready for others to use. (i.e. handling gzipped compression). The gzipped
compression probably should be handled in hackney (which is what most of the
ueberauth strategies use). There is [an outstanding
issue](https://github.com/benoitc/hackney/issues/155) for this and I'm looking
at submitting a PR for this feature.

Secondly - The Stack Exchange API does not return any email address for the
user. So if you are wanting to use this to get at that kind of information,
you might look else where or plan on asking the user for an email. See [this answer]( https://stackoverflow.com/questions/37026028/how-to-get-stackexchange-users-email-id-through-the-api).

# Überauth StackOverflow

> StackOverflow OAuth2 strategy for Überauth.

## Installation

1. Setup your application at [Stack Apps](https://stackapps.com/apps/oauth/register).

1. Add `:ueberauth_stackoverflow` to your list of dependencies in `mix.exs`:

    ```elixir
    def deps do
      [{:ueberauth_stackoverflow, "~> 0.0.1"}]
    end
    ```

1. Add the strategy to your applications:

    ```elixir
    def application do
      [applications: [:ueberauth_stackoverflow]]
    end
    ```

1. Add StackOverflow to your Überauth configuration:

    ```elixir
    config :ueberauth, Ueberauth,
      providers: [
        stackoverflow: {Ueberauth.Strategy.StackOverflow, []}
      ]
    ```

1.  Update your provider configuration:

    ```elixir
    config :ueberauth, Ueberauth.Strategy.StackOverflow.OAuth,
      client_id: System.get_env("STACKOVERFLOW_CLIENT_ID"),
      client_secret: System.get_env("STACKOVERFLOW_CLIENT_SECRET")
    ```

1.  Include the Überauth plug in your controller:

    ```elixir
    defmodule MyApp.AuthController do
      use MyApp.Web, :controller

      pipeline :browser do
        plug Ueberauth
        ...
       end
    end
    ```

1.  Create the request and callback routes if you haven't already:

    ```elixir
    scope "/auth", MyApp do
      pipe_through :browser

      get "/:provider", AuthController, :request
      get "/:provider/callback", AuthController, :callback
    end
    ```

1. You controller needs to implement callbacks to deal with `Ueberauth.Auth` and `Ueberauth.Failure` responses.

For an example implementation see the [Überauth Example](https://github.com/ueberauth/ueberauth_example) application.

## Calling

Depending on the configured url you can initial the request through:

    /auth/stackoverflow

Or with options:

    /auth/stackoverflow?scope=no_expiry

By default the requested scope is "". This provides "an application to identify a user via the /me method". See more at [StackOverflow's OAuth Documentation](http://api.stackexchange.com/docs/authentication#scope). Scope can be configured either explicitly as a `scope` query value on the request path or in your configuration:

```elixir
config :ueberauth, Ueberauth,
  providers: [
    stackoverflow: {Ueberauth.Strategy.StackOverflow, [default_scope: "private_info no_expiry"]}
  ]
```

It is also possible to disable the sending of the `redirect_uri` to StackOverflow. This is particularly useful
when your production application sits behind a proxy that handles SSL connections. In this case,
the `redirect_uri` sent by `Ueberauth` will start with `http` instead of `https`, and if you configured
your StackOverflow OAuth application's callback URL to use HTTPS, StackOverflow will throw an `uri_missmatch` error.

To prevent `Ueberauth` from sending the `redirect_uri`, you should add the following to your configuration:

```elixir
config :ueberauth, Ueberauth,
  providers: [
    stackoverflow: {Ueberauth.Strategy.StackOverflow, [send_redirect_uri: false]}
  ]
```

## License

Please see [LICENSE](https://github.com/cgorshing/ueberauth_stackoverflow/blob/master/LICENSE) for licensing details.
