require 'forwardable'

class PrimeFinder
  module CollectionResult
    def initialize_result; self.result = [] end
    private :initialize_result
  end

  module OptionsValidation
    class InvalidOptions < StandardError; end

    INVALID_MODE = -> (mode) {
      InvalidOptions.new(
        ":mode not recognised, available modes are #{MODES.join(', ')}, :mode is #{mode}"
      )
    }
    FROM_GT_TO = -> (from, to) do
      InvalidOptions.new(":from cannot be larger than :to (from is #{from}, to is #{to})")
    end

    def check_from_not_gt_to
      raise FROM_GT_TO.(from, to) if from > to
    end

    def check_mode
      return unless respond_to?(:mode)
      raise INVALID_MODE.(mode) unless ::PrimeFinder::MODES.include?(mode)
    end

    def check_options_validity
      check_from_not_gt_to && check_mode
    end
  end

  include OptionsValidation

  MODES = %i(find_x all first last).freeze

  attr_accessor :mode, :quantity, :from, :to

  def initialize(**opts)
    # mode opts:
    #   :find_x => find first x amount (specified by :quantity option and limited by :from and :to options)
    #   :all    => find all within range (specified by :from and :to) (ignores :quantity option if passed)
    #   :first  => find first from within range (specified by :from and :to) (ignores :quantity option if passed)
    #   :last   => find last from within range (specified by :from and :to) (ignores :quantity option if passed)
    self.mode     = opts.fetch(:mode, :find_x)
    self.quantity = opts.fetch(:quantity, 100)
    self.from     = opts.fetch(:from, 1)
    self.to       = opts.fetch(:to, 1000)

    check_options_validity
  end

  def find
    check_mode
    Object.const_get(mode_klazz).new(self).perform
  end

  private

  def mode_klazz
    'PrimeFinder::' << mode.to_s.split('_').map { |str| str.capitalize }.join
  end

  class Base
    extend Forwardable
    include OptionsValidation

    def_delegators :settings, :from, :to

    attr_accessor :settings, :possibilities, :range, :result, :counter

    def initialize(settings, **opts)
      self.settings      = settings
      self.possibilities = [*1..to]
      rng_end            = (to / 2) + 1
      self.range         = [*2..rng_end]
      self.counter       = 0

      initialize_result
      check_options_validity
    end

    def perform
      raise NotImplementedError, "Implement me"
    end

    private

    def initialize_result
      # Implement me if required!
    end

    def next_prime(int)
      possibilities.delete_if { |pos| pos != 1 && pos % int == 0 }.shift
    end
  end

  class FindX < Base
    include CollectionResult

    def_delegator :settings, :quantity

    def perform
      range.each do |i|
        return result unless (np = next_prime(i))
        result << np if np >= from && np <= to

        return result if result.size == quantity
      end

      result
    end
  end

  class All < Base
    include CollectionResult

    def perform
      range.each do |i|
        return result unless (np = next_prime(i))
        result << np if np >= from && np <= to
      end

      result
    end
  end

  class First < Base
    def perform
      range.each do |i|
        return result unless (np = next_prime(i))
        return self.result = np if np >= from && np <= to
      end
    end
  end

  class Last < Base
    def perform
      self.result = PrimeFinder::All.new(settings).perform.last
    end
  end
end

