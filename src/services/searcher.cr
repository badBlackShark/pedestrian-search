require "lexbor"

# Parts of the content extraction are inspired by https://github.com/mozilla/readability
class Searcher
  IGNORE_HINTS = {"nav", "link", "noprint", "title", "path", "menu", "editorial"}
  # As per https://meta.wikimedia.org/wiki/Stop_word_list/google_stop_word_list
  STOPWORDS = {"a", "about", "above", "after", "again", "against", "all", "am", "an", "and", "any",
               "are", "aren't", "as", "at", "be", "because", "been", "before", "being", "below", "between",
               "both", "but", "by", "can't", "cannot", "could", "couldn't", "did", "didn't", "do", "does",
               "doesn't", "doing", "don't", "down", "during", "each", "few", "for", "from", "further",
               "had", "hadn't", "has", "hasn't", "have", "haven't", "having", "he", "he'd", "he'll",
               "he's", "her", "here", "here's", "hers", "herself", "him", "himself", "his", "how", "how's",
               "i", "i'd", "i'll", "i'm", "i've", "if", "in", "into", "is", "isn't", "it", "it's", "its",
               "itself", "let's", "me", "more", "most", "mustn't", "my", "myself", "no", "nor", "not",
               "of", "off", "on", "once", "only", "or", "other", "ought", "our", "ours", "ourselves",
               "out", "over", "own", "same", "shan't", "she", "she'd", "she'll", "she's", "should",
               "shouldn't", "so", "some", "such", "than", "that", "that's", "the", "their", "theirs",
               "them", "themselves", "then", "there", "there's", "these", "they", "they'd", "they'll",
               "they're", "they've", "this", "those", "through", "to", "too", "under", "until", "up",
               "very", "was", "wasn't", "we", "we'd", "we'll", "we're", "we've", "were", "weren't",
               "what", "what's", "when", "when's", "where", "where's", "which", "while", "who", "who's",
               "whom", "why", "why's", "with", "won't", "would", "wouldn't", "you", "you'd", "you'll",
               "you're", "you've", "your", "yours", "yourself", "yourselves"}

  MAX_SNIPPET_WORDS = 30

  def initialize(@strategy : ExtractionStrategy)
  end

  def search(job : Job, search_string : String) : SearchResult | ErrorResult
    url_str = job.uri.to_s

    Log.context.set(url: url_str)
    Log.info { "Starting ranking job" }

    request_time_start = Time.monotonic

    content = Requester.get_html(job)
    if content.is_a?(ErrorResult)
      return content
    end

    request_time = Time.monotonic - request_time_start

    compute_start = Time.monotonic
    parser = Lexbor::Parser.new(content)
    terms = search_string.downcase.split(" ").reject { |term| STOPWORDS.includes?(term) }
    content = extract_content(parser)
    description = extract_description(parser)
    title = extract_title(parser)

    score, term_scores = calculate_scores(job.uri, content, terms, title, description)

    if score >= 31
      Log.debug { "Score threshold passed with #{score} points" }
      best_term = select_best_term(term_scores)
      snippet = extract_snippet(parser, content, best_term, description) || title
      snippet = highlight_search_terms(snippet, terms) if snippet

      result = DateExtractor.new(@strategy).extract(job)
      date = if result.is_a?(Result)
        result.date
      else
        nil
      end

      return SearchResult.new(job, date, title, snippet, score)
    end

    return ErrorResult.new(job.uri.to_s, ErrorCode::ScoreTooLow, "Website didn't pass the score threshold.", 0_f64, 0_f64)
  end

  def rank_results(results : Array(SearchResult))
    results_without_date, results_with_date = results.partition { |result| result.date.nil? }

    results_with_date.sort_by! { |result| result.date.not_nil! }.reverse!
    oldest_result_date = results_with_date[-1].date.not_nil!

    results_with_date.each do |result|
      distance = (result.date.not_nil! - oldest_result_date).total_days.round_away.to_i
      result.score += distance
    end

    ranked_results = (results_with_date + results_without_date).sort_by { |result| result.score }.reverse

    return ranked_results[0..9]
  end

  private def calculate_scores(uri : URI, content : String, terms : Array(String), title : String?, description : String?)
    score = 0
    term_scores = terms.to_h { |term| {term, 0} }

    content = content.downcase

    terms.each do |term|
      content_hits = content.scan(term).size
      score += content_hits
      term_scores[term] += content_hits

      url_hits = uri.to_s.downcase.scan(term).size
      score += url_hits * 30
      term_scores[term] += url_hits * 30

      if title
        title_hits = title.downcase.scan(term).size
        score += title_hits * 30
        term_scores[term] += title_hits * 30
      end

      if description
        desc_hits = description.downcase.scan(term).size
        score += desc_hits * 15
        term_scores[term] += desc_hits * 15
      end
    end

    # Give a big bonus if a certain site is searched for and another search term is also present.
    hostname = uri.hostname
    if(hostname && (host = terms.find { |term| hostname.includes?(term) }))
      score += 100 if term_scores.any? { |t, s| t != host && s > 0 }
    end

    # Also give a big bonus if all relevant search terms were found
    score += 100 if term_scores.values.all? { |s| s > 0 }

    return score, term_scores
  end

  private def extract_title(parser : Lexbor::Parser) : String?
    candidates = Array(String).new
    parser.nodes(:meta).each do |node|
      if node.attributes.values.any? { |value| value.downcase.includes?("title") }
        candidates << node.attributes["content"]
      end
    end

    # Turns out of all the candidates the one you actually want is generally the last one.
    return candidates[-1]?
  end

  private def extract_snippet(parser : Lexbor::Parser, content : String, term : String, description : String?) : String?
    return description if description && description.downcase.includes?(term)

    word_count = 0

    snippet = nil

    if(index = content.downcase.index(term))
      sentence_start = content.rindex(/(?<!Mr|Mrs|Ms|\d)\. [[:upper:]]/, index)
      sentence_start = sentence_start.nil? ? 0 : sentence_start + 2
      snippet = content[sentence_start..-1].split(" ")[0...MAX_SNIPPET_WORDS].join(" ")
    end

    if snippet
      snippet += "..." unless snippet.ends_with?(".")
      return snippet
    else
      return nil
    end
  end

  private def extract_description(parser : Lexbor::Parser)
    candidates = Array(String).new
    parser.nodes(:meta).each do |node|
      if node.attributes.values.any? { |value| value.downcase.includes?("description") }
        candidates << node.attributes["content"]
      end
    end

    # Return the longest description we can find.
    return candidates.sort_by { |c| (c.size) }[-1]?
  end

  private def select_best_term(term_scores : Hash(String, Int32))
    term_scores.key_for(term_scores.values.sort.reverse.first)
  end

  private def highlight_search_terms(snippet : String, terms : Array(String))
    terms.each do |term|
      snippet = snippet.gsub(Regex.new("(#{term})", Regex::Options::IGNORE_CASE)) { |match| "<b>#{match}</b>" }
    end

    return snippet
  end

  private def extract_content(parser : Lexbor::Parser) : String
    # The exclusion rules for these nodes are set very aggressively compared to Mozilla's
    # Readability as we're not interested in anything like titles or navigation here. This might
    # lead to us dropping a little bit of content accidentally, but so far it has worked out.
    parser.nodes(:div).each do |node|
      next if node.attributes.values.any? { |v| IGNORE_HINTS.any? { |hint| v.downcase.includes?(hint) } }
      next if node.children.any? { |child|  child.attributes.values.any? { |v| IGNORE_HINTS.any? { |hint| v.downcase.includes?(hint) } } }

      p_node = nil
      node.children.each do |child_node|
        if is_phrasing_content?(child_node)
          if !is_whitespace?(child_node)
            p_node = parser.create_node(:p)
            child_node.insert_before(p_node)
            child_node.remove!
            p_node.append_child(child_node)
          end
        end
      end
    end

    content = String.build do |str|
      parser.nodes(:p).each do |node|
        text = node.inner_text
        unless text.empty? || text == "Advertisement"
          str << node.inner_text.strip
          str << " "
        end
      end
    end

    return content
  end

  private def is_phrasing_content?(node : Lexbor::Node)
    return node.is_text? ||
           ((node.tag_sym == :a || node.tag_sym == :del || node.tag_sym == :ins) &&
            node.children.all? { |child| is_phrasing_content?(child) })
  end

  private def is_whitespace?(node : Lexbor::Node)
    return (node.is_text? && node.tag_text.strip.empty?) ||
           (node.tag_sym == :br)
  end
end
