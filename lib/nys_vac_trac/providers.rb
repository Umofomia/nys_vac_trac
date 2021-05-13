# frozen_string_literal: true

require_relative 'provider'

module NYSVacTrac
  class Providers
    attr_reader :providers, :updated_at

    class << self
      PROVIDERS_URL = URI('https://am-i-eligible.covid19vaccine.health.ny.gov/api/list-providers')
      TIME_ZONE = ActiveSupport::TimeZone["America/New_York"]
      TIME_FORMAT = '%m/%d/%Y, %l:%M:%S %p'

      def load
        provider_response = list_providers
        providers = provider_response[:provider_list].map do |provider|
          Provider.new(**provider.slice(:provider_name, :address, :available_appointments))
        end.sort_by(&:location)
        updated_at = TIME_ZONE.strptime(provider_response[:last_updated], TIME_FORMAT)
        new(providers, updated_at)
      end

      private

      def list_providers
        response = Net::HTTP.get(PROVIDERS_URL)
        JSON.parse(response).deep_transform_keys { |key| key.underscore.to_sym }
      end
    end

    def initialize(providers, updated_at)
      @providers = providers
      @updated_at = updated_at
    end

    def at(*locations)
      locations = locations.map { |location| location.to_s.parameterize.underscore }
      providers = @providers.select do |provider|
        locations.include?(provider.location.parameterize.underscore)
      end
      self.class.new(providers, @updated_at)
    end

    def locations
      @providers.map(&:location).uniq
    end

    def available
      self.class.new(@providers.select(&:available?), @updated_at)
    end

    def empty?
      @providers.empty?
    end
  end
end
