defmodule FileBeam.WWW.Actions.HomePage do
  use Raxx.SimpleServer
  use FileBeam.WWW.Layout, arguments: [:buid]
  # alias Raxx.Session

  @impl Raxx.SimpleServer
  def handle_request(_request = %{method: :GET}, _state) do
    buid = UUID.uuid4()

    response(:ok)
    |> render(buid, [])
  end
end
