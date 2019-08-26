defmodule FileBeam.WWW.Actions.HomePage do
  use Raxx.SimpleServer
  use FileBeam.WWW.Layout, arguments: [:buid]
  # alias Raxx.Session

  @impl Raxx.SimpleServer
  def handle_request(_request = %{method: :GET}, _state) do
    # TODO stop relying on the lack of collisions
    buid = FileBeam.Utils.get_random_id()

    response(:ok)
    |> render(buid, [])
  end
end
