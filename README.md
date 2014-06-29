sidekiq-cluster-cron
====================

Just a test/concept to resolve the following issue.

## Scenario

A rails app that need to be placed behind an http balancer to improve performance, SLA etc... This app requires of a never ending job that coninuosly analize the data collected making any sort of calculations etc....
The job is actually runned as a deamon and is basically a never ending loop with a short sleep, something like:

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
that any new server added to the cluster is absolutely identical to the others.
* The background JOB must be unique. This means that while we add more nodes to our cluster we must be sure that our JOB is never runned in parallel. For avoiding data corruption we cannot have 2 JOB instance running at the same time.
* Our JOB must run more often as possible.
* We must consider that we cannot be sure on how long the JOB will take to end.

## Issues

While our goal is to add more nodes to a cluster we cannot rely on linux cron. We should need to add the cron rules to one specific server (we cannot run more that one JOB at a time!). This means that swithing off that machine should stop the JOB up to when we do not restart it.
Another solutions should be to deploy and demonize our actual JOB class on any node. The issue here is that we should then implement a distrinuited lock system and make our JOB able to manage the lock/unlock for preventing concurrency.

## Solution - Sidqkiq Cron and Unique jobs to the rescue

A simple solution is using Sidekiq and some interesting Sidekiq plugins.

..... more to come ....



  


