struct Job
  getter uri
  getter created_at
  getter config

  def initialize(@uri : URI, @created_at : Time, @config : Config = Config.new)
  end

  def self.from_url(url : String) : Job | Error
    uri = URI.parse(url)
    unless uri.scheme.in?("http", "https")
      return Error.new(ErrorCode::UnsupportedUriScheme, "URI scheme not supported: #{uri.scheme || "(none)"}.", Time.utc)
    end

    Job.new(uri, Time.utc)
  end

  def to_json(builder : JSON::Builder)
    builder.object do
      builder.field("uri", @uri.to_s)
      builder.field("created_at", @created_at)
      builder.field("config", @config)
    end
  end
end
