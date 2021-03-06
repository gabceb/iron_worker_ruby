require_relative 'test_base'
require_relative 'workers/one_line_worker'
require_relative 'workers/merging_worker'
require_relative 'workers/progress_worker'
require_relative 'workers/mq_worker'
require 'concur'
#require_relative 'prawn_worker'

class BatchRun < TestBase

  def test_concur_batch

    IronWorker.logger.level = Logger::INFO

    clz = MqWorker
    num_tasks = 1000

    worker = clz.new
    worker.upload

    jobs = []
    executor = Concur::Executor.new_thread_pool_executor(20)
    num_tasks.times do |i|
      jobs << executor.execute do
        begin
          worker2 = clz.new
          puts "queueing #{i}"
          if clz == MqWorker
            worker2.config = {:token=>IronWorker.config.token, :project_id=>IronWorker.config.project_id}
          else
            worker2.x =  "hello payload #{i}"
          end
          response_hash = worker2.queue(:priority=>(@config[:priority] || 0))
          puts "response_hash #{i} = " + response_hash.inspect
          assert response_hash["msg"]
          assert response_hash["status_code"]
          assert response_hash["tasks"]
          assert response_hash["status_code"] == 200
          assert response_hash["tasks"][0]["id"].length == 24, "length is #{response_hash["tasks"][0]["id"].length}"
          assert response_hash["tasks"][0]["id"] == worker2.task_id, "id in hash: #{response_hash["tasks"][0]["id"]}, task_id: #{worker2.task_id}. response was #{worker2.response.inspect}"
          worker2
        rescue => ex
          puts "ERROR! #{ex.class.name}: #{ex.message} -- #{ex.backtrace.inspect}"
          raise ex
        end

      end
    end

    sleep 10

    completed_count = 0
    errored_queuing_count = 0
    error_count = 0
    while jobs.size > 0
      jobs.each_with_index do |f, i|
#    p f
        begin
          t = f.get
#      p t
          puts i.to_s + ' task_id=' + t.task_id.to_s
          status_response = t.status # worker.status(t["task_id"])
          puts 'status ' + status_response["status"] + ' for ' + status_response.inspect
          puts 'msg=' + status_response["msg"].to_s
          if status_response["status"] == "complete" || status_response["status"] == "error"
            if true || status_response["status"] == "error"
              puts t.get_log
            end

            jobs.delete(f)
            completed_count += 1
            puts "#{completed_count} completed so far. #{jobs.size} left..."
            if status_response["status"] == "error"
              error_count += 1
            end
          end
        rescue => ex
          puts 'error! ' + ex.class.name + ' -> ' + ex.message.to_s
          puts ex.backtrace
          errored_queuing_count += 1
          jobs.delete(f)
        end
      end
      puts 'sleep'
      sleep 2
      puts 'done sleeping'
    end

    puts 'Total completed=' + completed_count.to_s
    puts 'Total errored while queuing=' + errored_queuing_count.to_s
    puts 'Total errored while running=' + error_count.to_s

    executor.shutdown

    #tasks = []
    #1000.times do |i|
    #  puts "#{i}"
    #  worker = ProgressWorker.new
    #  #worker = OneLineWorker.new
    #  #    worker = MergingWorker.new
    #  #worker = PrawnWorker.new
    #  worker.queue
    #  tasks << worker
    #end
    #
    #tasks.each_with_index do |task, i|
    #  puts "#{i}"
    #  status = task.wait_until_complete
    #  p status
    #  puts "\n\n\nLOG START:"
    #  puts task.get_log
    #  puts "LOG END\n\n\n"
    #  assert status["status"] == "complete", "Status was not complete, it was #{status["status"]}"
    #end
    IronWorker.logger.level = Logger::DEBUG

  end

end

