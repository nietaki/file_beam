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
          queue: term()
        }

  # ===========================================================================
  # Public API
  # ===========================================================================

  @doc """
  Blocking if the buffer fills up - do {:noreturn, _, _}
  """
  def upload_chunk(server_reference, chunk) do
    GenServer.call(server_reference, {:upload_chunk, chunk})
  end

  @doc """
  Just as blocking
  """
  def download_chunk(server_reference) do
    GenServer.call(server_reference, :download_chunk)
  end

  @doc """
  Making sure there
  """
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
      uploader: :connected
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

  @impl GenServer
  def handle_call({:upload_chunk, chunk}, _from, state) when is_binary(chunk) do
    state = %{state | queue: chunk}
    {:reply, {:ok, :uploaded}, state}
  end

  # ---------------------------------------------------------------------------
  # Download chunk
  # ---------------------------------------------------------------------------

  @impl GenServer
  def handle_call(:download_chunk, _from, state = %__MODULE__{downloader: :connected}) do
    {:reply, {:ok, state.queue}, state}
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
end
