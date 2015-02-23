require 'bunny'
require 'json'

class PackagerServer
  def initialize(channel)
    @channel = channel
  end

  def split_into_day_tasks(task)
    from = Date.strptime(task['from'])
    to = Date.strptime(task['to'])

    (from..to).map do |day|
      {
        task_id: task['task_id'],
        date: day
      }
    end
  end

  def start(queue_name)
    @q = @channel.queue(queue_name)
    @x = @channel.default_exchange

    @q.subscribe(block: true) do |delivery_info, properties, payload|
      puts "Got #{payload}"
      task = JSON.parse(payload)
      day_tasks = split_into_day_tasks(task)

      @x.publish(
        day_tasks.to_json,
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
  server = PackagerServer.new(ch)
  puts 'Packager: Awaiting RPC requests'
  server.start 'packager_queue'
rescue Interrupt => _
ensure
  ch.close
  conn.close
end

puts 'Bye.'
puts ''
