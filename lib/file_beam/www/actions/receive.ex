defmodule FileBeam.WWW.Actions.Receive do
  use Raxx.SimpleServer
  use FileBeam.WWW.Layout, arguments: [:buid]

  @impl Raxx.SimpleServer
  def handle_request(%{path: ["receive", buid], method: :GET}, _state) do
    # TODO, see if the downloading has started and don't show the page if it has
    response(:ok)
    |> render(buid, [])
  end
end
