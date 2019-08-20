defmodule FileBeam.WWW.Actions.StatsSSE do
  require Logger
  use Raxx.Server
  # alias FileBeam.Core.FileBuffer

  def handle_head(request = %{path: ["stats_sse", buid]}, _state) do
    IO.inspect(buid)
    IO.puts("stats for #{buid}: #{inspect(self())}")
    IO.inspect(request)

    # {:ok, buffer_pid} = FileBeam.Application.lookup_buffer_server(buid)
    # {:ok, metadata} = FileBuffer.register_downloader(buffer_pid)
    # IO.inspect(metadata)

    headers =
      response(:ok)
      |> set_header("content-type", ServerSentEvent.mime_type())
      |> set_body(true)

    state = :state
    Process.send_after(self(), :more, 5000)
    {[headers], state}
  end

  def handle_data(_body, state) do
    {[], state}
  end

  def handle_tail(_trailers, state) do
    {[], state}
  end

  def handle_info(:more, state) do
    data = %{foo: "bar"}
    json = Jason.encode!(data)
    sse_struct = ServerSentEvent.new(json)
    chunk = ServerSentEvent.serialize(sse_struct)

    Process.send_after(self(), :more, 5000)
    {[data(chunk)], state}
  end
end
