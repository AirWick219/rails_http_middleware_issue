# README

### Description 
This is an example app to show ActiveSupport::Reloader middleware
does not block the request from going down the rack middlewares before it is done reloading. 

I have added a session middleware to the end of the rack. 

    use ActionDispatch::DebugLocks
    use Rack::Sendfile
    use ActionDispatch::Static
    use ActionDispatch::Executor
    use ActiveSupport::Cache::Strategy::LocalCache::Middleware
    use Rack::Runtime
    use Rack::MethodOverride
    use ActionDispatch::RequestId
    use ActionDispatch::RemoteIp
    use Sprockets::Rails::QuietAssets
    use Rails::Rack::Logger
    use ActionDispatch::ShowExceptions
    use WebConsole::Middleware
    use ActionDispatch::DebugExceptions
    use ActionDispatch::Reloader
    use ActionDispatch::Callbacks
    use ActiveRecord::Migration::CheckPending
    use ActionDispatch::Cookies
    use ActionDispatch::Session::CookieStore
    use ActionDispatch::Flash
    use Rack::Head
    use Rack::ConditionalGet
    use Rack::ETag
    use Middlewares::SessionMiddleware
    run RailsHttpMiddlewareIssue::Application.routes

This middleware makes a http request to a mock session processing engine(see background for our setup).

### Background
Our original app adds a session middleware for processing that calls a session service for non-development environment.
For local development, we use a mock session service engine that is mounted with the app. However, this is causing issue.
Whenever we make a code change, the reloader unloads all the classes but before it's done reloading, the request continue down the rake middlewares. The request then get to our session middleware and kick off a http request to the mock engine which resulted in a Net::ReadTimeout error, since the reload was not complete.

This is extreme annoying for local development since developer has to refresh twice to see a code change. 1. It's timeout due to the reloader. 2. page reload correctly since reloader was not triggered. However, This issue does not effect non-development since all classes are cached and reloaded is not triggered.  


### Version information 
* Rails 5.1
* Ruby version: 2.4.1

### Reproduction steps
1. run bundle install 
2. Run rail s in development mode
3. Hit localhost:3000/
4. Make a code change in home#index
5. Refresh the page 

### Expected behavior
1. Reload page with updated code without error

### Actual behavior
1. Error page Net::ReadTimeout

### Other information
I have tried a numbers of things like wraping the call with 
`permit_concurrent_loads`, `Rails.application.executor.wrap`, `Concurrent::Future.execute` do

But non of which works. 

I have also added the following log message to understand the sequence of events

application.rb

    ActiveSupport::Reloader.before_class_unload do
      puts 'Before class unload'
    end

    ActiveSupport::Reloader.after_class_unload do
      puts 'After class unload'
    end

    ActiveSupport::Reloader.to_run do
      puts 'Reloading'
    end
    ActiveSupport::Reloader.to_complete do
      puts 'DONE Reloading'
    end
   
app/middlewares/session_middleware.rb

    def call(env)
      puts 'Session processing'
      ...
    end  

log output

    Before class unload
    After class unload
    Reloading
    Session processing
    DONE Reloading
    
I can't seem to understand why. 

From the conversation with @matthewd from [here](https://stackoverflow.com/questions/51052070/rails-5-halt-a-custom-http-middleware-while-reloader-is-reloading). we noticed the following info from 
`http://localhost:3000/rails/locks` . It seems like Thread 0 (reloading) is block waiting for Thread 1 (http request) that's calling something that is not there. In which, the request should have been blocked from going down the rack middlewares before it is done reloading. 

    Thread 0 [0x3fd4ad8a831c sleep]  No lock (yielded share)
      Waiting in start_exclusive to "unload"
      may be pre-empted for: "load", "unload"
      blocked by: 1

    /Users/.rvm/rubies/ruby-2.4.1/lib/ruby/2.4.0/monitor.rb:111:in `sleep'
    /Users/.rvm/rubies/ruby-2.4.1/lib/ruby/2.4.0/monitor.rb:111:in `wait'
    /Users/.rvm/rubies/ruby-2.4.1/lib/ruby/2.4.0/monitor.rb:111:in `wait'
    /Users/.rvm/rubies/ruby-2.4.1/lib/ruby/2.4.0/monitor.rb:123:in `wait_while'
    /Users/.rvm/gems/ruby-2.4.1/gems/activesupport-5.1.6/lib/active_support/concurrency/share_lock.rb:219:in `wait_for'
    /Users/.rvm/gems/ruby-2.4.1/gems/activesupport-5.1.6/lib/active_support/concurrency/share_lock.rb:81:in `block (2 levels) in start_exclusive'
    /Users/.rvm/gems/ruby-2.4.1/gems/activesupport-5.1.6/lib/active_support/concurrency/share_lock.rb:185:in `yield_shares'
    /Users/.rvm/gems/ruby-2.4.1/gems/activesupport-5.1.6/lib/active_support/concurrency/share_lock.rb:80:in `block in start_exclusive'
    /Users/.rvm/rubies/ruby-2.4.1/lib/ruby/2.4.0/monitor.rb:214:in `mon_synchronize'
    /Users/.rvm/gems/ruby-2.4.1/gems/activesupport-5.1.6/lib/active_support/concurrency/share_lock.rb:75:in `start_exclusive'
    /Users/.rvm/gems/ruby-2.4.1/gems/activesupport-5.1.6/lib/active_support/dependencies/interlock.rb:23:in `start_unloading'
    /Users/.rvm/gems/ruby-2.4.1/gems/activesupport-5.1.6/lib/active_support/reloader.rb:99:in `require_unload_lock!'
    /Users/.rvm/gems/ruby-2.4.1/gems/activesupport-5.1.6/lib/active_support/reloader.rb:118:in `class_unload!'
    /Users/.rvm/gems/ruby-2.4.1/gems/railties-5.1.6/lib/rails/application/finisher.rb:175:in `block (2 levels) in <module:Finisher>'
    /Users/.rvm/gems/ruby-2.4.1/gems/activesupport-5.1.6/lib/active_support/callbacks.rb:413:in `instance_exec'
    /Users/.rvm/gems/ruby-2.4.1/gems/activesupport-5.1.6/lib/active_support/callbacks.rb:413:in `block in make_lambda'
    /Users/.rvm/gems/ruby-2.4.1/gems/activesupport-5.1.6/lib/active_support/callbacks.rb:197:in `block (2 levels) in halting'
    /Users/.rvm/gems/ruby-2.4.1/gems/activesupport-5.1.6/lib/active_support/callbacks.rb:601:in `block (2 levels) in default_terminator'
    /Users/.rvm/gems/ruby-2.4.1/gems/activesupport-5.1.6/lib/active_support/callbacks.rb:600:in `catch'
    /Users/.rvm/gems/ruby-2.4.1/gems/activesupport-5.1.6/lib/active_support/callbacks.rb:600:in `block in default_terminator'
    /Users/.rvm/gems/ruby-2.4.1/gems/activesupport-5.1.6/lib/active_support/callbacks.rb:198:in `block in halting'
    /Users/.rvm/gems/ruby-2.4.1/gems/activesupport-5.1.6/lib/active_support/callbacks.rb:507:in `block in invoke_before'
    /Users/.rvm/gems/ruby-2.4.1/gems/activesupport-5.1.6/lib/active_support/callbacks.rb:507:in `each'
    /Users/.rvm/gems/ruby-2.4.1/gems/activesupport-5.1.6/lib/active_support/callbacks.rb:507:in `invoke_before'
    /Users/.rvm/gems/ruby-2.4.1/gems/activesupport-5.1.6/lib/active_support/callbacks.rb:130:in `run_callbacks'
    /Users/.rvm/gems/ruby-2.4.1/gems/activesupport-5.1.6/lib/active_support/execution_wrapper.rb:108:in `run!'
    /Users/.rvm/gems/ruby-2.4.1/gems/activesupport-5.1.6/lib/active_support/reloader.rb:113:in `run!'
    /Users/.rvm/gems/ruby-2.4.1/gems/activesupport-5.1.6/lib/active_support/execution_wrapper.rb:70:in `block in run!'
    /Users/.rvm/gems/ruby-2.4.1/gems/activesupport-5.1.6/lib/active_support/execution_wrapper.rb:67:in `tap'
    /Users/.rvm/gems/ruby-2.4.1/gems/activesupport-5.1.6/lib/active_support/execution_wrapper.rb:67:in `run!'
    /Users/.rvm/gems/ruby-2.4.1/gems/activesupport-5.1.6/lib/active_support/reloader.rb:59:in `run!'
    /Users/.rvm/gems/ruby-2.4.1/gems/actionpack-5.1.6/lib/action_dispatch/middleware/executor.rb:10:in `call'
    /Users/.rvm/gems/ruby-2.4.1/gems/actionpack-5.1.6/lib/action_dispatch/middleware/debug_exceptions.rb:59:in `call'
    /Users/.rvm/gems/ruby-2.4.1/gems/web-console-3.6.2/lib/web_console/middleware.rb:135:in `call_app'
    /Users/.rvm/gems/ruby-2.4.1/gems/web-console-3.6.2/lib/web_console/middleware.rb:30:in `block in call'
    /Users/.rvm/gems/ruby-2.4.1/gems/web-console-3.6.2/lib/web_console/middleware.rb:20:in `catch'
    /Users/.rvm/gems/ruby-2.4.1/gems/web-console-3.6.2/lib/web_console/middleware.rb:20:in `call'
    /Users/.rvm/gems/ruby-2.4.1/gems/actionpack-5.1.6/lib/action_dispatch/middleware/show_exceptions.rb:31:in `call'
    /Users/.rvm/gems/ruby-2.4.1/gems/railties-5.1.6/lib/rails/rack/logger.rb:36:in `call_app'
    /Users/.rvm/gems/ruby-2.4.1/gems/railties-5.1.6/lib/rails/rack/logger.rb:24:in `block in call'
    /Users/.rvm/gems/ruby-2.4.1/gems/activesupport-5.1.6/lib/active_support/tagged_logging.rb:69:in `block in tagged'
    /Users/.rvm/gems/ruby-2.4.1/gems/activesupport-5.1.6/lib/active_support/tagged_logging.rb:26:in `tagged'
    /Users/.rvm/gems/ruby-2.4.1/gems/activesupport-5.1.6/lib/active_support/tagged_logging.rb:69:in `tagged'
    /Users/.rvm/gems/ruby-2.4.1/gems/railties-5.1.6/lib/rails/rack/logger.rb:24:in `call'
    /Users/.rvm/gems/ruby-2.4.1/gems/sprockets-rails-3.2.1/lib/sprockets/rails/quiet_assets.rb:13:in `call'
    /Users/.rvm/gems/ruby-2.4.1/gems/actionpack-5.1.6/lib/action_dispatch/middleware/remote_ip.rb:79:in `call'
    /Users/.rvm/gems/ruby-2.4.1/gems/actionpack-5.1.6/lib/action_dispatch/middleware/request_id.rb:25:in `call'
    /Users/.rvm/gems/ruby-2.4.1/gems/rack-2.0.5/lib/rack/method_override.rb:22:in `call'
    /Users/.rvm/gems/ruby-2.4.1/gems/rack-2.0.5/lib/rack/runtime.rb:22:in `call'
    /Users/.rvm/gems/ruby-2.4.1/gems/activesupport-5.1.6/lib/active_support/cache/strategy/local_cache_middleware.rb:27:in `call'
    /Users/.rvm/gems/ruby-2.4.1/gems/actionpack-5.1.6/lib/action_dispatch/middleware/executor.rb:12:in `call'
    /Users/.rvm/gems/ruby-2.4.1/gems/actionpack-5.1.6/lib/action_dispatch/middleware/static.rb:125:in `call'
    /Users/.rvm/gems/ruby-2.4.1/gems/rack-2.0.5/lib/rack/sendfile.rb:111:in `call'
    /Users/.rvm/gems/ruby-2.4.1/gems/actionpack-5.1.6/lib/action_dispatch/middleware/debug_locks.rb:39:in `call'
    /Users/.rvm/gems/ruby-2.4.1/gems/railties-5.1.6/lib/rails/engine.rb:522:in `call'
    /Users/.rvm/gems/ruby-2.4.1/gems/puma-3.11.4/lib/puma/configuration.rb:225:in `call'
    /Users/.rvm/gems/ruby-2.4.1/gems/puma-3.11.4/lib/puma/server.rb:632:in `handle_request'
    /Users/.rvm/gems/ruby-2.4.1/gems/puma-3.11.4/lib/puma/server.rb:446:in `process_client'
    /Users/.rvm/gems/ruby-2.4.1/gems/puma-3.11.4/lib/puma/server.rb:306:in `block in run'
    /Users/.rvm/gems/ruby-2.4.1/gems/puma-3.11.4/lib/puma/thread_pool.rb:120:in `block in spawn_thread'


    ---


    Thread 1 [0x3fd4ad8a8434 sleep]  Sharing
      blocking: 0

    /Users/.rvm/rubies/ruby-2.4.1/lib/ruby/2.4.0/net/protocol.rb:176:in `wait_readable'
    /Users/.rvm/rubies/ruby-2.4.1/lib/ruby/2.4.0/net/protocol.rb:176:in `rbuf_fill'
    /Users/.rvm/rubies/ruby-2.4.1/lib/ruby/2.4.0/net/protocol.rb:154:in `readuntil'
    /Users/.rvm/rubies/ruby-2.4.1/lib/ruby/2.4.0/net/protocol.rb:164:in `readline'
    /Users/.rvm/rubies/ruby-2.4.1/lib/ruby/2.4.0/net/http/response.rb:40:in `read_status_line'
    /Users/.rvm/rubies/ruby-2.4.1/lib/ruby/2.4.0/net/http/response.rb:29:in `read_new'
    /Users/.rvm/rubies/ruby-2.4.1/lib/ruby/2.4.0/net/http.rb:1446:in `block in transport_request'
    /Users/.rvm/rubies/ruby-2.4.1/lib/ruby/2.4.0/net/http.rb:1443:in `catch'
    /Users/.rvm/rubies/ruby-2.4.1/lib/ruby/2.4.0/net/http.rb:1443:in `transport_request'
    /Users/.rvm/rubies/ruby-2.4.1/lib/ruby/2.4.0/net/http.rb:1416:in `request'
    /Users/.rvm/rubies/ruby-2.4.1/lib/ruby/2.4.0/net/http.rb:1409:in `block in request'
    /Users/.rvm/rubies/ruby-2.4.1/lib/ruby/2.4.0/net/http.rb:877:in `start'
    /Users/.rvm/rubies/ruby-2.4.1/lib/ruby/2.4.0/net/http.rb:1407:in `request'
    /Users/git/rails_http_middleware_issue/app/middlewares/session_middleware.rb:28:in `call'
    /Users/.rvm/gems/ruby-2.4.1/gems/rack-2.0.5/lib/rack/etag.rb:25:in `call'
    /Users/.rvm/gems/ruby-2.4.1/gems/rack-2.0.5/lib/rack/conditional_get.rb:25:in `call'
    /Users/.rvm/gems/ruby-2.4.1/gems/rack-2.0.5/lib/rack/head.rb:12:in `call'
    /Users/.rvm/gems/ruby-2.4.1/gems/rack-2.0.5/lib/rack/session/abstract/id.rb:232:in `context'
    /Users/.rvm/gems/ruby-2.4.1/gems/rack-2.0.5/lib/rack/session/abstract/id.rb:226:in `call'
    /Users/.rvm/gems/ruby-2.4.1/gems/actionpack-5.1.6/lib/action_dispatch/middleware/cookies.rb:613:in `call'
    /Users/.rvm/gems/ruby-2.4.1/gems/activerecord-5.1.6/lib/active_record/migration.rb:556:in `call'
    /Users/.rvm/gems/ruby-2.4.1/gems/actionpack-5.1.6/lib/action_dispatch/middleware/callbacks.rb:26:in `block in call'
    /Users/.rvm/gems/ruby-2.4.1/gems/activesupport-5.1.6/lib/active_support/callbacks.rb:97:in `run_callbacks'
    /Users/.rvm/gems/ruby-2.4.1/gems/actionpack-5.1.6/lib/action_dispatch/middleware/callbacks.rb:24:in `call'
    /Users/.rvm/gems/ruby-2.4.1/gems/actionpack-5.1.6/lib/action_dispatch/middleware/executor.rb:12:in `call'
    /Users/.rvm/gems/ruby-2.4.1/gems/actionpack-5.1.6/lib/action_dispatch/middleware/debug_exceptions.rb:59:in `call'
    /Users/.rvm/gems/ruby-2.4.1/gems/web-console-3.6.2/lib/web_console/middleware.rb:135:in `call_app'
    /Users/.rvm/gems/ruby-2.4.1/gems/web-console-3.6.2/lib/web_console/middleware.rb:30:in `block in call'
    /Users/.rvm/gems/ruby-2.4.1/gems/web-console-3.6.2/lib/web_console/middleware.rb:20:in `catch'
    /Users/.rvm/gems/ruby-2.4.1/gems/web-console-3.6.2/lib/web_console/middleware.rb:20:in `call'
    /Users/.rvm/gems/ruby-2.4.1/gems/actionpack-5.1.6/lib/action_dispatch/middleware/show_exceptions.rb:31:in `call'
    /Users/.rvm/gems/ruby-2.4.1/gems/railties-5.1.6/lib/rails/rack/logger.rb:36:in `call_app'
    /Users/.rvm/gems/ruby-2.4.1/gems/railties-5.1.6/lib/rails/rack/logger.rb:24:in `block in call'
    /Users/.rvm/gems/ruby-2.4.1/gems/activesupport-5.1.6/lib/active_support/tagged_logging.rb:69:in `block in tagged'
    /Users/.rvm/gems/ruby-2.4.1/gems/activesupport-5.1.6/lib/active_support/tagged_logging.rb:26:in `tagged'
    /Users/.rvm/gems/ruby-2.4.1/gems/activesupport-5.1.6/lib/active_support/tagged_logging.rb:69:in `tagged'
    /Users/.rvm/gems/ruby-2.4.1/gems/railties-5.1.6/lib/rails/rack/logger.rb:24:in `call'
    /Users/.rvm/gems/ruby-2.4.1/gems/sprockets-rails-3.2.1/lib/sprockets/rails/quiet_assets.rb:13:in `call'
    /Users/.rvm/gems/ruby-2.4.1/gems/actionpack-5.1.6/lib/action_dispatch/middleware/remote_ip.rb:79:in `call'
    /Users/.rvm/gems/ruby-2.4.1/gems/actionpack-5.1.6/lib/action_dispatch/middleware/request_id.rb:25:in `call'
    /Users/.rvm/gems/ruby-2.4.1/gems/rack-2.0.5/lib/rack/method_override.rb:22:in `call'
    /Users/.rvm/gems/ruby-2.4.1/gems/rack-2.0.5/lib/rack/runtime.rb:22:in `call'
    /Users/.rvm/gems/ruby-2.4.1/gems/activesupport-5.1.6/lib/active_support/cache/strategy/local_cache_middleware.rb:27:in `call'
    /Users/.rvm/gems/ruby-2.4.1/gems/actionpack-5.1.6/lib/action_dispatch/middleware/executor.rb:12:in `call'
    /Users/.rvm/gems/ruby-2.4.1/gems/actionpack-5.1.6/lib/action_dispatch/middleware/static.rb:125:in `call'
    /Users/.rvm/gems/ruby-2.4.1/gems/rack-2.0.5/lib/rack/sendfile.rb:111:in `call'
    /Users/.rvm/gems/ruby-2.4.1/gems/actionpack-5.1.6/lib/action_dispatch/middleware/debug_locks.rb:39:in `call'
    /Users/.rvm/gems/ruby-2.4.1/gems/railties-5.1.6/lib/rails/engine.rb:522:in `call'
    /Users/.rvm/gems/ruby-2.4.1/gems/puma-3.11.4/lib/puma/configuration.rb:225:in `call'
    /Users/.rvm/gems/ruby-2.4.1/gems/puma-3.11.4/lib/puma/server.rb:632:in `handle_request'
    /Users/.rvm/gems/ruby-2.4.1/gems/puma-3.11.4/lib/puma/server.rb:446:in `process_client'
    /Users/.rvm/gems/ruby-2.4.1/gems/puma-3.11.4/lib/puma/server.rb:306:in `block in run'
    /Users/.rvm/gems/ruby-2.4.1/gems/puma-3.11.4/lib/puma/thread_pool.rb:120:in `block in spawn_thread'    

 


 