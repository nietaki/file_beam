# FileBeam

- Install dependencies with `mix deps.get`
- Start your service with `iex -S mix`
- Run project test suite with `mix test`
- You can access the file_beam server at http://localhost:8080/
- You can see the wobserver at http://localhost:4001/

# TODO

- [x] shorter ids (randomly generate a 10 character one like `DFI0dfdF3r`
  - [ ] make sure it's not used)
- [ ] kill the FileBuffer process after a while after the transfer has been completed
- [x] SSE endpoint with stats, using periodic polling with `GenServer.call`
- [x] Put it up on ~gigalixir~ DigitalOcean
- [ ] UI on the uploader side
  - [ ] copy the receive url
  - [x] hide the upload button after a file has been picked
  - [x] wire up the stats
  - [ ] don't show the download stuff until the FileBuffer is up
- [x] UI on the downloader side
  - [x] wire up the stats
- [ ] make sure we handle failure cases well (uploader / downloader dies)

## Docker commands

- Start the service with `docker-compose up`
- Run project test suite with `docker-compose run file_beam mix test`
- Start IEx session in running service
      # Find a container id using docker ps
      docker exec -it <container-id> bash

      # In container
      iex --sname debug --remsh app@$(hostname)
