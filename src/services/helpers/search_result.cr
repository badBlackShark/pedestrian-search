class SearchResult
  getter job
  getter uri : URI
  getter date
  getter title
  getter snippet
  property score

  def initialize(@job : Job, @date : Time?, @title : String?, @snippet : String?, @score : Int32)
    @uri = job.uri
  end

  def to_json(builder : JSON::Builder)
    builder.object do
      builder.field("job", @job)
      builder.field("uri", @job.uri.to_s)
      builder.field("date", @date)
      builder.field("title", @title.to_s)
      builder.field("snippet", @snippet.to_s)
      builder.field("score", @score.to_s)
    end
  end
end
