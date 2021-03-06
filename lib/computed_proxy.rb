
module AsyncProxy
  
  # a specialization of ObjectProxy to be used when the wraped value is dependent on another
  # async proxy and a computation (a block)
  #
  # will be automatically created by calling a method or +when_ready+ in any async object 
  #
  # the user should not directly create objects of this class
  
  class ComputedProxy < ObjectProxy
    
    attr_reader :callable
    attr_reader :proc
    attr_reader :trace_name
    
    def initialize(callable, proc, trace_name = nil)
      @callable   = callable
      @proc       = proc
      @trace_name = trace_name
      @callbacks = []
    end
    
    def ready?
      @ready
    end
    
    def async
      self
    end
    
    # waits for the computation to finish and returns the actual result
    #
    # optional arguments:
    #   - timeout: the maximum number of seconds that the computation can take.
    
    def sync(options = {})
      if options[:timeout]
        if (!defined?(RUBY_ENGINE) || "ruby" == RUBY_ENGINE) && RUBY_VERSION < '1.9'
          Timeout.timeout(options[:timeout]){wait_for_computation}
        else
          SystemTimer.timeout_after(options[:timeout]){wait_for_computation}
        end
      else
        wait_for_computation
      end
      @result
    end

    def launch_computation
      @thread = Thread.new do
        @result = @proc.call(@callable.sync)
        @ready = true
        run_callbacks
      end
    end

    def wait_for_computation
      callable.sync # ensures the callable has finished and run its callbacks
      @thread.join unless @done
    end
    
    private
      def run_callbacks
        @callbacks.each { |block| block.call @result }
      end
  end
end
