require 'byebug'
require 'bunny'
require 'securerandom'
require 'json'

require_relative '../lib/bunny_rpc_client.rb'

class ApiServer
  attr_reader :channel

  def initialize(channel)
    @channel = channel
    @packager_client = BunnyRpcClient.new(@channel, 'packager_queue')
    @calc_client = BunnyRpcClient.new(channel, 'calc_queue')
  end

  def start(queue_name)
    # "Command line"
    while true do
      cmd = Readline.readline('> ')

      case cmd
      when 'send'
        start_new_call Date.new(2012, 1, 1), Date.new(2012, 1, 5)
      when 'quit', 'exit'
        break
      else
        puts 'enter "send" or "quit"'
        puts ''
      end
    end
  end

  def start_new_call(from, to)
    task_id = SecureRandom.uuid

    # start call
    payload = { task_id: task_id, from: from.to_s, to: to.to_s }
    day_tasks = @packager_client.call(payload)
    puts "Packager Result: #{day_tasks}"
    that = self

    # Send day tasks to calc:
    puts "Calling calc..."
    day_tasks.each do |day_task|
      result = @calc_client.call(day_task)
      puts "  --> #{result}"
    end
  end
end

conn = Bunny.new
conn.start
ch = conn.create_channel

server = ApiServer.new(ch)
server.start 'api_queue'

ch.close
conn.close
puts 'Bye.'
puts ''
