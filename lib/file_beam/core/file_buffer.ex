defmodule FileBeam.Core.FileBuffer do
  @type peer_state ::
          nil
          | {:connected, pid()}
          | {:waiting, {pid(), tag :: term}}
          | {:done, pid}
          | {:dead, pid}

  defstruct [
    :uploader_state,
    :downloader_state,
    :pending_download?
  ]

  @doc """
  Blocking if the buffer fills up - do {:noreturn, _, _}
  """
  def upload_chunk(_buid, _chunk) do
  end

  @doc """
  Just as blocking
  """
  def download_chunk(_buid) do
  end

  # handle :DOWN messages from downloader/uploader
  def handle_info(_, _) do
  end
end
