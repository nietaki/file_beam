defmodule FileBeam.WWW.Upload do
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

    {:ok, buffer_pid} = FileBeam.Application.start_buffer_server(buid)
    {[], %__MODULE__{buffer_pid: buffer_pid}}
  end

  @impl Raxx.Server
  def handle_data(chunk, state = %{buffer_pid: buffer_pid}) do
    IO.puts("received chunk, chunk size: #{byte_size(chunk) / 1024} KB")
    FileBuffer.upload_chunk(buffer_pid, chunk)
    IO.puts("uploaded chunk")
    {[], state}
  end

  @impl Raxx.Server
  def handle_tail(_trailers, state = %{buffer_pid: buffer_pid}) do
    IO.puts("finishing upload!")
    FileBuffer.signal_upload_done(buffer_pid)
    response(:no_content)
  end
end
