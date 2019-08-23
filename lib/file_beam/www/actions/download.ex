defmodule FileBeam.WWW.Actions.Download do
  require Logger
  use Raxx.Server
  alias FileBeam.Core.FileBuffer

  defstruct [
    :buffer_pid
  ]

  def handle_head(request = %{path: ["download", buid]}, _state) do
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
      |> maybe_set_header("content-type", metadata.original_content_type)
      |> set_header("content-length", Integer.to_string(metadata.content_length))
      |> set_body(true)

    state = %__MODULE__{buffer_pid: buffer_pid}
    send(self(), :more)
    {[headers], state}
  end

  def handle_data(_body, state) do
    {[], state}
  end

  def handle_tail(_trailers, state) do
    {[], state}
  end

  def handle_info(:more, state = %{buffer_pid: buffer_pid}) do
    {:ok, chunks} = FileBuffer.download_chunks(buffer_pid)

    case chunks do
      :complete ->
        IO.puts("finishing download!")
        {[tail()], state}

      reversed_chunks when is_list(reversed_chunks) ->
        send(self(), :more)
        datas = Enum.reduce(reversed_chunks, [], fn chunk, acc -> [data(chunk) | acc] end)
        {datas, state}
    end
  end

  defp maybe_set_header(response, _header_name, nil) do
    response
  end

  defp maybe_set_header(response, header_name, value) do
    set_header(response, header_name, value)
  end
end
