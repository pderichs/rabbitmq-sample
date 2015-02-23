require 'bunny'
require 'json'
require 'active_support/all'
require 'readline'

conn = Bunny.new
conn.start

ch = conn.create_channel
in_q = ch.queue('app.calc.tasks')

puts 'Waiting for work...'

Thread.new do
  in_q.subscribe(manual_ack: true, block: true) do |delivery_info, properties, body|
    coord_ch = conn.create_channel
    coordinator_result_queue = coord_ch.queue('app.coordinator.results')

    task = Date.parse(body)
    puts "Got new calc message -> #{task}"

    # Simulate hard work
    sleep 3

    # Send a "result" which is pretty positive... like... every time...
    coordinator_result_queue.publish("OK", persistent: true)

    coord_ch.close

    ch.ack(delivery_info.delivery_tag)
  end
end

s = Readline.readline('> ')