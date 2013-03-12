#!/usr/bin/env ruby

# http://blitz.io
# http://www.mudynamics.com
# Making load and performance testing a fun sport!

begin
  require 'rubygems'
  gem 'blitz', "~> 0.1.29"
  gem "heroku-api", "~> 0.3.8"
  require 'blitz'
  require 'heroku-api'
rescue Exception
  puts 'Blitzer requires the following gems to be installed:'
  puts 'blitz'
  puts 'heroku-api'
  exit
end

class Blitzer
    ERROR_TOLERANCE = 2 # percentage of errors
    
    attr_reader :heroku
    attr_reader :app
    attr_reader :target
    attr_reader :path
    
    def initialize opts
        @heroku = Heroku::API.new :user => opts[:user], :api_key => opts[:pass]
        @app    = opts[:app]
        @target = opts[:target]
        @path = opts[:path]
    end
    
    # Kick off the number of dynos and wait until all those are up. We do
    # this by checking the state of each dyno until it's up.
    def set_dynos qty
        progress "starting #{qty} dyno(s) "

        heroku.post_ps_scale app, 'web', qty
        # heroku.set_dynos app, qty
        while true
            progress "."
            sleep 1.0
            dynos = heroku.get_ps(app).body
            web_synos = []
            dynos.each do |dyno|
                if dyno["process"].to_s.match(/^web/) != nil && (dyno["state"] == "up" || dyno["state"] == "idle")
                    web_synos << dyno
                end
            end
            break if web_synos.size == qty
        end
        
        progress "done\n"
    end
    
    def run
        [ 1, 2, 4, 8, 16, 32 ].each do |dyno|
            set_dynos dyno
            
            # The :status => 200 makes http://blitz.io generate an error when
            # we receive something other than 200 Okay during the load test.
            # And Heroku generates a 500 error when this happens so it allows
            # us to detect that the app crashed.
            opts = []
            opts << "-r virginia"
            opts << "-p 10-#{target}:30"

            url = "http://#{app}.herokuapp.com#{path}"
            opts << url

            progress "  rushing... #{url}\n"
            status = Blitz::Curl.parse(opts.join(" ")).execute do |s|
                progress "."
                last = s.timeline[-1]
                
                # Abort the rush, if the error rate is higher than 1%
                percent_errors = 100 - (last.hits * 100 / last.total)
                if percent_errors >= ERROR_TOLERANCE
                    ary = []
                    ary << "#{last.hits} hits"
                    ary << "#{last.errors} errors" if last.errors
                    ary << "#{last.timeouts} timeouts" if last.timeouts
                    progress "#{ary.join(' | ')} @ #{last.volume} users\n"
                end
                
                percent_errors < ERROR_TOLERANCE
            end

            # When there are no more errors, we've reached the
            # optimimum number of dynos for the target concurrency.
            last = status.timeline[-1]
            percent_errors = 100 - (last.hits * 100 / last.total)
            if percent_errors < ERROR_TOLERANCE
                progress "done\n\n"
                progress ">> You need #{dyno} dyno(s) to handle #{target} concurrent users!\n\n"
                break
            end
        end
        
        # Reset the dynos back to 1
        heroku.post_ps_scale app, 'web', 1
    end
    
    def progress text
        $stdout.print text
        $stdout.flush
    end
end

if ARGV.size < 3
    puts "Usage: blitzer user pass heroku-app [target]"
    puts "user   - Your heroku account name (email)"
    puts "pass   - Heroku API key (from the accounts page)"
    puts "app    - The name of your heroku app"
    puts "target - How many users do you want to get to? default = 1000"
    puts "path   - What URL path to be added to the request? eg. /path?var=value | default = ''"
    exit 1
end

opts = Hash.new
opts[:user]   = ARGV.shift
opts[:pass]   = ARGV.shift
opts[:app]    = ARGV.shift
opts[:target] = (ARGV.shift || 1000).to_i
opts[:path]   = (ARGV.shift || "")

puts "Blitzing http://#{opts[:app]}.heroku.com with a target of #{opts[:target]} users"
puts
blitzer = Blitzer.new opts
blitzer.run
