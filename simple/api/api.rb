require 'bunny'
require 'json'
require 'readline'
require 'securerandom'
require 'byebug'

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

    @tasks = {}
    @tasks_lock = Mutex.new

    subscribe_to_queues
  end

  def start_command_line
    while true do
      cmd = Readline.readline('> ')
      cmds = cmd.split(' ')

      case cmds[0]
      when 'send'
        count = 1
        count = cmds[1].to_i if cmds.size > 1
        send count
      when 'list'
        pending_only = false
        pending_only = (cmds[1] == 'pending') if cmds.size > 1
        list_tasks pending_only
      when 'stop'
        byebug
      when 'quit', 'exit'
        break
      else
        puts 'enter "send [count]", "list [done]" or "exit"'
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
    task_count.times do |i|
      # id = SecureRandom.uuid
      id = "#{i}"
      task = create_new_task(id)
      @tasks[id] = task
    end

    @tasks_lock.synchronize do
      @tasks.values.each do |task|
        @packager_tasks_queue.publish(task.to_json, persistent: true)
      end
    end
  end

  private

  def create_new_task(id)
    {
      'task_id' => id,
      'from' =>'20120101',
      'to' => '20120105',
      'results' => [],
      'start' => Time.now
    }
  end

  def list_tasks(pending_only = false)
    @tasks_lock.synchronize do
      @tasks.values.each do |task|
        task_id = task['task_id']
        expected = task['daycount']
        actual = task['results'].size
        state = actual == expected ? 'Done.' : 'Pending.'
        next if pending_only && state != 'Pending.'
        puts ''
        puts "  #{task_id}  " \
             " time: #{task['start']} - #{task['end']} " \
             "-> got: #{actual}, needed: #{expected}" \
             " --> #{state}"
        puts ''
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
      begin
        puts 'Got calc result!'
        puts ''

        # byebug

        @tasks_lock.synchronize do
          time = Time.now

          result = JSON.parse(body)
          puts "  --> #{result}"
          # Do further work with result (maybe store it elsewhere?)

          id = result['task_id']
          # byebug unless @tasks.key?(id)
          task = @tasks.fetch(id)
          task['results'] << result
          if task['results'].size >= task['daycount']
            task['end'] = time
          end
        end

        @calc_results_channel.ack(delivery_info.delivery_tag)
      rescue Exception => e
        puts "#{e}"
        byebug
        # raise
      end
    end

    # Handling Day results
    @packager_daycount_queue.subscribe(opts) do |delivery_info, _props, body|
      @tasks_lock.synchronize do
        result = JSON.parse(body)
        days = result['day_count']
        task_id = result['task_id']
        puts "Got days: #{days} (#{task_id})"
        puts ''

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

