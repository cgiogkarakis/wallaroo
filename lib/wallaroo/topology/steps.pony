use "buffered"
use "time"
use "net"
use "collections"
use "sendence/epoch"
use "wallaroo/metrics"
use "wallaroo/resilience"
use "wallaroo/messages"

actor Step is ResilientOrigin
  let _runner: Runner
  let _hwm: HighWatermarkTable = HighWatermarkTable(10)
  let _lwm: LowWatermarkTable = LowWatermarkTable(10)
  let _translate: TranslationTable = TranslationTable(10)
  let _origins: OriginSet = OriginSet(10)
  var _router: Router val = EmptyRouter
  let _metrics_reporter: MetricsReporter 
  let _outgoing_envelope: MsgEnvelope ref
  
  new create(runner: Runner iso, metrics_reporter: MetricsReporter iso) =>
    _runner = consume runner
    _runner.set_buffer_target(this)
    _metrics_reporter = consume metrics_reporter
    _outgoing_envelope = MsgEnvelope(this, 0, None, 0, 0)

  fun _send_watermark()
  =>
    // for origin in _all_origins.values do
    //   origin.update_watermark(route_id, seq_id)
    // end
    None
    
  be update_router(router: Router val) => _router = router

  be run[D: Any val](metric_name: String, source_ts: U64, data: D,
    incoming_envelope: MsgEnvelope val)
  =>
    let is_finished = _runner.run[D](metric_name, source_ts, data,
      _outgoing_envelope, incoming_envelope, _router)
    if is_finished then
      ifdef "resilience" then
        _bookkeeping(incoming_envelope)
        // if Sink then _send_watermark()
      end
      _metrics_reporter.pipeline_metric(metric_name, source_ts)
    end
    
  be recovery_run[D: Any val](metric_name: String, source_ts: U64, data: D,
    incoming_envelope: MsgEnvelope val)
  =>
    let is_finished = _runner.recovery_run[D](metric_name, source_ts, data,
      _outgoing_envelope, incoming_envelope, _router)
    if is_finished then
      _bookkeeping(incoming_envelope)
      _metrics_reporter.pipeline_metric(metric_name, source_ts)
    end
    
  be replay_log_entry(uid: U64, frac_ids: (Array[U64] val | None), statechange_id: U64, payload: Array[ByteSeq] val) =>
    _runner.replay_log_entry(uid, frac_ids, statechange_id, payload, this)

  be replay_finished() =>
    _runner.replay_finished()

  be dispose() =>
    match _router
    | let r: TCPRouter val =>
      r.dispose()
    // | let sender: DataSender =>
    //   sender.dispose()
    end

  be update_watermark(route_id: U64, seq_id: U64)
  =>
  """
  Process a high watermark received from a downstream step.
  TODO: receive watermark, flush buffers and send another watermark
  """
  // translate downstream seq_id to origin's seq_id
  let origin_seq_id = _translate.outToIn(seq_id)
  // update low watermark for this route_id
  _lwm.update(route_id, seq_id)
  // report low watermark to upstream origins
  for origin in _origins.values() do
    //   origin.update_watermark(_lwm.low_watermark())
    None
  end

  
  fun ref _bookkeeping(incoming_envelope: MsgEnvelope val)
  =>
    """
    Process envelopes and keep track of things
    """
    // keep track of messages we've received from upstream
    _hwm.update((incoming_envelope.origin , incoming_envelope.route_id),
      incoming_envelope.seq_id)
    // keep track of mapping between incoming / outgoing seq_id
    _translate.update(incoming_envelope.seq_id, _outgoing_envelope.seq_id)
    // keep track of origins
    _origins.set(incoming_envelope.origin)
    
interface StepBuilder
  fun id(): U128

  fun apply(next: Router val, metrics_conn: TCPConnection,
    pipeline_name: String): Step tag

// trait ThroughStepBuilder[In: Any val, Out: Any val] is StepBuilder

class StatelessStepBuilder
  let _runner_sequence_builder: RunnerSequenceBuilder val
  let _id: U128

  new val create(r: RunnerSequenceBuilder val, id': U128) =>
    _runner_sequence_builder = r
    _id = id'

  fun id(): U128 => _id

  fun apply(next: Router val, metrics_conn: TCPConnection,
    pipeline_name: String): Step tag =>
    let runner = _runner_sequence_builder(MetricsReporter(pipeline_name, 
      metrics_conn))
    // let runner = ComputationRunner[In, Out](_computation_builder(),
      // consume next, MetricsReporter(pipeline_name, metrics_conn))
    let step = Step(consume runner, 
      MetricsReporter(pipeline_name, metrics_conn))
    step.update_router(next)
    step