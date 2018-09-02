defmodule FileBeam.Core.FileBuffer do
  use GenServer

  defstruct [
    :uploader,
    :downloader,
    :queue
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
          queue: [] | [binary]
        }

  # NOTE: the uploader will block when the buffer gets to @max_queue_size
  @max_queue_size 5

  # ===========================================================================
  # Public API
  # ===========================================================================

  def upload_chunk(server_reference, chunk) do
    GenServer.call(server_reference, {:upload_chunk, chunk}, :infinity)
  end

  def download_chunk(server_reference) do
    GenServer.call(server_reference, :download_chunk, :infinity)
  end

  def register_downloader(server_reference) do
    GenServer.call(server_reference, :register_downloader)
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
    IO.puts("FileBuffer started with opts #{inspect(opts)}")
    Process.monitor(uploader_pid)

    state = %__MODULE__{
      uploader: :connected,
      downloader: nil,
      queue: []
    }

    {:ok, state}
  end

  # ---------------------------------------------------------------------------
  # Connect downloader
  # ---------------------------------------------------------------------------

  @impl GenServer
  @spec handle_call(term, term, t()) :: {:reply, term, t()} | {:noreply, t()}
  def handle_call(:register_downloader, _from, state = %__MODULE__{downloader: nil}) do
    state = %__MODULE__{state | downloader: :connected}
    {:reply, {:ok, :connected}, state}
  end

  def handle_call(:register_downloader, _from, _ = state) do
    {:reply, {:error, :downloader_already_registered}, state}
  end

  # ---------------------------------------------------------------------------
  # Upload chunk
  # ---------------------------------------------------------------------------

  def handle_call({:upload_chunk, chunk}, from, state = %{queue: queue}) when is_binary(chunk) do
    queue = queue ++ [chunk]

    state =
      %{state | queue: queue}
      |> maybe_handle_waiting_downloader()

    case Enum.count(queue) do
      short when short < @max_queue_size ->
        {:reply, {:ok, :uploaded}, state}

      _full ->
        state = %__MODULE__{state | uploader: {:waiting, from}}
        {:noreply, state}
    end
  end

  # ---------------------------------------------------------------------------
  # Download chunk
  # ---------------------------------------------------------------------------

  @impl GenServer
  def handle_call(:download_chunk, from, state = %__MODULE__{downloader: :connected}) do
    case state.queue do
      [] ->
        state = %__MODULE__{state | downloader: {:waiting, from}}
        {:noreply, state}

      [first | rest] ->
        state =
          %__MODULE__{state | queue: rest}
          |> maybe_handle_waiting_uploader()

        {:reply, {:ok, first}, state}
    end
  end

  def handle_call(:download_chunk, _from, state = %__MODULE__{downloader: nil}) do
    {:reply, {:error, :downloader_not_registered}, state}
  end

  # handle :DOWN messages from downloader/uploader
  @impl GenServer
  def handle_info(msg, state) do
    IO.puts("FileBuffer server got info: #{inspect(msg)}")
    {:noreply, state}
  end

  # ===========================================================================
  # Pure helpers
  # ===========================================================================

  @spec maybe_handle_waiting_downloader(t()) :: t()
  defp maybe_handle_waiting_downloader(state = %__MODULE__{downloader: {:waiting, from}}) do
    case state.queue do
      [] ->
        state

      [first | rest] ->
        GenServer.reply(from, {:ok, first})
        %__MODULE__{state | downloader: :connected, queue: rest}
    end
  end

  defp maybe_handle_waiting_downloader(state) do
    state
  end

  @spec maybe_handle_waiting_uploader(t()) :: t()
  defp maybe_handle_waiting_uploader(state = %__MODULE__{uploader: {:waiting, from}}) do
    case Enum.count(state.queue) do
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
