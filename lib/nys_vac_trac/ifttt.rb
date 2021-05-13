# frozen_string_literal: true

module NYSVacTrac
  class Ifttt
    PROJECT_ROOT = Pathname(__dir__).parent.parent
    CONFIG_FILE = PROJECT_ROOT.join('config', 'ifttt.yml')
    WEBHOOK_URL_FORMAT = 'https://maker.ifttt.com/trigger/%s/with/key/%s'

    def initialize
      @config = YAML.load_file(CONFIG_FILE).deep_symbolize_keys
      @webhook_config = @config.dig(:ifttt, :webhook)
    end

    def trigger_webhook(**payload)
      uri = webhook_url
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true if uri.instance_of? URI::HTTPS
      request = Net::HTTP::Post.new(uri, 'Content-Type' => 'application/json')
      request.body = payload.slice(:value1, :value2, :value3).to_json
      response = http.request(request)
      response.body
    end

    private

    def webhook_url
      url_str = format(WEBHOOK_URL_FORMAT, *@webhook_config.values_at(:event, :key))
      URI(url_str)
    end

  end
end
