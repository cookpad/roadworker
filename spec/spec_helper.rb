TEST_ELB = ENV['TEST_ELB']

AWS.config({
  :access_key_id => (ENV['TEST_AWS_ACCESS_KEY_ID'] || 'scott'),
  :secret_access_key => (ENV['TEST_AWS_SECRET_ACCESS_KEY'] || 'tiger'),
})

def routefile(options = {})
  updated = false
  tempfile = `mktemp /tmp/#{File.basename(__FILE__)}.XXXXXX`.strip

  begin
    open(tempfile, 'wb') {|f| f.puts(yield) }
    options = {:logger => Logger.new('/dev/null')}.merge(options)
    client = Roadworker::Client.new(options)
    updated = client.apply(tempfile)
    sleep ENV['TEST_DELAY'].to_f
  ensure
    FileUtils.rm_f(tempfile)
  end

  return updated
end

def rrs_list(rrs)
  rrs.map {|i| i[:value] }
end

def fetch_health_checks(route53)
  check_list = {}

  is_truncated = true
  next_marker = nil

  while is_truncated
    opts = next_marker ? {:marker => next_marker} : {}
    response = @route53.client.list_health_checks(opts)

    response[:health_checks].each do |check|
      check_list[check[:id]] = check[:health_check_config]
    end

    is_truncated = response[:is_truncated]
    next_marker = response[:next_marker]
  end

  return check_list
end
