defmodule FileBeam.WWW.Upload do
  use Raxx.Server

  @impl Raxx.Server
  def handle_head(request, _state) do
    IO.puts "upload"
    IO.inspect request
    response(:ok)
    {[], :state}
  end

  def handle_data(chunk, state) do
    # IO.inspect chunk
    IO.puts "received chunk"
    IO.puts("chunk size: #{byte_size(chunk) / 1024} KB")
    Process.sleep(100)
    {[], :statee}
  end

  def handle_tail(_trailers, state) do
    response(:no_content)
  end
end
