require 'bunny'
require 'json'
require 'active_support/all'
require 'readline'

conn = Bunny.new
conn.start

ch = conn.create_channel
in_q = ch.queue('app.packager.tasks')

puts 'Waiting for work...'

in_q.subscribe(manual_ack: true) do |delivery_info, properties, body|
  puts 'Got message'

  task = JSON.parse(body)

  coord_ch = conn.create_channel
  begin
    coord_days_queue = coord_ch.queue('app.packager.daycount')

    calc_ch = conn.create_channel
    begin
      calc_in_queue = calc_ch.queue('app.calc.tasks')

      task = JSON.parse(body)

      from = Date.strptime(task['from'],"%Y%m%d")
      to = Date.strptime(task['to'],"%Y%m%d")

      # Send day count to api
      daysdiff = (to - from).to_i + 1
      puts "Diff in days: #{daysdiff}"
      result = { 'task_id' => task['task_id'], 'day_count' => daysdiff }
      coord_days_queue.publish(result.to_json, persistent: true)

      # Create tasks for calc - one task for each day
      calc_task = { 'task_id' => task['task_id'] }
      (from..to).each do |date|
        calc_task['date'] = date.to_s
        calc_in_queue.publish(calc_task.to_json, persistent: true)
      end
    ensure
      calc_ch.close
    end
  ensure
    coord_ch.close
  end

  ch.ack(delivery_info.delivery_tag)
end

s = Readline.readline('> ')

ch.close
conn.close

puts 'Bye.'
