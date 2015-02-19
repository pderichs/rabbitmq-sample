require 'bunny'
require 'json'
require 'active_support/all'
require 'readline'

conn = Bunny.new
conn.start

ch = conn.create_channel
in_q = ch.queue('app.packager.tasks')

puts 'Waiting for work...'

Thread.new do
  in_q.subscribe(manual_ack: true, block: true) do |delivery_info, properties, body|
    puts 'Got message'

    coord_ch = conn.create_channel
    begin
      coord_days_queue = coord_ch.queue('app.coordinator.days')

      calc_ch = conn.create_channel
      begin
        calc_in_queue = calc_ch.queue('app.calc.tasks')

        task = JSON.parse(body)

        from = Date.strptime(task['from'],"%Y%m%d")
        to = Date.strptime(task['to'],"%Y%m%d")

        # Send item count to coordinator
        daysdiff = (to - from).to_i
        puts "Diff in days: #{daysdiff}"
        # Send day count to coordinator
        coord_days_queue.publish(daysdiff.to_s, persistent: true)

        # Create tasks for calc - one task for each day
        date = from
        while date < to
          calc_in_queue.publish(date.to_s, persistent: true)
          date = date + 1.day
        end
      ensure
        calc_ch.close
      end
    ensure
      coord_ch.close
    end

    ch.ack(delivery_info.delivery_tag)
  end
end

s = Readline.readline('> ')