sidekiq-cluster-cron
====================

Just a test/concept to resolve the following issue.

## Scenario

A rails app that need to be placed behind an http balancer to improve performance, SLA etc... This app requires a never ending job that coninuosly analizes the data collected making any sort of calculations etc....
The job is actually runned as a deamon and is basically a never ending loop with a short sleep. Something like this:

```ruby
	class Job
		def run 
			while true do 
				sleep 60
				# Do any sort of thing here
		    end		
		end
	end
```

## Goal

* We need to add an http balancer so that we can easily add extra node avoiding any downtime. To reach this goal we must be sure
that any new server added to the cluster is absolutely identical to the others. This will help us do not add extra complexity to our capistrano deploy scripts. We just want to add another IP to the :web roles and configure the balancer.
* The background JOB must be unique. This means that while we add more nodes to our cluster we must be sure that our JOB is never runned in parallel. For avoiding data corruption we cannot have 2 JOB instance running at the same time.
* Our JOB must run more often as possible.
* We must consider that we cannot be sure on how long the JOB will take to end.

## Issues

While our goal is to add more nodes to a cluster we cannot rely on linux cron. We should need to add the cron rules to one specific server (we cannot run more that one JOB at a time!). This means that swithing off that machine should stop the JOB up to when we do not restart it.
Another solutions should be to deploy and demonize our actual JOB class on any node. The issue here is that we should then implement a distrinuited lock system and make our JOB able to manage the lock/unlock for preventing concurrency. Probably someone has already done this for us!!

## Solution using sidekiq

A simple solution is using Sidekiq and some interesting Sidekiq plugins. Let's look at the exmaple app that implement this solution.
The app is just a plain rails app the uses the following gems:

```ruby

	gem 'sidekiq'
	gem 'sidekiq-cron', '~> 0.2.0'
	gem 'sidekiq-unique-jobs'	

```

For docs about sidekiq and the plugins take a look at the related github repos.

```ruby
	# config/initializers/sidekiq.rb
	
	require 'sidekiq'

	Sidekiq.configure_server do |config|
	  config.redis = {:url => 'redis://localhost:6379', :namespace => "sidetest:sidekiq:#{Rails.env}"}
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

```

Here we just add some basic sidekiq conf pointing to a local redis instance. Of course redis should be on a separate machine 
in our production environment. We also load the schedule file that will add our JOB to the cron.

```ruby
	# config/schedule.yml

	print:
	  cron: "*/1 * * * *"
	  class: "PrintWorker"
	  queue: default

```

The schedule file just says that our example JOB PrintWorker will be runned any minute.

```ruby
	# app/workers/print_worker.rb

	class PrintWorker
	  include Sidekiq::Worker
	  sidekiq_options unique: true
  
	  def perform
	    p "I AM WORKING AT #{Time.now}"
	    sleep 120
	  end  
  
	end  

```

This is our test worker. It just prints something out and sleep for 2 minutes. The sleep time will help us to prove that we can run the cron any minute without incurring in concurrent JOB execution even if the JOB takes longer than 1 minute.
To test it out just clone the repo, bundle and then open several shells in the project root.

In any shell launch sidekiq.

```sh

bundle exec sidekiq

```

If you look at the logs you will note that our test JOB will be enqueued just once any minute but will never be runned more than once at a time !! Exactly what we wanted to happen.

### Why is this working?

**sidekiq-cron** uses Rufus-Scheduler under the hood to parse the schedule and to get the next timestamp. The next occurrency is added to Redis in a **sorted set** that uses the timestamp as score and the job hash as member. This ensure that just one single JOB occurrency is actually in the set. So no matter how many sidekiq instance are running. While the JOB config is identical
this will never be scheduled more that once.

But we also do not want the scheduled JOB to run if the previous ones has not ended yet. For this purpose we rely on the **sidekiq-unique-jobs** gem that just does what promised. Adding a simple option to our JOB (sidekiq_options unique: true) will create a lock/unlock system for us. While **sidekiq-cron** will add the JOB any minute when the JOB is about to start **sidekiq-unique-jobs** will ensure that the JOB gets skipped if the previous onces has not exited yet.

At the end converting the JOB from a demonized never ending loop to a cron inside sidekiq allows us to deploy the same application on several nodes without worrying about maintaining a MASTER server that runs more service than the others. Just staring a sidekiq instance on any server will allow us to switch off one machine or add a new one to the cluster without worrying about having a downtime of some crucial service. Of course once sidekiq has kicked in we can then uses it to play any other backgroud, scheduled task we need.

Nice!



  


