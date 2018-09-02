defmodule FileBeam.Core.FileBufferTest do
  use ExUnit.Case

  alias FileBeam.Core.FileBuffer

  test "you can upload a chunk to a freshly spawned FileBuffer" do
    pid = spawn_file_buffer()
    assert {:ok, :uploaded} = FileBuffer.upload_chunk(pid, "foo")
  end

  test "you can download the freshly uploaded chunk" do
    pid = spawn_file_buffer()
    assert {:ok, :connected} = FileBuffer.register_downloader(pid)
    assert {:ok, :uploaded} = FileBuffer.upload_chunk(pid, "foo")
    assert {:ok, "foo"} = FileBuffer.download_chunk(pid)
  end

  test "you can only download a chunk after you register yourself as the downloader" do
    pid = spawn_file_buffer()
    assert {:ok, :uploaded} = FileBuffer.upload_chunk(pid, "foo")
    assert {:error, :downloader_not_registered} = FileBuffer.download_chunk(pid)
    assert {:ok, :connected} = FileBuffer.register_downloader(pid)
    assert {:ok, "foo"} = FileBuffer.download_chunk(pid)
  end

  test "you can't register downloader more than once" do
    pid = spawn_file_buffer()
    assert {:ok, :connected} = FileBuffer.register_downloader(pid)
    assert {:error, _} = FileBuffer.register_downloader(pid)
  end

  test "you can download more than one chunk" do
    pid = spawn_file_buffer()
    FileBuffer.register_downloader(pid)
    assert {:ok, :uploaded} = FileBuffer.upload_chunk(pid, "foo")
    assert {:ok, :uploaded} = FileBuffer.upload_chunk(pid, "bar")
    assert {:ok, "foo"} = FileBuffer.download_chunk(pid)
    assert {:ok, "bar"} = FileBuffer.download_chunk(pid)
  end

  defp spawn_file_buffer() do
    assert {:ok, pid} = FileBuffer.start_link(uploader_pid: self())
    pid
  end
end
