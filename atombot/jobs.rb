require 'rubygems'
require 'beanstalk-client'
require 'benchmark'

require 'atombot/config'
require 'atombot/models'
require 'atombot/multimatch'

module AtomBot

  class JobAccess

    def initialize
      @beanstalk = Beanstalk::Pool.new [AtomBot::Config::CONF['jobs']['beanstalkd']]
      @beanstalk.watch AtomBot::Config::CONF['jobs']['tube']
      @beanstalk.ignore 'default'
      @beanstalk.use AtomBot::Config::CONF['jobs']['tube']
    end

    def rebuild
      @beanstalk.yput({'type' => 'rebuild'}, 65536, 0, 900)
    end

  end

  class JobRunner < JobAccess

    def process_rebuild(stuff)
      MultiMatch.recache_all
    end

    def get_deduplicated_jobs
      rv = {}
      # Get the first job...
      job = @beanstalk.reserve
      rv[job.ybody] = job
      # Now get the rest deduplicated
      100.times do
        job = @beanstalk.reserve(0)
        if rv.keys.include? job.ybody
          $logger.info "Removing duplicate job:  #{job.ybody['type']}"
          job.delete
        else
          rv[job.ybody] = job
        end
      end
    rescue Beanstalk::TimedOut
      rv.values
    end

    def run_job(job)
      stuff = job.ybody
      $logger.info "Running a #{stuff['type']}"
      timing = Benchmark.measure do
        self.send "process_#{stuff['type']}", stuff
      end
      printf "... Processed #{stuff['type']} in %.5fs\n", timing.real
      job.delete
      job = nil
    rescue StandardError, Interrupt
      $logger.info "Error in run process.  #{$!}" + $!.backtrace.join("\n\t")
      sleep 1
    ensure
      job.decay unless job.nil?
      $stdout.flush
    end

    def process
      get_deduplicated_jobs.each { |job| run_job job }
    end

    def run
      process
    end

  end

end
