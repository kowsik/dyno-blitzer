## How many dynos do I need on Heroku?
We set out to answer this problem by combining the ruby gem from http://blitz.io
and the `Heroku::Client` which allows you to change the number of dynos for
your app instantly.

The syntax is pretty simple

    $ ./blitzer.rb
    Usage: blitzer user pass heroku-app [target]
    user   - Your heroku account name (email)
    pass   - Heroku API key (from the accounts page)
    app    - The name of your Heroku app
    target - How many users do you want to get to? default = 1000
    
The *app* is just the name of your Heroku app which resolves to http://<app>.heroku.com.
You can set the target concurrency to a specific value, with the default being
1,000 users. When you run this, we keep adding dynos (up to 32 dynos) until
the percentage of errors during the load test is greater than 2%.

The output from running the blitzer looks something like this:

    Blitzing http://dyno-capacity.heroku.com with a target of 1000 users
    
    starting 1 dyno(s) .done
      rushing ..322 hits | 0 errors | 1 timeouts @ 167 users
    starting 2 dyno(s) ....done
      rushing .......6259 hits | 1 errors | 0 timeouts @ 670 users
    starting 4 dyno(s) ...done
      rushing .......4784 hits | 1 errors | 0 timeouts @ 591 users
    starting 8 dyno(s) .......done
      rushing .......4781 hits | 1 errors | 0 timeouts @ 589 users
    starting 16 dyno(s) ...done
      rushing .............done
    
    >> You need 16 dyno(s) to handle 1,000 users
    
Integrating load and performance testing into your continuous integration
process doesn't get simpler than this!