defmodule FileBeam.WWW.Upload do
  use Raxx.Server

  @impl Raxx.Server
  def handle_head(request = %{path: ["upload", buid]}, _state) do
    IO.inspect(buid)
    IO.puts("upload")
    IO.inspect(request)

    IO.inspect FileBeam.Application.start_buffer_server(buid)
    {[], :state}
  end

  @impl Raxx.Server
  def handle_data(chunk, _state) do
    # IO.inspect chunk
    IO.puts("received chunk")
    IO.puts("chunk size: #{byte_size(chunk) / 1024} KB")
    Process.sleep(100)
    {[], :statee}
  end

  @impl Raxx.Server
  def handle_tail(_trailers, _state) do
    response(:no_content)
  end
end
