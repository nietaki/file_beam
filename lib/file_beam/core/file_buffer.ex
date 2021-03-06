defmodule FileBeam.Core.FileBuffer do
  require Logger
  use GenServer

  defmodule Stats do
    defstruct [
      :bytes_transferred,
      :upload_started_at,
      :download_started_at
    ]

    def new() do
      %__MODULE__{
        bytes_transferred: 0,
        upload_started_at: DateTime.utc_now(),
        download_started_at: nil
      }
    end

    @type t :: %__MODULE__{
            bytes_transferred: integer,
            upload_started_at: DateTime.t(),
            download_started_at: DateTime.t() | nil
          }

    def download_started(%__MODULE__{} = stats) do
      %__MODULE__{stats | download_started_at: DateTime.utc_now()}
    end

    def bytes_transferred(%__MODULE__{} = stats, newly_transferred_count) do
      %__MODULE__{stats | bytes_transferred: stats.bytes_transferred + newly_transferred_count}
    end
  end

  defstruct [
    :uploader,
    :downloader,
    :queue,
    :metadata,
    :stats
  ]

  @type peer_state ::
          nil
          | :connected
          | {:waiting, from :: {pid(), tag :: term}}
          | :done
          | :dead

  @type t :: %__MODULE__{
          uploader: peer_state(),
          downloader: peer_state(),
          queue: [] | [binary],
          metadata: map(),
          stats: Stats.t()
        }

  # NOTE: the uploader will block when the buffer gets to @max_queue_size
  @max_queue_size 10

  # ===========================================================================
  # Public API
  # ===========================================================================

  def upload_chunk(server_reference, chunk) do
    GenServer.call(server_reference, {:upload_chunk, chunk}, :infinity)
  end

  def signal_upload_done(server_reference) do
    GenServer.call(server_reference, :upload_done)
  end

  @doc """
  returns the chunks reversed!
  """
  def download_chunks(server_reference) do
    GenServer.call(server_reference, :download_chunks, :infinity)
  end

  def register_downloader(server_reference) do
    GenServer.call(server_reference, :register_downloader)
  end

  def get_stats(server_reference) do
    GenServer.call(server_reference, :get_stats)
  end

  def get_metadata(server_reference) do
    GenServer.call(server_reference, :get_metadata)
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, opts)
  end

  # ===========================================================================
  # Implementation
  # ===========================================================================

  @impl GenServer
  @spec init(Keyword.t()) :: {:ok, t()}
  def init(opts) do
    uploader_pid = Keyword.fetch!(opts, :uploader_pid)
    metadata = %{} = Keyword.get(opts, :metadata, %{})
    Logger.info("FileBuffer started with opts #{inspect(opts)}")

    Process.monitor(uploader_pid)

    state = %__MODULE__{
      uploader: :connected,
      downloader: nil,
      queue: [],
      metadata: metadata,
      stats: Stats.new()
    }

    {:ok, state}
  end

  # ---------------------------------------------------------------------------
  # Connect downloader
  # ---------------------------------------------------------------------------

  @impl GenServer
  @spec handle_call(term, term, t()) :: {:reply, term, t()} | {:noreply, t()}
  def handle_call(:register_downloader, _from, state = %__MODULE__{downloader: nil, stats: stats}) do
    stats = Stats.download_started(stats)
    state = %__MODULE__{state | downloader: :connected, stats: stats}
    {:reply, {:ok, state.metadata}, state}
  end

  def handle_call(:register_downloader, _from, _ = state) do
    {:reply, {:error, :downloader_already_registered}, state}
  end

  # ---------------------------------------------------------------------------
  # Upload chunk
  # ---------------------------------------------------------------------------

  def handle_call({:upload_chunk, chunk}, from, state = %{queue: queue}) when is_binary(chunk) do
    queue = [chunk | queue]

    # IO.puts("queue size: #{Enum.count(queue)}, chunk size: #{byte_size(chunk)}")

    state =
      %{state | queue: queue}
      |> maybe_handle_waiting_downloader()

    case length(queue) do
      short when short < @max_queue_size ->
        {:reply, {:ok, :uploaded}, state}

      _full ->
        state = %__MODULE__{state | uploader: {:waiting, from}}
        {:noreply, state}
    end
  end

  # ---------------------------------------------------------------------------
  # Upload done
  # ---------------------------------------------------------------------------

  def handle_call(:upload_done, _from, state = %__MODULE__{uploader: :connected}) do
    Logger.info("Upload done!")

    state =
      %{state | uploader: :done}
      |> maybe_handle_waiting_downloader()

    {:reply, {:ok, :acknowledged}, state}
  end

  # ---------------------------------------------------------------------------
  # Download chunks
  # ---------------------------------------------------------------------------

  def handle_call(
        :download_chunks,
        _from,
        state = %__MODULE__{downloader: :connected, uploader: :done, queue: []}
      ) do
    state = %{state | downloader: :done}
    {:reply, {:ok, :complete}, state}
  end

  def handle_call(:download_chunks, from, state = %__MODULE__{downloader: :connected}) do
    case state.queue do
      [] ->
        # Logger.info("blocking on download")
        state = %__MODULE__{state | downloader: {:waiting, from}}
        {:noreply, state}

      [_ | _] = all_chunks ->
        # first_byte_size = byte_size(first)

        new_byte_count = Enum.reduce(all_chunks, 0, fn chunk, acc -> byte_size(chunk) + acc end)
        stats = Stats.bytes_transferred(state.stats, new_byte_count)

        state =
          %__MODULE__{state | queue: [], stats: stats}
          |> maybe_handle_waiting_uploader()

        {:reply, {:ok, all_chunks}, state}
    end
  end

  def handle_call(:download_chunks, _from, state = %__MODULE__{downloader: nil}) do
    {:reply, {:error, :downloader_not_registered}, state}
  end

  # ---------------------------------------------------------------------------
  # Stats
  # ---------------------------------------------------------------------------

  def handle_call(:get_stats, _from, state) do
    {:reply, {:ok, state.stats}, state}
  end

  def handle_call(:get_metadata, _from, state) do
    {:reply, {:ok, state.metadata}, state}
  end

  # ===========================================================================
  # handlle_info
  # ===========================================================================

  # TODO: handle :DOWN messages from downloader/uploader
  @impl GenServer
  def handle_info(msg, state) do
    Logger.info("FileBuffer server got info: #{inspect(msg)}")

    {:noreply, state}
  end

  # ===========================================================================
  # Pure helpers
  # ===========================================================================

  @spec maybe_handle_waiting_downloader(t()) :: t()
  defp maybe_handle_waiting_downloader(
         state = %__MODULE__{downloader: {:waiting, from}, uploader: :done, queue: []}
       ) do
    Logger.info("telling waiting downloader the whole thing is finished")

    GenServer.reply(from, {:ok, :complete})
    %{state | downloader: :done}
  end

  defp maybe_handle_waiting_downloader(state = %__MODULE__{downloader: {:waiting, from}}) do
    case state.queue do
      [] ->
        state

      [_ | _] = all_chunks ->
        new_byte_count = Enum.reduce(all_chunks, 0, fn chunk, acc -> byte_size(chunk) + acc end)
        stats = Stats.bytes_transferred(state.stats, new_byte_count)
        GenServer.reply(from, {:ok, all_chunks})
        %__MODULE__{state | downloader: :connected, queue: [], stats: stats}
    end
  end

  defp maybe_handle_waiting_downloader(state) do
    state
  end

  @spec maybe_handle_waiting_uploader(t()) :: t()
  defp maybe_handle_waiting_uploader(state = %__MODULE__{uploader: {:waiting, from}}) do
    case length(state.queue) do
      @max_queue_size ->
        state

      decreased when decreased < @max_queue_size ->
        GenServer.reply(from, {:ok, :uploaded})
        %__MODULE__{state | uploader: :connected}
    end
  end

  defp maybe_handle_waiting_uploader(state) do
    state
  end
end
