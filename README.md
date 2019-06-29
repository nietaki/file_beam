# FileBeam

- Install dependencies with `mix deps.get`
- Start your service with `iex -S mix`
- Run project test suite with `mix test`
- You can see the wobserver at http://localhost:4001/

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

## Docker commands

- Start the service with `docker-compose up`
- Run project test suite with `docker-compose run file_beam mix test`
- Start IEx session in running service
      # Find a container id using docker ps
      docker exec -it <container-id> bash

      # In container
      iex --sname debug --remsh app@$(hostname)
