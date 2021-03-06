defmodule FileBeam.WWW.Router do
  use Raxx.Router
  alias FileBeam.WWW.Actions

  section([{Raxx.Logger, Raxx.Logger.setup(level: :info)}], [
    {%{path: []}, Actions.HomePage},
    {%{method: :POST, path: ["upload", _buid]}, Actions.Upload},
    {%{method: :GET, path: ["receive", _buid]}, Actions.Receive},
    {%{method: :GET, path: ["download", _buid]}, Actions.Download},
    {%{method: :GET, path: ["stats_sse", _buid]}, Actions.StatsSSE}
  ])

  section([{Raxx.Logger, Raxx.Logger.setup(level: :debug)}], [
    {_, Actions.NotFoundPage}
  ])
end
