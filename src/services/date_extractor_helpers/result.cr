class Result
  include JSON::Serializable

  getter job
  getter uri : URI
  getter date
  getter request_time_needed
  getter compute_time_needed

  def initialize(@job : Job, @date : Time, @request_time_needed : Float64, @compute_time_needed : Float64, @cache_hit : Bool = false)
    @uri = job.uri
  end

  def to_json(builder : JSON::Builder)
    builder.object do
      builder.field("job", @job)
      builder.field("uri", @job.uri.to_s)
      builder.field("date", @date)
      builder.field("request_time_needed", @request_time_needed.to_s)
      builder.field("compute_time_needed", @compute_time_needed.to_s)
      builder.field("cache_hit", @cache_hit.to_s)
    end
  end
end
