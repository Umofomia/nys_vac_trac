# frozen_string_literal: true

require_relative 'providers'
require_relative 'ifttt'

module NYSVacTrac
  class Poller

    EXPECTED_UPDATE_INTERVAL = 1.hour
    MINIMUM_POLL_INTERVAL = 5.seconds
    MAXIMUM_POLL_INTERVAL = 15.minutes

    NOTIFICATION_TITLE = 'NYS COVID Vaccine Appointment Availablity'
    SIGNUP_LINK = 'https://am-i-eligible.covid19vaccine.health.ny.gov/Public/prescreener'

    attr_reader :watchlist

    def initialize(*watchlist)
      unless watchlist.empty?
        watchlist_locations = Providers.load.at(*watchlist).locations
        log("Watching for appointments at: #{watchlist_locations.to_sentence.light_yellow}")
      end
      @watchlist = watchlist
      @triggered_locations = []
    end

    def poll
      last_updated_at = nil
      last_update_interval = nil

      loop do
        current_providers = Providers.load
        if last_updated_at && last_updated_at == current_providers.updated_at
          log('No new updates.'.blue)
        else
          available_providers = current_providers.available
          if available_providers.empty?
            log('No available appointments anywhere.')
          else
            log("Available appointments at: #{available_providers.locations.to_sentence.green}")
            notify_watched_locations(available_providers)
          end

          if last_updated_at
            last_update_interval = current_providers.updated_at - last_updated_at
          end
          last_updated_at = current_providers.updated_at
          log("Last updated at: " + last_updated_at.localtime.to_s.cyan)
        end
        next_poll_at = calculate_next_poll_time(last_updated_at, last_update_interval)
        next_poll_duration = [next_poll_at - Time.now, 0].max

        next_poll_duration_formatted =
          ActiveSupport::Duration.build(next_poll_duration.round).inspect
        log("Next poll in #{next_poll_duration_formatted} at: ".blue +
              next_poll_at.localtime.to_s.light_black)

        sleep(next_poll_duration)
      end
    end

    private

    def calculate_next_poll_time(last_updated_at, last_update_interval)
      if last_update_interval.nil? || last_update_interval > EXPECTED_UPDATE_INTERVAL
        last_update_interval = EXPECTED_UPDATE_INTERVAL
      end

      skipped_updates = ((Time.now - last_updated_at) / last_update_interval).floor
      last_expected_update_at = last_updated_at + skipped_updates * last_update_interval

      next_poll_interval = MINIMUM_POLL_INTERVAL
      next_poll_at = last_expected_update_at + next_poll_interval
      while next_poll_at < Time.now
        next_poll_interval = [next_poll_interval * 2, MAXIMUM_POLL_INTERVAL].min
        next_poll_at += next_poll_interval
      end

      [next_poll_at, last_expected_update_at + last_update_interval].min
    end

    def notify_watched_locations(available_providers)
      available_watched_locations = available_providers.at(*watchlist).locations
      newly_available_locations = available_watched_locations - @triggered_locations
      no_longer_available_locations = @triggered_locations - available_watched_locations

      unless newly_available_locations.empty?
        trigger_notification("Available appointments at #{newly_available_locations.to_sentence}! Book now!")
        @triggered_locations.concat(newly_available_locations)
      end

      unless no_longer_available_locations.empty?
        message = "Appointments at #{no_longer_available_locations.to_sentence} no longer available!"
        trigger_notification(message)
        log(message.light_magenta)
        @triggered_locations -= no_longer_available_locations
      end

      unless available_watched_locations.empty?
        log("Available appointments at #{available_watched_locations.to_sentence}! Book now!".light_red)
      end
    end

    def trigger_notification(message, title: NOTIFICATION_TITLE, link: SIGNUP_LINK)
      Ifttt.new.trigger_webhook(value1: title, value2: message, value3: link)
    end

    def log(message)
      puts "#{timestamp} #{message}"
    end

    def timestamp
      "[#{Time.now}]".light_black
    end
  end
end
