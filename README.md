# FileBeam

- Install dependencies with `mix deps.get`
- Start your service with `iex -S mix`
- Run project test suite with `mix test`

## Action Plan

- homepage javascript generates a uuid for upload path `/upload/<uuid>`
- js makes the file request to `/upload/<uuid>`
- Upload action handler:
  - spawns a buffer gen_server
  - feeds it with chunks whenever it can
- Download action handler:
  - looks up the file buffer gen_server
  - repeatedly asks for more

If the uploader/downloader dies, the FileBuffer already monitors them, sends a failure message and waits for them to die.
