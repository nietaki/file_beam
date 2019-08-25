defmodule FileBeam.Application do
  @moduledoc false
  alias FileBeam.Core.FileBuffer

  use Application

  def start(_type, _args) do
    cleartext_options = [port: port(), cleartext: true]

    secure_options = [
      port: secure_port(),
      certfile: certificate_path(),
      keyfile: certificate_key_path()
    ]

    children = [
      {FileBeam.WWW, [cleartext_options]},
      {FileBeam.WWW, [secure_options]},
      Supervisor.child_spec({Registry, [keys: :unique, name: BufferRegistry]}, []),
      {DynamicSupervisor, strategy: :one_for_one, name: BufferSupervisor}
    ]

    opts = [strategy: :one_for_one, name: FileBeam.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def buffer_server_reference(buid) when is_binary(buid) do
    {:via, Registry, {BufferRegistry, buid}}
  end

  def start_buffer_server(buid, opts \\ []) when is_binary(buid) do
    opts =
      Keyword.merge(
        opts,
        name: buffer_server_reference(buid),
        buid: buid,
        uploader_pid: self()
      )

    DynamicSupervisor.start_child(BufferSupervisor, {FileBuffer, opts})
  end

  def lookup_buffer_server(buid) do
    case Registry.lookup(BufferRegistry, buid) do
      [{pid, nil}] -> {:ok, pid}
      [] -> {:error, :not_found}
    end
  end

  defp port() do
    with raw when is_binary(raw) <- System.get_env("PORT"), {port, ""} = Integer.parse(raw) do
      port
    else
      _ -> 8080
    end
  end

  defp secure_port() do
    with raw when is_binary(raw) <- System.get_env("SECURE_PORT"),
         {secure_port, ""} = Integer.parse(raw) do
      secure_port
    else
      _ -> 8443
    end
  end

  defp certificate_path() do
    case System.get_env("SSL_CERTIFICATE") do
      none when none in [nil, ""] ->
        Application.app_dir(:file_beam, "priv/localhost/certificate.pem")

      some ->
        Application.app_dir(:file_beam, Path.join("priv/", some))
    end
  end

  defp certificate_key_path() do
    case System.get_env("SSL_KEY") do
      none when none in [nil, ""] ->
        Application.app_dir(:file_beam, "priv/localhost/certificate_key.pem")

      some ->
        Application.app_dir(:file_beam, Path.join("priv/", some))
    end
  end
end
