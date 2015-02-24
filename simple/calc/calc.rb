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
    begin
      coordinator_result_queue = coord_ch.queue('app.calc.results')

      task = JSON.parse(body)
      puts "Got new calc message -> #{task}"

      # Simulate hard work
      # sleep 1

      # Send a "result"
      task['calc_result'] = 42
      coordinator_result_queue.publish(task.to_json, persistent: true)
    rescue Exception => e
      puts "ARGH! #{e}"
    ensure
      coord_ch.close
    end

    ch.ack(delivery_info.delivery_tag)
  end
end

s = Readline.readline('> ')

ch.close
conn.close
