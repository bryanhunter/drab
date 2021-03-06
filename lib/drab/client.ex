defmodule Drab.Client do
  @moduledoc """
  Enable Drab on the browser side. Must be included in HTML template, for example 
  in `web/templates/layout/app.html.eex`:

      <%= Drab.Client.js(@conn) %>

  after the line which loads app.js:

      <script src="<%= static_path(@conn, "/js/app.js") %>"></script>
  """

  import Drab.Template
  require Logger

  @doc """
  Generates JS code which runs Drab. Passes controller and action name, tokenized for safety.
  Runs only when the controller which renders current action has been compiled
  with `use Drab.Controller`.

  Optional argument may be a list of parameters which will be added to assigns to the socket.
  Example of `layout/app.html.eex`:

      <%= Drab.Client.js(@conn) %>
      <%= Drab.Client.js(@conn, user_id: 4, any_other: "test") %>

  Please remember that your parameters are passed to the browser as Phoenix Token. Token is signed, 
  but not ciphered. Do not put any secret data in it.

  On the browser side, there is a global object `Drab`, which you may use to create your own channels
  inside Drab Socket:

      ch = Drab.socket.channel("mychannel:whatever")
      ch.join()
  """
  def js(conn, assigns \\ []) do
    controller = Phoenix.Controller.controller_module(conn)
    # Enable Drab only if Controller compiles with `use Drab.Controller`
    # in this case controller contains function `__drab__/0`
    if Enum.member?(controller.__info__(:functions), {:__drab__, 0}) do
      controller_and_action = Phoenix.Token.sign(conn, "controller_and_action", 
                              # "#{controller}##{Phoenix.Controller.action_name(conn)}")
                              [__controller: controller, 
                               __action: Phoenix.Controller.action_name(conn), 
                               __assigns: assigns])
      commander = controller.__drab__()[:commander]
      modules = [Drab.Core | commander.__drab__().modules] # Drab.Core is included by default
      templates = Enum.map(modules, fn x -> "#{Module.split(x) |> Enum.join(".") |> String.downcase()}.js" end)

      access_store = commander.__drab__().access_session
      store = access_store 
        |> Enum.map(fn x -> {x, Plug.Conn.get_session(conn, x)} end) 
        |> Enum.into(%{})
      # Logger.debug("**** #{inspect store}")

      store_token = Drab.Core.tokenize_store(conn, store)

      bindings = [
        controller_and_action: controller_and_action,
        commander: commander,
        templates: templates,
        drab_session_token: store_token
      ]

      js = render_template("drab.js", bindings)

      Phoenix.HTML.raw """
      <script>
        #{js}
      </script>
      """
    else 
      ""
    end
  end

end
