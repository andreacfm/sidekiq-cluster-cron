class PrintWorker
  include Sidekiq::Worker
  sidekiq_options unique: true, :backtrace => true
  
  def perform
    p "I AM WORKING AT #{Time.now}"
    sleep 75
  end  
  
end  
  