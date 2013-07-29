def routefile(options = {})
  updated = false
  tempfile = `mktemp /tmp/#{File.basename(__FILE__)}.XXXXXX`.strip

  begin
    open(tempfile, 'wb') {|f| f.puts(yield) }
    options = {:logger => Logger.new('/dev/null')}.merge(options)
    client = Roadworker::Client.new(options)
    updated = client.apply(tempfile)
  ensure
    FileUtils.rm_f(tempfile)
  end

  return updated
end

def rrs_list(rrs)
  rrs.map {|i| i[:value] }
end
