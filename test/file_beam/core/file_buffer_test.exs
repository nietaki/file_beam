defmodule FileBeam.Core.FileBufferTest do
  use ExUnit.Case

  alias FileBeam.Core.FileBuffer

  test "you can upload a chunk to a freshly spawned FileBuffer" do
    pid = spawn_file_buffer()
    assert {:ok, :uploaded} = FileBuffer.upload_chunk(pid, "foo")
  end

  test "you can download the freshly uploaded chunk" do
    pid = spawn_file_buffer()
    assert {:ok, %{}} = FileBuffer.register_downloader(pid)
    assert {:ok, :uploaded} = FileBuffer.upload_chunk(pid, "foo")
    assert {:ok, ["foo"]} = FileBuffer.download_chunks(pid)
  end

  test "you can get stats" do
    pid = spawn_file_buffer()
    assert {:ok, %FileBuffer.Stats{}} = FileBuffer.get_stats(pid)
  end

  test "you can get metadata" do
    pid = spawn_file_buffer()
    assert {:ok, %{}} = FileBuffer.get_metadata(pid)
  end

  test "metadata gets forwarded to the downloader on registration" do
    metadata = %{foo: :bar}
    assert {:ok, pid} = FileBuffer.start_link(uploader_pid: self(), metadata: metadata)
    assert {:ok, metadata} == FileBuffer.register_downloader(pid)
  end

  test "you can only download a chunk after you register yourself as the downloader" do
    pid = spawn_file_buffer()
    assert {:ok, :uploaded} = FileBuffer.upload_chunk(pid, "foo")
    assert {:error, :downloader_not_registered} = FileBuffer.download_chunks(pid)
    assert {:ok, %{}} = FileBuffer.register_downloader(pid)
    assert {:ok, ["foo"]} = FileBuffer.download_chunks(pid)
  end

  test "you can't register downloader more than once" do
    pid = spawn_file_buffer()
    assert {:ok, %{}} = FileBuffer.register_downloader(pid)
    assert {:error, _} = FileBuffer.register_downloader(pid)
  end

  test "you can download more than one chunk, the chunks come out reversed" do
    pid = spawn_file_buffer()
    FileBuffer.register_downloader(pid)
    assert {:ok, :uploaded} = FileBuffer.upload_chunk(pid, "foo")
    assert {:ok, :uploaded} = FileBuffer.upload_chunk(pid, "bar")
    assert {:ok, ["bar", "foo"]} = FileBuffer.download_chunks(pid)
  end

  test "buffer blocks when downloader requests more chunks and there is none in the buffer" do
    pid = spawn_file_buffer()
    FileBuffer.register_downloader(pid)
    assert {:ok, :uploaded} = FileBuffer.upload_chunk(pid, "foo")
    assert {:ok, ["foo"]} = FileBuffer.download_chunks(pid)

    download_task = Task.async(fn -> FileBuffer.download_chunks(pid) end)
    refute done?(download_task)
    # make sure it's not a race condition
    Process.sleep(10)
    refute done?(download_task)

    assert {:ok, :uploaded} = FileBuffer.upload_chunk(pid, "bar")
    assert {:ok, ["bar"]} = result!(download_task)
    assert done?(download_task)
    assert {:ok, :uploaded} = FileBuffer.upload_chunk(pid, "baz")
    assert {:ok, ["baz"]} = FileBuffer.download_chunks(pid)
  end

  # changing the size of the buffer breaks this test
  @tag :skip
  test "buffer blocks when it gets full" do
    pid = spawn_file_buffer()
    assert {:ok, :uploaded} = FileBuffer.upload_chunk(pid, "foo")
    assert {:ok, :uploaded} = FileBuffer.upload_chunk(pid, "bar")
    assert {:ok, :uploaded} = FileBuffer.upload_chunk(pid, "baz")
    assert {:ok, :uploaded} = FileBuffer.upload_chunk(pid, "ban")

    upload_task =
      Task.async(fn ->
        FileBuffer.upload_chunk(pid, "bak")
      end)

    Process.sleep(10)
    refute done?(upload_task)

    FileBuffer.register_downloader(pid)
    assert {:ok, ["ban", "baz", "bar", "foo"]} = FileBuffer.download_chunks(pid)
    assert {:ok, :uploaded} = result!(upload_task)
  end

  test "uploader finishing while downloader isn't waiting" do
    pid = spawn_file_buffer()
    assert {:ok, :uploaded} = FileBuffer.upload_chunk(pid, "foo")
    assert {:ok, _} = FileBuffer.signal_upload_done(pid)
    FileBuffer.register_downloader(pid)
    assert {:ok, ["foo"]} = FileBuffer.download_chunks(pid)
    assert {:ok, :complete} = FileBuffer.download_chunks(pid)
  end

  # if this test fails it's probably I introduced a delay in
  # FileBuffer.download_chunks/1 for some experiments
  test "uploader finishing while downloader is waiting" do
    pid = spawn_file_buffer()
    {:ok, _} = FileBuffer.register_downloader(pid)

    download_task_1 =
      Task.async(fn ->
        FileBuffer.download_chunks(pid)
      end)

    assert {:ok, :uploaded} = FileBuffer.upload_chunk(pid, "foo")

    Process.sleep(10)
    assert done?(download_task_1)
    assert {:ok, ["foo"]} = result!(download_task_1)

    download_task_2 =
      Task.async(fn ->
        FileBuffer.download_chunks(pid)
      end)

    Process.sleep(10)

    refute done?(download_task_2)
    assert {:ok, _} = FileBuffer.signal_upload_done(pid)

    assert {:ok, :complete} = result!(download_task_2)
  end

  # ===========================================================================
  # Helper functions
  # ===========================================================================

  defp spawn_file_buffer() do
    assert {:ok, pid} = FileBuffer.start_link(uploader_pid: self())
    pid
  end

  defp done?(task) do
    !Process.alive?(task.pid)
  end

  defp result!(task) do
    Task.await(task, 100)
  end
end
