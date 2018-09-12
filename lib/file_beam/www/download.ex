defmodule FileBeam.WWW.Download do
  require Logger
  use Raxx.Server
  alias FileBeam.Core.FileBuffer

  defstruct [
    :buffer_pid
  ]

  def handle_request(request = %{path: ["download", buid]}, _state) do
    IO.inspect(buid)
    IO.puts("download: #{inspect(self())}")
    IO.inspect(request)

    {:ok, buffer_pid} = FileBeam.Application.lookup_buffer_server(buid)
    {:ok, metadata} = FileBuffer.register_downloader(buffer_pid)
    IO.inspect(metadata)

    headers =
      response(:ok)
      |> set_header(
        "content-disposition",
        "attachment; filename=\"#{metadata.original_filename}\""
      )
      |> set_header("content-type", metadata.original_content_type)
      |> set_body(true)

    state = %__MODULE__{buffer_pid: buffer_pid}
    send(self(), :more)
    {[headers], state}
  end

  def handle_info(:more, state = %{buffer_pid: buffer_pid}) do
    {:ok, chunk} = FileBuffer.download_chunk(buffer_pid)

    case chunk do
      :complete ->
        IO.puts("finishing download!")
        {[tail()], state}

      chunk when is_binary(chunk) ->
        send(self(), :more)
        {[data(chunk)], state}
    end
  end
end
