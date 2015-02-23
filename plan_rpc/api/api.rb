require 'bunny'
require 'securerandom'
require 'lib/packager_client.rb'
require 'json'

class ApiServer
  def initialize(channel)
    @channel = channel
    @packager_client = PackagerClient.new
    @calc_client = CalcClient.new
  end

  def start(queue_name)
    start_input_queue_handling queue_name

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
  end

  def start_new_call(from, to)
    task_id = SecureRandom.uuid

    # start call
    payload = { task_id: task_id, from: from, to: to }.to_json

    day_tasks = @packager_client.new_task(payload)
    day_tasks.each do |day_task|
      result = @calc_client.calc_for(day_task)
      puts result
    end
  end

  private

  def start_input_queue_handling(queue_name)
    @queue = @channel.queue(queue_name)
    @xchange = @channel.default_exchange

    @input_handler = Thread.new do
      @queue.subscribe(block: true) do |delivery_info, properties, payload|
        # n = payload.to_i
        # r = FibonacciServer.fib(n)

        # @xchange.publish(
        #   r.to_s,
        #   routing_key: properties.reply_to,
        #   correlation_id: properties.correlation_id
        # )
      end
    end
  end
end

conn = Bunny.new
ch = conn.create_channel

server = ApiServer.new(ch)
server.start('api_queue')
