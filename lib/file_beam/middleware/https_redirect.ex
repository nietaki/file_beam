defmodule FileBeam.Middleware.HttpsRedirect do
  alias Raxx.Server
  alias Raxx.Middleware
  alias Raxx.Request

  @behaviour Middleware

  @moduledoc """
  Redirects all http requests to https, except for when on localhost
  """

  @impl Middleware
  def process_head(%Request{scheme: :https} = request, _config, inner_server) do
    # all good, do nothing
    {parts, inner_server} = Server.handle_head(inner_server, request)
    {parts, :state, inner_server}
  end

  def process_head(%Request{authority: "localhost" <> _} = request, _config, inner_server) do
    # you can do anything on localhost
    {parts, inner_server} = Server.handle_head(inner_server, request)
    {parts, :state, inner_server}
  end

  def process_head(%Request{authority: "127.0.0.1" <> _} = request, _config, inner_server) do
    # you can do anything on localhost
    {parts, inner_server} = Server.handle_head(inner_server, request)
    {parts, :state, inner_server}
  end

  def process_head(%Request{scheme: :http} = request, _config, inner_server) do
    redirect_uri = %URI{
      authority: request.authority,
      host: Raxx.request_host(request),
      path: request.raw_path,
      # TODO make it configureable
      port: 443,
      query: request.query,
      scheme: "https",
      # TODO
      userinfo: nil
    }

    redirect = Raxx.redirect(URI.to_string(redirect_uri), status: 302)
    {[redirect], :state, inner_server}
  end

  @impl Middleware
  def process_data(data, state, inner_server) do
    {parts, inner_server} = Server.handle_data(inner_server, data)
    {parts, state, inner_server}
  end

  @impl Middleware
  def process_tail(tail, state, inner_server) do
    {parts, inner_server} = Server.handle_tail(inner_server, tail)
    {parts, state, inner_server}
  end

  @impl Middleware
  def process_info(info, state, inner_server) do
    {parts, inner_server} = Server.handle_info(inner_server, info)
    {parts, state, inner_server}
  end
end
