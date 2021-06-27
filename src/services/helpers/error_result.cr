class ErrorResult
  include JSON::Serializable

  getter uri
  getter code
  getter message
  getter request_time_needed
  getter compute_time_needed
  getter date_source_text

  def initialize(@uri : String, @code : ErrorCode, @message : String, @request_time_needed : Float64, @compute_time_needed : Float64)
    @date_source_text = "None"
  end

  def to_json(builder : JSON::Builder)
    builder.object do
      builder.field("uri", @uri)
      builder.field("code", @code.to_i)
      builder.field("message", @message)
      builder.field("request_time_needed", @request_time_needed.to_s)
      builder.field("compute_time_needed", @compute_time_needed.to_s)
      builder.field("date_source_text", @date_source_text)
    end
  end
end
