CodeSunset.configure do |config|
  config.dashboard_authorizer = ->(_controller) { true }
end
