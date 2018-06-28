require 'session_middleware'

RailsHttpMiddlewareIssue::Application.config.middleware.use Middlewares::SessionMiddleware
