defmodule FileBeam.WWW.Actions.Receive do
  use Raxx.SimpleServer
  use FileBeam.WWW.Layout, arguments: [:buid]

  @impl Raxx.SimpleServer
  def handle_request(%{path: ["receive", buid], method: :GET}, _state) do
    case FileBeam.Application.lookup_buffer_server(buid) do
      {:ok, _pid} ->
        response(:ok)
        |> render(buid, [])

      {:error, :not_found} ->
        response(:not_found)
        |> FileBeam.WWW.Actions.NotFoundPage.render()
    end
  end
end
