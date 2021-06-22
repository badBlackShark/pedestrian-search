class ErrorResult
  include JSON::Serializable

  getter uri
  getter code
  getter message
  getter time_needed

  def initialize(@uri : String, @code : ErrorCode, @message : String, @time_needed : Float64)
  end

  def to_json(builder : JSON::Builder)
    builder.object do
      builder.field("uri", @uri)
      builder.field("code", @code.to_i)
      builder.field("message", @message)
      builder.field("time_needed", @time_needed.to_s)
    end
  end
end
