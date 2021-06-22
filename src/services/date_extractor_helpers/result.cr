class Result
  include JSON::Serializable

  getter job
  getter uri : URI
  getter date
  getter time_needed

  def initialize(@job : Job, @date : Time, @time_needed : Float64)
    @uri = job.uri
  end

  def to_json(builder : JSON::Builder)
    builder.object do
      builder.field("job", @job)
      builder.field("uri", @job.uri.to_s)
      builder.field("date", @date)
      builder.field("time_needed", @time_needed.to_s)
    end
  end
end
