use "../backpressure"

actor TCPSourceListener
  """
  # TCPSourceListener
  """

  let _notify: TCPSourceListenerNotify
  var _fd: U32
  var _event: AsioEventID = AsioEvent.none()
  let _limit: USize
  var _count: USize = 0
  var _closed: Bool = false
  var _init_size: USize
  var _max_size: USize

  new create(source_builder: SourceBuilder val,
    host: String = "", service: String = "0",
    limit: USize = 0,
    init_size: USize = 64, max_size: USize = 16384)
  =>
    """
    Listens for both IPv4 and IPv6 connections.
    """
    _notify = SourceListenerNotify(source_builder)
    _event = @pony_os_listen_tcp[AsioEventID](this,
      host.null_terminated().cstring(), service.null_terminated().cstring())
    _limit = limit

    _init_size = init_size
    _max_size = max_size
    _fd = @pony_asio_event_fd(_event)
    _notify_listening()

  be _event_notify(event: AsioEventID, flags: U32, arg: U32) =>
    """
    When we are readable, we accept new connections until none remain.
    """
    if event isnt _event then
      return
    end

    if AsioEvent.readable(flags) then
      _accept(arg)
    end

    if AsioEvent.disposable(flags) then
      @pony_asio_event_destroy(_event)
      _event = AsioEvent.none()
    end

  be _conn_closed() =>
    """
    An accepted connection has closed. If we have dropped below the limit, try
    to accept new connections.
    """
    _count = _count - 1

    if _count < _limit then
      _accept()
    end

  fun ref _accept(ns: U32 = 0) =>
    """
    Accept connections as long as we have spawned fewer than our limit.
    """
    if _closed then
      return
    end

    while (_limit == 0) or (_count < _limit) do
      var fd = @pony_os_accept[U32](_event)

      match fd
      | -1 =>
        // Something other than EWOULDBLOCK, try again.
        None
      | 0 =>
        // EWOULDBLOCK, don't try again.
        return
      else
        _spawn(fd)
      end
    end

  fun ref _spawn(ns: U32) =>
    """
    Spawn a new connection.
    """
    try
      TCPSource._accept(this, _notify.connected(this), ns, _init_size,
        _max_size)
      _count = _count + 1
    else
      @pony_os_socket_close[None](ns)
    end

  fun ref _notify_listening() =>
    """
    Inform the notifier that we're listening.
    """
    if not _event.is_null() then
      _notify.listening(this)
    else
      _closed = true
      _notify.not_listening(this)
    end