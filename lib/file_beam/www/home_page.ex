defmodule FileBeam.WWW.HomePage do
  use Raxx.Server
  use FileBeam.WWW.HTMLView

  @impl Raxx.Server
  def handle_request(_request, _state) do
    response(:ok)
    |> render(%{buid: UUID.uuid4()})
  end
end
