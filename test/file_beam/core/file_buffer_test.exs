defmodule FileBeam.Core.FileBufferTest do
  use ExUnit.Case

  alias FileBeam.Core.FileBuffer

  test "you can upload a chunk to a freshly spawned FileBuffer" do
    pid = spawn_file_buffer()
    assert {:ok, :uploaded} = FileBuffer.upload_chunk(pid, "foo")
  end

  test "you can download the freshly uploaded chunk" do
    pid = spawn_file_buffer()
    assert {:ok, :uploaded} = FileBuffer.upload_chunk(pid, "foo")
    assert {:ok, "foo"} = FileBuffer.download_chunk(pid)
  end

  defp spawn_file_buffer() do
    assert {:ok, pid} = FileBuffer.start_link(uploader_pid: self())
    pid
  end
end