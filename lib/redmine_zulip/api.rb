module RedmineZulip
  class Api
    attr_reader :url, :email, :key

    def initialize(url:, email:, key:)
      @url = "#{url}/api/v1"
      @key = key
      @email = email
    end

    def configured?
      url.present? && email.present? && key.present?
    end

    def messages
      RedmineZulip::Api::Messages.new(self)
    end

    private

    class Messages
      attr_reader :api

      def initialize(api)
        @api = api
      end

      def send(type:, to:, content:, subject: nil)
        form_data = {
          "type" => type,
          "to" => to,
          "content" => content
        }
        form_data["subject"] = subject if subject.present?
        uri = URI("#{api.url}/messages")
        req = Net::HTTP::Post.new(uri)
        req.basic_auth(api.email, api.key)
        req["User-Agent"] = "ZulipRedminePlugin/#{RedmineZulip::VERSION}"
        req.set_form_data(form_data)
        res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
          http.request(req)
        end
        res.code == "200"
      end
    end
  end
end
