# Stolen from http://www.rabbitmq.com/tutorials/tutorial-six-ruby.html

require 'thread'

class BunnyRpcClient
  attr_reader :reply_queue
  attr_accessor :response, :call_id
  attr_reader :lock, :condition

  def initialize(ch, server_queue)
    @ch             = ch
    @x              = ch.default_exchange

    @server_queue   = server_queue
    @reply_queue    = @ch.queue('', exclusive: true)

    @lock      = Mutex.new
    @condition = ConditionVariable.new
    that       = self

    @reply_queue.subscribe do |delivery_info, properties, payload|
      return unless properties[:correlation_id] == that.call_id
      that.response = JSON.parse(payload)
      that.lock.synchronize { that.condition.signal }
    end
  end

  def call(days_task)
    self.call_id = days_task['task_id']

    @x.publish days_task.to_json,
      routing_key:    @server_queue,
      correlation_id: call_id,
      reply_to:       @reply_queue.name

    lock.synchronize { condition.wait lock }
    response
  end
end
