defmodule FileBeam.Application do
  @moduledoc false
  alias FileBeam.Core.FileBuffer

  use Application

  def start(_type, _args) do
    config = %{}
    cleartext_options = [port: port(), cleartext: true]

    secure_options = [
      port: secure_port(),
      cleartext: false,
      certfile: certificate_path(),
      keyfile: certificate_key_path()
    ]

    children = [
      Supervisor.child_spec({FileBeam.WWW, [config, cleartext_options]}, id: :www_cleartext),
      Supervisor.child_spec({FileBeam.WWW, [config, secure_options]}, id: :www_secure),
      Supervisor.child_spec({Registry, [keys: :unique, name: BufferRegistry]}, []),
      {DynamicSupervisor, strategy: :one_for_one, name: BufferSupervisor}
    ]

    opts = [strategy: :one_for_one, name: FileBeam.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def buffer_server_reference(buid) when is_binary(buid) do
    {:via, Registry, {BufferRegistry, buid}}
  end

  def start_buffer_server(buid) when is_binary(buid) do
    opts = [name: buffer_server_reference(buid), buid: buid]
    DynamicSupervisor.start_child(BufferSupervisor, {FileBuffer, opts})
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
    Application.app_dir(:file_beam, "priv/localhost/certificate.pem")
  end

  defp certificate_key_path() do
    Application.app_dir(:file_beam, "priv/localhost/certificate_key.pem")
  end
end