class ExtractController < ApplicationController
  def extract
    unless request.headers["Content-Type"].try(&.==("application/json"))
      context.response.status = HTTP::Status::BAD_REQUEST
      context.response.content_type = "application/json"
      data = Error.new(ErrorCode::InvalidBody, "Content-Type must be application/json", Time.utc)
      return data
    end
    start = Time.monotonic

    urls = Urls.from_json(request.body.not_nil!).urls.reject { |url| url.empty? }

    results = Array(Result | ErrorResult).new(urls.size)
    job_channel = Channel({Job, Result | ErrorResult}).new
    extractor = DateExtractor.new(ExtractionStrategy::LexborCombo)
    valid_jobs = 0

    urls.each do |url_string|
      job = Job.from_url(url_string)
      case job
      when Job
        valid_jobs += 1
        spawn { job_channel.send({job, extractor.extract(job)}) }
      when Error
        results << ErrorResult.new(url_string, job.code, job.message, 0_f64, 0_f64)
      end
    end

    Log.debug { "Valid jobs: #{valid_jobs}" }

    valid_jobs.times do |i|
      job, result = job_channel.receive
      FrontendSocket.broadcast("message", "frontend_stream:1", "message_new", {"message" => %({"type": "result", "result": #{result.to_json}})})
    end

    finish = Time.monotonic - start

    FrontendSocket.broadcast("message", "frontend_stream:1", "message_new", {"message" => %({"type": "time", "message": "Total server time needed: #{finish.total_milliseconds}ms"})})

    response.status = HTTP::Status::OK
  end
end
