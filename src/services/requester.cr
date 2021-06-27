module Requester
  extend self

  def self.get_html(job : Job) : String | ErrorResult
    if(content = WebsiteCache.retrieve("#{job.uri.to_s}-content"))
      return content
    end

    html = ""

    uri = job.uri
    redirects = 0
    retries = 0
    success = false
    backoff_time = job.config.backoff_time

    max_redirects = job.config.max_redirects
    max_retries = job.config.max_retries

    headers = HTTP::Headers.new
    headers["User-Agent"] = job.config.user_agent

    request_time = nil

    while(!success && redirects <= max_redirects && retries <= max_retries)
      HTTP::Client.new(uri) do |client|
        begin
          Log.context.set(url: uri.to_s, redirect: redirects, retry: retries)
          client.compress = true
          client.get(uri.to_s, headers) do |response|
            Log.info { "#{response.status_code} #{response.status.inspect}" }
            case response.status
            when .success?
              success = true
              html = response.body_io.gets_to_end

              break
            when .redirection?
              location = response.headers["Location"]
              uri = URI.parse(location)
              client.close
              redirects += 1
              if redirects > max_redirects
                return ErrorResult.new(job.uri.to_s, ErrorCode::RedirectDepthExceeded, "Maximum redirect depth exceeded.", (Time.utc - job.created_at).total_milliseconds, 0_f64)
              end
            when .server_error?
              retries += 1
              client.close
              if retries > max_retries
                return ErrorResult.new(job.uri.to_s, ErrorCode::MaxRetriesExceeded, "Maximum amount of retries exceeded.", (Time.utc - job.created_at).total_milliseconds, 0_f64)
              end
              sleep(backoff_time)
              backoff_time *= 2
            else
              Log.error { "Unhandled HTTP status: #{response.status}" }
              client.close
              return ErrorResult.new(job.uri.to_s, ErrorCode::UnhandledHTTPStatus, "HTTP status #{response.status} wasn't handled.", (Time.utc - job.created_at).total_milliseconds, 0_f64)
            end
          end
        ensure
          client.close
        end
      end
    end

    WebsiteCache.store("#{job.uri.to_s}-content", html)
    return html
  end
end
