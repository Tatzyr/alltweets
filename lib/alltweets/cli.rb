require "json"
require "optparse"
require "rainbow/ext/string"
require "alltweets/fetcher"
require "alltweets/settings"
require "alltweets/version"

module AllTweets
  class CLI
    def run
      Rainbow.enabled = true # forcing coloring even when stdout/stderr is not a tty
      @screen_name, @opts = parse_args
      @settings = Settings.new
      update_access_token
      fetch_and_print
    rescue
      warn "Error: #{$!}".color(:red)
      exit 1
    end

    private

    def parse_args
      opts = ARGV.getopts("", "help", "version")

      if opts["help"]
        puts <<~EOS
          alltweets #{VERSION}
          
          Usage:
            alltweets [options] SCREEN_NAME
          
          Options:
            -v, --version     Print version and exit
            -h, --help        Show this message
        EOS
        exit
      end

      if opts["version"]
        puts "alltweets #{VERSION}"
        exit
      end

      unless ARGV.size == 1
        warn "usage: alltweets [options] SCREEN_NAME"
        exit 1
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

        warn "You need to get token/secret pair of Twitter OAuth.".color(:cyan)
        warn "The token/secret pair will be saved to #{@settings.filename}".color(:cyan)
        warn "".color(:cyan)
        warn "1) Open: #{request_token.authorize_url}".color(:cyan)
        $stderr.print "2) Enter the PIN: ".color(:cyan)
        pin = $stdin.gets.strip

        access_token = request_token.get_access_token(oauth_verifier: pin)

        @settings.add_access_tokens(access_token.token, access_token.secret)
        warn "Saved the token/secret pair to #{@settings.filename}".color(:cyan)
      end
    end

    def fetch_and_print
      fetcher = Fetcher.new(
        consumer_key: @settings.consumer_key,
        consumer_secret: @settings.consumer_secret,
        access_token: @settings.access_token,
        access_token_secret: @settings.access_token_secret
      )

      warn "Downloading @#{@screen_name}'s all tweets..."
      result = fetcher.fetch_all_tweets(@screen_name).map(&:to_h)
      puts JSON.dump(result)
    end
  end
end
