require "colorize"
require "oj"
require "trollop"

module AllTweets
  class CLI
    def initialize
      @screen_name, @opts = parse_args
      @settings = Settings.new
      update_access_token
      @collector = Collector.new(
        consumer_key: @settings.consumer_key,
        consumer_secret: @settings.consumer_secret,
        access_token: @settings.access_token,
        access_token_secret: @settings.access_token_secret
      )
      @filename = filename
    end

    def run
      puts "Saving #{@screen_name}'s all tweets to #{@filename}"
      result = @collector.get_all_tweets(@screen_name, include_retweets: @opts[:retweets]).map(&:to_h)

      if @opts[:json]
        dump_data = Oj.dump(result, mode: :compat)
      else
        dump_data = YAML.dump(result)
      end

      open(filename, "w") do |f|
        f.puts dump_data
      end
    rescue
      puts "Error: #{$!}".colorize(:red)
    end

    private
    def parse_args
      opts = Trollop::options do
        opt :retweets, "Include retweets to output"
        opt :json, "Use JSON"
      end
      screen_name = ARGV.first
      [screen_name, opts]
    end

    def update_access_token
      unless @settings.exist?
        consumer = OAuth::Consumer.new(
          @settings.consumer_key,
          @settings.consumer_secret,
          site: "https://api.twitter.com"
        )
        request_token = consumer.get_request_token

        puts "1) Open: #{request_token.authorize_url}".colorize(:cyan)
        Launchy.open(request_token.authorize_url)

        print "2) Enter the PIN: ".colorize(:cyan)
        pin = $stdin.gets.strip

        access_token = request_token.get_access_token(oauth_verifier: pin)

        puts "Saving access token and access token secret to #{@settings.filename}"
        @settings.add_access_tokens(access_token.token, access_token.secret)
      end
    end

    def filename
      ext = @opts[:json] ? ".json" : ".yml"
      "alltweets_#{@screen_name}#{ext}"
    end
  end
end
