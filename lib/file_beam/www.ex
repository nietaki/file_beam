defmodule FileBeam.WWW do
  use Ace.HTTP.Service, cleartext: true

  use Raxx.Router, [
    {%{method: :GET, path: []}, FileBeam.WWW.HomePage},
    {%{method: :POST, path: ["upload", _buid]}, FileBeam.WWW.Upload},
    {_, FileBeam.WWW.NotFoundPage}
  ]

  @external_resource "lib/file_beam/public/main.css"
  @external_resource "lib/file_beam/public/main.js"
  use Raxx.Static, "./public"
  use Raxx.Logger, level: :info
end
