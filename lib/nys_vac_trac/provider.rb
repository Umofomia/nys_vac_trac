# frozen_string_literal: true

module NYSVacTrac
  class Provider
    attr_reader :name, :location, :available
    alias_method :available?, :available

    def initialize(provider_name:, address:, available_appointments:)
      @name = provider_name
      @location = address.chomp(', NY')
      @available = available_appointments.in?(%w[AA Y])
    end
  end
end
