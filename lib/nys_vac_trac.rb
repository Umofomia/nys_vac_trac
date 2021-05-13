# frozen_string_literal: true

require 'net/http'
require 'yaml'

require 'nys_vac_trac/poller'

module NYSVacTrac
  extend self

  def poll(*watchlist)
    poller = Poller.new(*watchlist)
    poller.poll
  end

end
