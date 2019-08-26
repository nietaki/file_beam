defmodule FileBeam.Utils do
  @characters Enum.to_list(?a..?z) ++ Enum.to_list(?A..?Z) ++ Enum.to_list(?0..?9)

  def get_random_id() do
    1..10
    |> Enum.map(fn _ -> Enum.random(@characters) end)
    |> List.to_string()
  end
end
