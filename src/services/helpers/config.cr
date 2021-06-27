class Config
  getter strategy
  getter max_redirects
  getter max_retries
  getter user_agent
  getter backoff_time

  def initialize(@strategy : ExtractionStrategy,
                 @max_redirects : Int32,
                 @max_retries : Int32,
                 @user_agent : String,
                 @backoff_time : Time::Span)
  end

  def initialize
    @strategy = ExtractionStrategy::LexborCombo
    @max_redirects = 5
    @max_retries = 5
    @user_agent = UserAgent::FIREFOX_MAC
    @backoff_time = 1.second
  end

  def to_json(builder : JSON::Builder)
    builder.object do
      builder.field("strategy", @strategy)
      builder.field("max_redirects", @max_redirects)
      builder.field("max_retries", @max_retries)
      builder.field("user_agent", @user_agent)
      builder.field("backoff_time", @backoff_time.to_s)
    end
  end
end
