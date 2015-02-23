require 'bunny'
require 'json'

class CalcServer
  def initialize(channel)
    @channel = channel
  end

  def start(queue_name)
    @q = @channel.queue(queue_name)
    @x = @channel.default_exchange

    @q.subscribe(block: true) do |delivery_info, properties, payload|
      puts "Got #{payload}"
      task = JSON.parse(payload)

      result = { task_id: task['task_id'], day: task['date'], result: 42 }

      @x.publish(
        result.to_json,
        routing_key: properties.reply_to,
        correlation_id: properties.correlation_id
      )
    end
  end
end

conn = Bunny.new
conn.start
ch = conn.create_channel

begin
  server = CalcServer.new(ch)
  puts 'Calc: Awaiting RPC requests'
  server.start 'calc_queue'
rescue Interrupt => _
ensure
  ch.close
  conn.close
end

puts 'Bye.'
puts ''
