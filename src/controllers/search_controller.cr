class SearchController < ApplicationController
  def search
    unless request.headers["Content-Type"].try(&.==("application/json"))
      context.response.status = HTTP::Status::BAD_REQUEST
      context.response.content_type = "application/json"
      data = Error.new(ErrorCode::InvalidBody, "Content-Type must be application/json", Time.utc)
      return data
    end

    start = Time.monotonic

    json = JSON.parse(request.body.not_nil!)
    urls = json["urls"].as_a.map(&.as_s)
    search_term = json["search_term"].as_s

    results = Array(SearchResult).new
    job_channel = Channel({Job, SearchResult | ErrorResult}).new
    searcher = Searcher.new(ExtractionStrategy::LexborCombo)
    valid_jobs = 0

    urls.each do |url_string|
      job = Job.from_url(url_string)
      case job
      when Job
        valid_jobs += 1
        spawn { job_channel.send({job, searcher.search(job, search_term)}) }
      when Error
        # Do nothing
      end
    end

    Log.debug { "Valid jobs: #{valid_jobs}" }

    results = Array(SearchResult).new
    valid_jobs.times do |i|
      job, result = job_channel.receive
      results << result if result.is_a?(SearchResult)
    end

    results = searcher.rank_results(results)

    # puts results.map { |r| "#{r.uri.to_s}: #{r.score}\n#{r.title}\n#{r.snippet}\n\n" }.join("\n")

    finish = Time.monotonic - start

    response.status = HTTP::Status::OK
    response.content_type = "application/json"

    return %({"results": #{results.to_json}, "server_time": "#{finish.total_milliseconds}"})
  end
end
