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
      @beanstalk.yput({:type => 'rebuild'}, 65536, 0, 300)
    end

  end

  class JobRunner < JobAccess

    def process_rebuild
      MultiMatch.recache_all
    end

    def process
      job = @beanstalk.reserve
      stuff = job.ybody
      timing = Benchmark.measure do
        self.send "process_#{stuff[:type]}", stuff
      end
      printf "... Processed #{stuff[:type]} in %.5fs\n", timing.real
      job.delete
      job = nil
    rescue StandardError, Interrupt
      puts "Error in run process.  #{$!}" + $!.backtrace.join("\n\t")
      sleep 1
    ensure
      job.decay unless job.nil?
      $stdout.flush
    end

    def run
      loop { process }
    end

  end

end