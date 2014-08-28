require "support/test_app"

module ApiHelper
  def app_id
    TestApp.instance.app_id
  end

  def key_id
    TestApp.instance.key_id
  end

  def api_key
    TestApp.instance.api_key
  end

  def environment
    TestApp.instance.environment
  end
end

RSpec.configure do |config|
  config.include ApiHelper

  config.before(:suite) do
    TestApp.instance
  end

  config.after(:suite) do
    TestApp.instance.delete
  end
end
