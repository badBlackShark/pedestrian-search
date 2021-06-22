class Error
  getter code
  getter message
  getter created_at

  def initialize(@code : ErrorCode, @message : String, @created_at : Time)
  end

  def to_json(builder : JSON::Builder)
    builder.object do
      builder.field("code", @code.to_i)
      builder.field("message", @message)
    end
  end
end
