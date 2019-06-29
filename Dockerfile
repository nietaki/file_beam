FROM elixir:1.8.2

# NOTE the WORKDIR should not be the users home dir as the will copy container cookie into host machine
WORKDIR /opt/app

# Add tools needed for development
# inotify-tools: gives filesystem events that are used to trigger recompilation

# RUN apt-get update && apt-get install -y inotify-tools
RUN apt-get update

# Build hex and rebar as a separate Docker layer
RUN mix local.hex --force && mix local.rebar --force

# Build all dependencies separately to the application code
RUN mkdir config
COPY config/* config/
COPY mix.* ./
RUN mix do deps.get, deps.compile

# Add application code as final layer
COPY . .

CMD ["sh", "./bin/start.sh"]

