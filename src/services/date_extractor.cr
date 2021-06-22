require "json"
require "lexbor"

class DateExtractor
  SEARCH_TERMS_PUBLISHED = {"time", "date", "data", "published", "created"}
  SEARCH_TERMS_MODIFIED  = {"time", "date", "data", "updated", "modified", "lastmod"}

  def initialize(@strategy : ExtractionStrategy)
  end

  def extract(job : Job) : Result | ErrorResult
    Log.context.set(url: job.uri.to_s)
    Log.info { "Starting job" }

    result = nil
    uri = job.uri
    redirects = 0
    retries = 0
    success = false
    backoff_time = job.config.backoff_time

    headers = HTTP::Headers.new
    headers["User-Agent"] = job.config.user_agent

    while(!success && redirects < job.config.max_redirects && retries < job.config.max_retries)
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
              if(date = extract_date(Lexbor::Parser.new(html)))
                result = Result.new(job, date, (Time.utc - job.created_at).total_milliseconds)
              else
                Log.error { "Couldn't extract date." }
              end
              break
            when .redirection?
              location = response.headers["Location"]
              uri = URI.parse(location)
              client.close
              redirects += 1
            when .server_error?
              retries += 1
              sleep(backoff_time)
              backoff_time *= 2
            else
              Log.error { "Unhandled HTTP status: #{response.status}" }
            end
          end
        ensure
          client.close
        end
      end
    end

    return result || ErrorResult.new(uri.to_s, ErrorCode::StrategyFailure, "Extraction strategy failed.", (Time.utc - job.created_at).total_milliseconds)

  rescue exception
    Log.error { "Internal error during date extraction" }
    Log.debug { exception.inspect_with_backtrace }
    ErrorResult.new(uri.to_s, ErrorCode::InternalFailure, exception.inspect, (Time.utc - job.created_at).total_milliseconds)
  end

  private def extract_date(parser : Lexbor::Parser) : Time?
    # If the combo strategy is used this will be determined for the different angles individually.
    find_modified = case @strategy
      when ExtractionStrategy::LexborPublished
        false
      when ExtractionStrategy::LexborModified
        true
    end

    # A script node of type `application/ld+json` is used for SEO and gives us a quick angle to
    # find what we're looking for.
    parser.nodes(:script).each do |node|
      if node.attribute_by("type").try(&.==("application/ld+json"))
        json = JSON.parse(node.inner_text)

        # When using the LexborCombo strategy we want to use the date the link was last modified for everything
        # that isn't an artilcle. For news articles the published date is more interesting.

        if @strategy == ExtractionStrategy::LexborCombo
          if json["@type"]? && json["@type"].as_s.downcase.includes?("news")
            find_modified = false
          else
            find_modified = true
          end
        end

        if find_modified
          date_str = json["dateModified"]?.try(&.as_s)

          # Sometimes the attribute we're looking for is on the top level, sometimes it is
          # nested somewhere within the structure. If it's not top level we simply scan the raw String.
          unless date_str
            raw = node.inner_text
            i = raw.index(%("dateModified"))
            date_str = raw[i+16..i+40] if i
          end
        else
          date_str = json["datePublished"]?.try(&.as_s)

          unless date_str
            raw = node.inner_text
            i = raw.index(%("datePublished"))
            date_str = raw[i+17..i+41] if i
          end
        end


        if(date_str && (date = parse_date(date_str)))
          return date
        end
      end
    end

    meta_date = nil

    # Pre-compute if we're going to be looking for a modified or a published date for the rest of
    # the strategies and which hints we'll be using.
    if @strategy == ExtractionStrategy::LexborCombo
      if(node = parser.nodes(:meta).find { |n| n.attributes["property"]? == "og:type" && n.attributes["content"]? == "article" })
        find_modified = false
      else
        find_modified = true
      end
    end
    hints = find_modified ? SEARCH_TERMS_MODIFIED : SEARCH_TERMS_PUBLISHED

    parser.nodes(:meta).each do |node|

      attributes = node.attributes

      candidates = [
        attributes["property"]?,
        attributes["name"]?,
        attributes["itemprop"]?,
        attributes["http-equiv"]?
      ]

      match = candidates.compact.any? do |candidate|
        candidate = candidate.downcase
        hints.find { |hint| candidate.includes?(hint) }
      end

      # Take the most recent one of the meta dates if we're looking for the last modified date.
      # Take the oldest one if we're looking for the publish date.
      if match && (date_str = attributes["content"]?)
        if(date = parse_date(date_str))
          if meta_date
            if find_modified
              meta_date = date if date > meta_date
            else
              meta_date = date if date < meta_date
            end
          else
            meta_date = date
          end
        end
      end
    end

    return meta_date if meta_date

    parser.nodes(:time).each do |node|
      if(candidate = node.attribute_by("class"))
        candidate = candidate.downcase
        if hints.find { |hint| candidate.includes?(hint) }
          date_str = node.attribute_by("datetime")
          if(date_str && (date = parse_date(date_str)))
            return date
          end
        end
      end
    end

    return nil
  end

  DATE_FORMATS = {
    # Standard date & time formats
    Time::Format::ISO_8601_DATE_TIME,
    Time::Format::ISO_8601_DATE,
    Time::Format::HTTP_DATE,

    # Other common date/time formats
    Time::Format.new("%Y-%m-%d", Time::Location::UTC),
    Time::Format.new("%Y/%m/%d", Time::Location::UTC),
    Time::Format.new("%d %B %Y", Time::Location::UTC),
    Time::Format.new("%m/%d/%Y %I:%M%P", Time::Location::UTC),
    Time::Format.new("%b %e, %Y", Time::Location::UTC),
    Time::Format.new("%A, %B %d, %Y, %l:%M %P", Time::Location::UTC),
    Time::Format.new("%I:%M:%S %P %A, %B %d, %Y", Time::Location::UTC),
  }

  private def parse_date(raw : String)
    DATE_FORMATS.each do |format|
      return format.parse(raw.strip)
    rescue ex : Time::Format::Error | ArgumentError
      # Try next format
    end
  end
end
