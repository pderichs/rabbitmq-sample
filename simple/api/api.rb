require 'bunny'
require 'json'
require 'readline'
require 'securerandom'

class ApiServer
  CALC_RESULTS = 'app.calc.results'.freeze
  PACKAGER_TASKS = 'app.packager.tasks'.freeze
  PACKAGER_DAYCOUNT_RESULT = 'app.packager.daycount'.freeze

  attr_reader :connection

  def initialize
    initialize_bunny
    create_packager_tasks_queue
    create_calc_results_queue
    create_packager_daycount_queue
    subscribe_to_queues

    @tasks = {}
    @tasks_lock = Mutex.new
  end

  def start_command_line
    while true do
      cmd = Readline.readline('> ')

      case cmd
      when 'send'
        send
      when 'list'
        list_tasks
      when 'quit', 'exit'
        break
      else
        puts 'enter "send" or "quit" or "exit"'
      end
    end
  end

  def close
    @calc_results_channel.close
    @packager_daycount_channel.close
    @channel.close
    connection.close
  end

  def send(task_count=1)
    task_count.times do
      id = SecureRandom.uuid
      task = { 'task_id' => id, 'from' =>'20120101', 'to' => '20120105' }
      @tasks_lock.synchronize do
        @tasks[id] = task
        task['start'] = Time.now
        task['results'] = []
      end
      @packager_tasks_queue.publish(task.to_json, persistent: true)
    end
  end

  private

  def list_tasks
    @tasks_lock.synchronize do
      @tasks.values.each do |task|
        task_id = task['task_id']
        expected = task['daycount']
        actual = task['results'].size
        state = actual >= expected ? 'Done.' : 'Pending.'
        puts "   #{task_id}  -> got: #{actual}, needed: #{expected}   --> #{state}"
      end
    end
  end

  def initialize_bunny
    @connection = Bunny.new
    @connection.start
  end

  def create_packager_tasks_queue
    @channel = connection.create_channel
    @packager_tasks_queue = @channel.queue(PACKAGER_TASKS)
  end

  def create_calc_results_queue
    @calc_results_channel = connection.create_channel
    @calc_results_queue = @calc_results_channel.queue(CALC_RESULTS)
  end

  def create_packager_daycount_queue
    @packager_daycount_channel = connection.create_channel
    @packager_daycount_queue = @packager_daycount_channel.queue(
      PACKAGER_DAYCOUNT_RESULT
    )
  end

  def subscribe_to_queues
    opts = { manual_ack: true }

    # Handling calc results
    @calc_results_queue.subscribe(opts) do |delivery_info, properties, body|
      puts 'Got calc result!'
      puts ''

      time = Time.now

      result = JSON.parse(body)
      puts "  --> #{result}"
      # Do further work with result (maybe store it elsewhere?)

      id = result['task_id']
      @tasks_lock.synchronize do
        @tasks[id]['results'] << result
        if @tasks[id]['results'].size >= @tasks[id]['daycount']
          @tasks[id]['end'] = time
        end
      end

      @calc_results_channel.ack(delivery_info.delivery_tag)
    end

    # Handling Day results
    @packager_daycount_queue.subscribe(opts) do |delivery_info, _props, body|
      result = JSON.parse(body)
      days = result['day_count']
      task_id = result['task_id']
      puts "Got days: #{days} (#{task_id})"
      puts ''

      @tasks_lock.synchronize do
        @tasks[task_id]['daycount'] = days
      end

      @packager_daycount_channel.ack(delivery_info.delivery_tag)
    end
  end
end


server = ApiServer.new
begin
  server.start_command_line
rescue Exception => e
  puts "ARGH! #{e}"
  raise
ensure
  puts 'Bye.'
  puts ''
  server.close
end

