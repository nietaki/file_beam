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

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, opts)
  end

  @impl GenServer 
  def init(opts) do
    IO.puts "FileBuffer started with opts #{inspect opts}"
    {:ok, %__MODULE__{}}
  end

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

  @impl GenServer
  def handle_call({:upload_chunk, chunk}, _from, state) do
    state = %{state | queue: chunk}
    {:reply, :ok, state}
  end

  @impl GenServer
  def handle_call(:download_chunk, _from, state) do
    {:reply, state.queue, state}
  end 

  # handle :DOWN messages from downloader/uploader
  @impl GenServer 
  def handle_info(msg, state) do
    IO.puts "FileBuffer server got info: #{inspect msg}"
    {:ok, state}
  end
end
