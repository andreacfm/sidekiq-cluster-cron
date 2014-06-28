require 'sidekiq'
require 'sidekiq/web'

Sidekiq.configure_server do |config|
  config.redis = {:url => 'redis://localhost:6379', :namespace => "sidetest:sidekiq:#{Rails.env}"}
  config.error_handlers << Proc.new { |ex, ctx_hash| Airbrake.notify_or_ignore(ex, parameters: ctx_hash) }
  config.on(:startup) do
    schedule_file = 'config/schedule.yml'
    if File.exists?(schedule_file)
      Sidekiq::Cron::Job.load_from_hash YAML.load_file(schedule_file)
    end
  end
end

Sidekiq.configure_client do |config|
  config.redis = {:url => 'redis://localhost:6379', :namespace => "sidetest:sidekiq:#{Rails.env}"}
end
