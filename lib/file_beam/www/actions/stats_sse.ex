defmodule FileBeam.WWW.Actions.StatsSSE do
  require Logger
  use Raxx.Server
  alias FileBeam.Core.FileBuffer

  defstruct [
    :buid,
    :metadata,
    :stats
  ]

  @interval 2000

  def handle_head(request = %{path: ["stats_sse", buid]}, _config) do
    # otherwise the individual messages don't get to the client
    FileBeam.Middleware.ResponseCompression.set_flush_every_chunk(true)
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

    state = %__MODULE__{
      buid: buid
    }

    Process.send_after(self(), :more, @interval)
    {[headers], state}
  end

  def handle_data(_body, state) do
    {[], state}
  end

  def handle_tail(_trailers, state) do
    {[], state}
  end

  def handle_info(:more, %{buid: buid} = state) do
    # yes, Process.send_after makes the calculations imprecise.
    # but I really don't want to care about it right now

    case FileBeam.Application.lookup_buffer_server(buid) do
      {:ok, pid} ->
        if state.metadata == nil do
          # initial hydration
          {:ok, metadata} = FileBuffer.get_metadata(pid)
          {:ok, stats} = FileBuffer.get_stats(pid)
          Process.send_after(self(), :more, @interval)
          state = %__MODULE__{state | metadata: metadata, stats: stats}
          {[], state}
        else
          {:ok, stats} = FileBuffer.get_stats(pid)
          data = get_sse_data(state, stats)

          if data.file_size != data.bytes_transferred do
            # let's not refresh after it's done
            Process.send_after(self(), :more, @interval)
          end

          json = Jason.encode!(data)
          sse_struct = ServerSentEvent.new(json)
          chunk = ServerSentEvent.serialize(sse_struct)

          {[data(chunk)], %__MODULE__{state | stats: stats}}
        end

      {:error, :not_found} ->
        Process.send_after(self(), :more, @interval)
        {[], state}
    end
  end

  def get_sse_data(state, new_stats) do
    IO.inspect(state)
    IO.inspect(new_stats)
    content_length = Map.get(state.metadata, :content_length)
    bytes_transferred = new_stats.bytes_transferred

    progress =
      if content_length,
        do: bytes_transferred / content_length,
        else: nil

    current_speed =
      (bytes_transferred - state.stats.bytes_transferred) /
        (@interval / 1000)

    %{
      filename: Map.get(state.metadata, :original_filename),
      file_size: content_length,
      bytes_transferred: bytes_transferred,
      progress: progress,
      current_speed: current_speed
    }
  end
end
