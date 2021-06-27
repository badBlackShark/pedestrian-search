class Result
  include JSON::Serializable

  getter job
  getter uri : URI
  getter date
  getter request_time_needed
  getter compute_time_needed
  getter date_source
  getter date_source_text : String

  def initialize(@job : Job, @date : Time, @request_time_needed : Float64, @compute_time_needed : Float64, @date_source : DateSource)
    @uri = job.uri
    @date_source_text = case @date_source
                        when DateSource::SEO
                          "ld+json node"
                        when DateSource::MetaTags
                          "Meta tags"
                        when DateSource::TimeNode
                          "Time node"
                        when DateSource::FullTextScan
                          "First date"
                        else
                          "Cache hit"
                        end
  end

  def to_json(builder : JSON::Builder)
    builder.object do
      builder.field("job", @job)
      builder.field("uri", @job.uri.to_s)
      builder.field("date", @date)
      builder.field("request_time_needed", @request_time_needed.to_s)
      builder.field("compute_time_needed", @compute_time_needed.to_s)
      builder.field("date_source", @date_source.to_s)
      builder.field("date_source_text", @date_source_text)
    end
  end
end
