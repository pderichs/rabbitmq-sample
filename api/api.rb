require 'bunny'
require 'json'
require 'readline'

conn = Bunny.new
conn.start

# Used to send tasks
ch = conn.create_channel
q = ch.queue('app.packager.tasks')

# Results from calc
results_ch = conn.create_channel
results_queue = results_ch.queue('app.coordinator.results') 

# Day result from packager
days_ch = conn.create_channel
days_queue = days_ch.queue('app.coordinator.days')


threads = []

# Handling calc results
threads << Thread.new do
  results_queue.subscribe(manual_ack: true, block: true) do |delivery_info, properties, body|
    puts 'Got calc result!'
    puts ''

    results_ch.ack(delivery_info.delivery_tag)
  end
end

# Handling Day results
threads << Thread.new do
  days_queue.subscribe(manual_ack: true, block: true) do |delivery_info, properties, body|
    days = body.to_i
    puts "Got days: #{days}"
    puts ''

    days_ch.ack(delivery_info.delivery_tag)
  end
end

# "Command line"
while true do
  cmd = Readline.readline('> ')

  case cmd
  when 'send' 
    task = { 'from' =>'20120101', 'to' => '20120105'}
    q.publish(task.to_json, persistent: true)
  when 'quit' 
    days_ch.close
    results_ch.close
    # It might be a bit hard, but... anyway... this is just a test right? ;-)
    exit
  else 
    puts 'enter "send" or "quit"'  
  end
end