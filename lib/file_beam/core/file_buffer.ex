defmodule FileBeam.Core.FileBuffer do
  use GenServer

  @type peer_state ::
          nil
          | {:connected, pid()}
          | {:waiting, from :: {pid(), tag :: term}}
          | {:done, pid}
          | {:dead, pid}

  defstruct [
    :uploader_state,
    :downloader_state,
    :queue
  ]

  # Public Inteface

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

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, opts)
  end

  # Implementation

  @impl GenServer
  def init(opts) do
    uploader_pid = Keyword.fetch!(opts, :uploader_pid)
    IO.puts("FileBuffer started with opts #{inspect(opts)}")
    Process.monitor(uploader_pid)

    state = %__MODULE__{
      uploader_state: {:connected, uploader_pid}
    }

    {:ok, state}
  end

  @impl GenServer
  def handle_call({:upload_chunk, chunk}, _from, state) when is_binary(chunk) do
    state = %{state | queue: chunk}
    {:reply, {:ok, :uploaded}, state}
  end

  @impl GenServer
  def handle_call(:download_chunk, _from, state) do
    {:reply, {:ok, state.queue}, state}
  end

  # handle :DOWN messages from downloader/uploader
  @impl GenServer
  def handle_info(msg, state) do
    IO.puts("FileBuffer server got info: #{inspect(msg)}")
    {:noreply, state}
  end
end
