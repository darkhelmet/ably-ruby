module Ably::Modules
  # StateEmitter module adds a set of generic state related methods to a class on the assumption that
  # the instance variable @state is used exclusively, the {Enum} STATE is defined prior to inclusion of this
  # module, and the class is an {EventEmitter}.  It then emits state changes.
  #
  # It also ensures the EventEmitter is configured to retrict permitted events to the
  # the available STATEs and :error.
  #
  # @example
  #   class Connection
  #     include Ably::Modules::EventEmitter
  #     extend  Ably::Modules::Enum
  #     STATE = ruby_enum('STATE',
  #       :initialized,
  #       :connecting,
  #       :connected
  #     )
  #     include Ably::Modules::StateEmitter
  #   end
  #
  #   connection = Connection.new
  #   connection.state = :connecting     # emits :connecting event via EventEmitter, returns STATE.Connecting
  #   connection.state?(:connected)      # => false
  #   connection.connecting?             # => true
  #   connection.state                   # => STATE.Connecting
  #   connection.state = :invalid        # raises an Exception as only a valid state can be defined
  #   connection.trigger :invalid        # raises an Exception as only a valid state can be used for EventEmitter
  #   connection.change_state :connected # emits :connected event via EventEmitter, returns STATE.Connected
  #   connection.once_or_if(:connected) { puts 'block called once when state is connected or becomes connected' }
  #
  module StateEmitter
    # Current state {Ably::Modules::Enum}
    #
    # @return [Symbol] state
    def state
      STATE(@state)
    end

    # Evaluates if check_state matches current state
    #
    # @return [Boolean]
    def state?(check_state)
      state == check_state
    end

    # Set the current state {Ably::Modules::Enum}
    #
    # @return [Symbol] new state
    # @api private
    def state=(new_state, *args)
      if state != new_state
        logger.debug("#{self.class}: StateEmitter changed from #{state} => #{new_state}") if respond_to?(:logger, true)
        @state = STATE(new_state)
        trigger @state, *args
      end
    end
    alias_method :change_state, :state=

    # If the current state matches the target_state argument the block is called immediately.
    # Else the block is called once when the target_state is reached.
    #
    # If the option block :else is provided then if any state other than target_state is reached, the :else block is called,
    # however only one of the blocks will ever be called
    #
    # @param [Symbol,Ably::Modules::Enum,Array] target_states a single state or array of states that once met, will fire the success block only once
    # @param [Hash] options
    # @option options [Proc] :else block called once the state has changed to anything but target_state
    #
    # @yield block is called if the state is matched immediately or once when the state is reached
    #
    # @return [void]
    def once_or_if(target_states, options = {}, &success_block)
      raise ArgumentError, 'Block is expected' unless block_given?

      if Array(target_states).any? { |target_state| state == target_state }
        success_block.call
      else
        failure_block   = options.fetch(:else, nil)
        failure_wrapper = nil

        success_wrapper = Proc.new do
          success_block.call
          off &success_wrapper
          off &failure_wrapper if failure_wrapper
        end

        failure_wrapper = proc do |*args|
          failure_block.call *args
          off &success_wrapper
          off &failure_wrapper
        end if failure_block

        Array(target_states).each do |target_state|
          once target_state, &success_wrapper

          once_state_changed do |*args|
            failure_wrapper.call *args unless state == target_state
          end if failure_block
        end
      end
    end

    # Calls the block once when the state changes
    #
    # @yield block is called once the state changes
    # @return [void]
    #
    # @api private
    def once_state_changed(&block)
      raise ArgumentError, 'Block is expected' unless block_given?

      once_block = proc do |*args|
        off *self.class::STATE.map, &once_block
        yield *args
      end

      once *self.class::STATE.map, &once_block
    end

    private

    # Returns an {EventMachine::Deferrable} and once the target state is reached, the
    # success_block if provided and {EventMachine::Deferrable#callback} is called.
    # If the state changes to any other state, the {EventMachine::Deferrable#errback} is called.
    #
    def deferrable_for_state_change_to(target_state, &success_block)
      EventMachine::DefaultDeferrable.new.tap do |deferrable|
        once_or_if(target_state, else: proc { |*args| deferrable.fail self, *args }) do
          success_block.call self if block_given?
          deferrable.succeed self
        end
      end
    end

    def self.included(klass)
      klass.configure_event_emitter coerce_into: Proc.new { |event|
        if event == :error
          :error
        else
          klass::STATE(event)
        end
      }

      klass::STATE.each do |state_predicate|
        klass.instance_eval do
          define_method("#{state_predicate.to_sym}?") do
            state?(state_predicate)
          end
        end
      end
    end
  end
end
