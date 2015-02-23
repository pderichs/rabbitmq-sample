require 'byebug'
require 'bunny'
require 'securerandom'
require 'json'

require_relative '../lib/packager_client.rb'
require_relative '../lib/calc_client.rb'

class ApiServer
  attr_reader :channel

  def initialize(channel)
    @channel = channel
    @packager_client = PackagerClient.new(@channel, 'packager_queue')
  end

  def start(queue_name)
    # "Command line"
    while true do
      cmd = Readline.readline('> ')

      case cmd
      when 'send'
        start_new_call Date.new(2012, 1, 1), Date.new(2012, 1, 5)
      when 'quit', 'exit'
        # It might be a bit hard, but... anyway...
        # this is just a test right? ;-)
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
    puts "Result: #{day_tasks}"
    that = self

    # Send day tasks to calc:
    day_tasks.each do |day_task|
      # Thread.new do
        client = CalcClient.new(that.channel, 'calc_queue')
        result = client.call(day_task)
        puts "  --> #{result}"
      # end
    end

    #threads.each { |t| t.join }
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
