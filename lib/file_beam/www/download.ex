defmodule FileBeam.WWW.Download do
  require Logger
  use Raxx.Server
  alias FileBeam.Core.FileBuffer

  defstruct [
    :buffer_pid
  ]

  @impl Raxx.Server
  def handle_request(request = %{path: ["download", buid]}, _state) do
    IO.inspect(buid)
    IO.puts("download: #{inspect self()}")
    IO.inspect(request)

    headers = 
      response(:ok)
      |> set_header("content-disposition", "attachment")
      |> set_header("content-type", "application/octet-stream")
      |> set_body(true)


    {:ok, buffer_pid} = FileBeam.Application.lookup_buffer_server(buid)
    {:ok, _} = FileBuffer.register_downloader(buffer_pid)
    state = %__MODULE__{buffer_pid: buffer_pid}

    send self(), :more
    {[headers], state}
  end

  @impl Raxx.Server
  def handle_info(:more, state = %{buffer_pid: buffer_pid}) do
    Logger.info("more")
    {:ok, chunk} = FileBuffer.download_chunk(buffer_pid)
    send self(), :more

    {[data(chunk)], state}
  end
end
