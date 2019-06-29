defmodule FileBeam.WWW.Actions.Upload do
  use Raxx.Server
  alias FileBeam.Core.FileBuffer

  defstruct [
    :buffer_pid
  ]

  @impl Raxx.Server
  def handle_head(request = %{path: ["upload", buid]}, _state) do
    IO.inspect(buid)
    IO.puts("upload: #{inspect(self())}")
    IO.inspect(request)

    metadata = %{
      content_length: get_content_length(request),
      original_filename: get_original_filename(request),
      original_content_type: get_header(request, "content-type")
    }

    {:ok, buffer_pid} = FileBeam.Application.start_buffer_server(buid, metadata: metadata)
    {[], %__MODULE__{buffer_pid: buffer_pid}}
  end

  @impl Raxx.Server
  def handle_data(chunk, state = %{buffer_pid: buffer_pid}) do
    FileBuffer.upload_chunk(buffer_pid, chunk)
    {[], state}
  end

  @impl Raxx.Server
  def handle_tail(_trailers, _state = %{buffer_pid: buffer_pid}) do
    IO.puts("finishing upload!")
    FileBuffer.signal_upload_done(buffer_pid)
    response(:no_content)
  end

  # defp get_content_length(request) do
  #   length_string = get_header(request, "content-length", "-1")
  #   String.to_integer(length_string)
  # end

  defp get_original_filename(request) do
    get_header(request, "x-original-filename")
  end
end
