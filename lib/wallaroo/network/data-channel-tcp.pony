use "net"
use "time"
use "buffered"
use "collections"
use "sendence/bytes"
use "wallaroo/messages"
use "wallaroo/metrics"
use "wallaroo/topology"


class DataChannelListenNotifier is TCPListenNotify
  let _name: String
  let _env: Env
  let _auth: AmbientAuth
  let _is_initializer: Bool
  var _host: String = ""
  var _service: String = ""
  let _router: DataRouter val
  let _connections: Connections

  new iso create(name: String, env: Env, auth: AmbientAuth, 
    connections: Connections, is_initializer: Bool, routes: DataRouter val = 
    DataRouter)
  =>
    _name = name
    _env = env
    _auth = auth
    _is_initializer = is_initializer
    _router = routes
    _connections = connections

  fun ref listening(listen: TCPListener ref) =>
    try
      (_host, _service) = listen.local_address().name()
      _env.out.print(_name + " data channel: listening on " + _host + ":" + _service)
      if not _is_initializer then
        let message = ChannelMsgEncoder.identify_data_port(_name, _service,
          _auth)
        _connections.send_control("initializer", message)
      end
    else
      _env.out.print(_name + "control : couldn't get local address")
      listen.close()
    end

  fun ref connected(listen: TCPListener ref): TCPConnectionNotify iso^ =>
    DataChannelConnectNotifier(_router, _env, _auth)

class DataOrigin is Origin
  // be update_watermark(route_id: U64, seq_id: U64)
  // =>
  //   //TODO: ack on TCP?
  //   None

class DataChannelConnectNotifier is TCPConnectionNotify
  let _router: DataRouter val
  let _env: Env
  let _auth: AmbientAuth
  let _origin: DataOrigin 
  var _header: Bool = true

  new iso create(routes: DataRouter val, env: Env, auth: AmbientAuth) =>
    _router = routes
    _env = env
    _auth = auth
    _origin = DataOrigin

  fun ref received(conn: TCPConnection ref, data: Array[U8] iso): Bool =>
    if _header then
      try
        let expect = Bytes.to_u32(data(0), data(1), data(2), data(3)).usize()

        conn.expect(expect)
        _header = false
      end
    else
      match ChannelMsgDecoder(consume data, _auth)
      | let d: DeliveryMsg val =>
        @printf[I32]("Received delivery msg!!\n".cstring())
        //TODO: create real envelope
        let outgoing_envelope = MsgEnvelope(_origin,0,None,0,0)
        //TODO: read envelope from data
        let incoming_envelope = outgoing_envelope.clone()
        _router.route[DeliveryMsg val](d.metric_name(), d.source_ts(), d,
          outgoing_envelope, incoming_envelope)
      | let m: SpinUpLocalTopologyMsg val =>
        _env.out.print("Received spin up local topology message!")
      | let m: UnknownChannelMsg val =>
        _env.err.print("Unknown Wallaroo data message type.")
      else
        _env.err.print("Unknown Wallaroo data message type.")
      end

      conn.expect(4)
      _header = true
    end
    false

  fun ref accepted(conn: TCPConnection ref) =>
    _env.out.print("accepted")
    conn.expect(4)

  fun ref connected(sock: TCPConnection ref) =>
    _env.out.print("incoming connected")

class DataSenderConnectNotifier is TCPConnectionNotify
  let _env: Env

  new iso create(env: Env)
  =>
    _env = env

  fun ref received(conn: TCPConnection ref, data: Array[U8] iso): Bool =>
    _env.out.print("Data sender channel received data.")
    true

  // fun ref closed(conn: TCPConnection ref) =>
  //   _coordinator.reconnect_data(_target_name)