defmodule FileBeam.WWW.Download2 do
  use Raxx.Server

  defstruct [
    :buffer_pid
  ]

  @impl Raxx.Server
  def handle_head(request = %{path: ["download", buid]}, _state) do
    IO.inspect(buid)
    IO.puts("download")
    IO.inspect(request)

    outbound = 
      response(:ok)
      |> set_header("content-disposition", "attachment")
      |> set_body(true)

    state = %__MODULE__{buffer_pid: nil}

    {[outbound], state}
  end

  @impl Raxx.Server
  def handle_data(chunk, state) do
    IO.puts "download data: #{chunk}"
    {[data("foo")], state}
  end

  @impl Raxx.Server
  def handle_tail(trailers, state) do
    # TODO
    IO.puts "tail: #{inspect(trailers)}"
    {[tail()], state}
  end
end
