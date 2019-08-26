defmodule FileBeam.Middleware.ResponseCompression do
  alias Raxx.Server
  alias Raxx.Middleware
  alias Raxx.Request
  alias Raxx.Response
  alias Raxx.Data
  alias Raxx.Tail
  alias __MODULE__, as: CompressionMiddleware

  @behaviour Middleware

  @moduledoc """
  Redirects all http requests to https, except for when on localhost
  """

  # TODO check if the upstream server set a content-encoding already

  @flush_every_chunk :flush_every_chunk

  defmodule State do
    defstruct [
      :compression_type,
      :zstream
    ]

    @type t :: %State{}

    @spec compress(State.t(), map) :: {State.t(), [map]}
    def compress(%__MODULE__{compression_type: nil} = state, message) do
      # nothing to do if we're not applying the compression
      {state, [message]}
    end

    def compress(%__MODULE__{} = state, %Response{body: false} = response) do
      # no body to compress
      {state, [response]}
    end

    def compress(%__MODULE__{} = state, %Response{body: whole_body} = response)
        when is_list(whole_body) do
      response = %Response{response | body: IO.iodata_to_binary(whole_body)}
      compress(state, response)
    end

    def compress(
          %__MODULE__{compression_type: type} = state,
          %Response{body: whole_body} = response
        )
        when is_binary(whole_body) do
      # TODO use the zstream instead of :zlib.gzip
      response =
        response
        |> Raxx.set_header("content-encoding", type)
        |> Raxx.delete_header("content-length")

      response = %Response{response | body: :zlib.gzip(whole_body)}

      {state, [response]}
    end

    def compress(%__MODULE__{compression_type: type} = state, %Response{body: true} = response) do
      # we'll compress the chunks later
      response =
        response
        |> Raxx.set_header("content-encoding", type)
        # in case the upstream server set it, we don't know how long the response is gonna be
        |> Raxx.delete_header("content-length")

      {state, [response]}
    end

    def compress(state, %Data{data: binary_data}) do
      # NOTE TODO FIXME flush= sync seems to be needed for SSE to work correctly
      # make it a config thing
      #
      zflush = if CompressionMiddleware.flush_every_chunk?(), do: :sync, else: :none

      compressed =
        :zlib.deflate(state.zstream, binary_data, zflush)
        |> IO.iodata_to_binary()

      case compressed do
        "" ->
          {state, []}

        longer when is_binary(longer) ->
          {state, [%Data{data: compressed}]}
      end
    end

    def compress(state, %Tail{} = tail) do
      last_compressed =
        :zlib.deflate(state.zstream, "", :finish)
        |> IO.iodata_to_binary()

      :zlib.deflateEnd(state.zstream)
      {state, [%Data{data: last_compressed}, tail]}
    end

    def compress_parts(state, parts) do
      do_compress_parts(state, parts, [])
    end

    defp do_compress_parts(state, [], acc) do
      {state, Enum.reverse(acc)}
    end

    defp do_compress_parts(state, [first | rest], acc) do
      {state, first_compressed} = compress(state, first)
      do_compress_parts(state, rest, Enum.reverse(first_compressed) ++ acc)
    end
  end

  # Public API

  @doc """
  Sets a value in the Context saying if every data chunk should be flushed

  If set to true, makes things like SSE more robust. Shouldn't be set to
  true for streaming data without meaningful chunks
  """
  def set_flush_every_chunk(boolean) when is_boolean(boolean) do
    section =
      Raxx.Context.retrieve(__MODULE__, %{})
      |> Map.put(@flush_every_chunk, boolean)

    Raxx.Context.set(__MODULE__, section)
  end

  def flush_every_chunk?() do
    Raxx.Context.retrieve(__MODULE__, %{})
    |> Map.get(@flush_every_chunk, false)
  end

  # callbacks

  @impl Middleware
  def process_head(%Request{} = request, config, inner_server) do
    {request, state} = negotiate_encoding(request, config)
    {parts, inner_server} = Server.handle_head(inner_server, request)
    {state, parts} = State.compress_parts(state, parts)
    {parts, state, inner_server}
  end

  @impl Middleware
  def process_data(data, state, inner_server) do
    {parts, inner_server} = Server.handle_data(inner_server, data)
    {state, parts} = State.compress_parts(state, parts)
    {parts, state, inner_server}
  end

  @impl Middleware
  def process_tail(tail, state, inner_server) do
    {parts, inner_server} = Server.handle_tail(inner_server, tail)
    {state, parts} = State.compress_parts(state, parts)
    {parts, state, inner_server}
  end

  @impl Middleware
  def process_info(info, state, inner_server) do
    {parts, inner_server} = Server.handle_info(inner_server, info)
    {state, parts} = State.compress_parts(state, parts)
    {parts, state, inner_server}
  end

  @spec negotiate_encoding(Raxx.Request.t(), Keyword.t()) :: {Raxx.Request.t(), State.t()}
  def negotiate_encoding(%Request{} = request, _options) do
    encoding_preferences =
      Raxx.get_header(request, "accept-encoding")
      |> parse_encoding_preferences()

    if "gzip" in encoding_preferences do
      # make sure no further middleware tries encoding it
      request = Raxx.delete_header(request, "accept-encoding")

      zstream = :zlib.open()
      # see the :zlib.gzip() implementation
      :zlib.deflateInit(zstream, :default, :deflated, 31, 8, :default)

      state = %State{
        compression_type: "gzip",
        zstream: zstream
      }

      {request, state}
    else
      {request, %State{}}
    end
  end

  def parse_encoding_preferences(nil) do
    []
  end

  def parse_encoding_preferences(accept_encoding_header_value) do
    Regex.replace(~r/\s/, accept_encoding_header_value, "", [])
    |> String.split(",")
    |> Enum.reject(&(&1 == ""))
    |> Enum.map(&parse_encoding_qvalue/1)
    |> Enum.sort_by(fn {_k, v} -> -1.0 * v end)
    |> Enum.map(fn {k, _v} -> k end)
  end

  def parse_encoding_qvalue(encoding_qvalue) do
    case String.split(encoding_qvalue, ";q=") do
      [just_value] ->
        {just_value, 1.0}

      [value, qvalue] ->
        case Float.parse(qvalue) do
          {float, _rest} ->
            {value, float}

          _error ->
            {value, 1.0}
        end

      [value | _rest] ->
        {value, 1.0}
    end
  end
end
