# bump..
class CoolWorker < IronWorker::Base
  attr_accessor :array_of_models
  merge '../models/cool_model'


  def run
    10.times do |i|
      puts "HEY THERE PUTS #{i}"
      log "HEY THERE LOG #{i}"
      sleep 1
    end
  end
end
