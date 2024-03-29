# Pedestrian Search

[![Amber Framework](https://img.shields.io/badge/using-amber_framework-orange.svg)](https://amberframework.org)

Pedestrian Search is, essentially, a very pedestrian variation of a search engine using a user- but pre-defined set of links. Its two functions are a date extraction algorithm to find out when an article has been published (or last modified, more on that below), and a basic search algorithm. This project uses the [Amber](https://amberframework.org) web framework with a Crystal backend and a frontend in JavaScript. The focus is on the backend, so not too much work was put into making things look good at the front beyond what Amber ships with plus some very minor stylings for better readability in some places. For faster results with continuous use a redis cache is employed, caching both the full content of the sites requested as well the extracted article date, if that algorithm has already run. For easy comparisons between performance with cached vs un-cached sites the site includes a "Clear Cache" button which fully clears the redis database. This obviously clears the cache for every client and something like it would obviously not be included in an actually production-ready version of something like this. Also not implemented is that the cache expires at some point, which is also something that should probably happen for a production-ready build.

~~A demo of this project in action can be enjoyed at http://demo.pedestrian-programming.com
Do note that at this time the demo is not being served via https.~~ Unfortunately, the live version of this application is currently broken. I will try to get it back online as fast as possible.

### Date Extration

The date extraction algorithm can work using three different strategies, which all employ the [Lexbor](https://github.com/kostya/lexbor) backend. Using the `LexborPublished` strategy always yields the actual publication date, while `LexborModified` finds out when the article was last edited. The most interesting strategy however is `LexborCombo`, which attempts to find out if the website linked contains a news article or not. If the algorithm determines that an article is indeed news (more on how that works later) then it will find the original publish date, as that's the date most relevant to news articles; it doesn't really matter when a spelling error was last corrected. For other kinds of articles however, like for example a Wikipedia entry, it doesn't really matter when the article was first published, so for those the algorithm tries to find the date where they were last modified.
Results for the date extraction are streamed to the frontend live as they come in using Amber's [WebSocket Chat](https://docs.amberframework.org/amber/cookbook/websocket-chat) functionality. For each date extraction request a [UUID](https://github.com/uuidjs/uuid) is generated which is used to identify the "chat" channel that both the server and the client connect to. For all date extraction requests both the time needed to fetch the actual site as well as the compute time are measured separately on a per-link basis and presented in a table alongside the results and the strategy that led to the successful extraction of a date, if it did. On top of that, the total server time needed is also measured. A detailed explanation on how the internal algorithm works will be provided in a later section.

### Search

The search functionality takes whichever query is given and attempts to find the most relevant ones among the links provided. It'll present the results in order of relevancy, displayed with the date extracted using the previously described functionality, a title if applicable, and a short preview snippet that has the search terms highlighted. It is noteworthy that as of now matches are case-insensitive, but only exact. Things like word stems or plurals are currently not supported, but could be using something like [Cadmium's stemmer](https://github.com/cadmiumcr/stemmer) in the future.

## Deployment

A prerequisite to doing anything with Pedestrian Search is installing [Crystal](https://crystal-lang.org/) ([installation guide](https://crystal-lang.org/docs/installation/)).

This project includes a file with the settings for the production environment located at `config/environments/.production.enc`. It is encrypted and can only be decrypted and changed using an encryption key generated by Amber. To actually deploy this application yourself you will need to provide your own `.production.enc` file using your own encryption key. A guide on how to set it up can be found [in the Amber documentation](https://docs.amberframework.org/amber/guides/configuration). Otherwise you can only run this using the development environment.

To deploy first of all follow Amber's [deployment instructions](https://docs.amberframework.org/amber/deployment), which I deem unnecessary to reiterate here. For this step you will also need the encryption key from the previous step, should you be wanting to deploy using the production environment.

In addition to setting up the application itself it is necessary to run a redis instance, which should be listening on the default port of 6379. You can set one up by following the [redis quick start guide](https://redis.io/topics/quickstart). In addition to following the guide it is very important that redis provides a Unix socket at `/tmp/redis.sock` as Amber's default [redis interface](https://github.com/stefanwille/crystal-redis) requires this. For this the `redis.conf` file used in the setup should have the two lines `unixsocket /tmp/redis.sock` and `unixsocketperm 755`.

Beyond that two folders need to be created that are part of Amber's default folder structure, but unused in this project, which are `<project_folder>/config/initializers` and `<project_folder>/src/models`. I chose not to remove all the `require`s that look at these folders as they're easy to forget to put back in should the project be expanded to use those folders. Unfortunately git doesn't seem to support adding empty directories to the repo.

Once all the instructions for setup have been followed simply run `npm install . && npm run release`, `shards build pedestrian-search --release`, and `./bin/pedestrian-search` to get things up and running.

## Application Flow

Let's examine, in great detail, where in our applications things end up in the application from start to finish for our two workflows.

### Date Extraction

When the button "Extract Dates" is hit [the JavaScript function `extract()`](https://github.com/badBlackShark/pedestrian-search/blob/32d32297f63c3ad467e3ea2acfd8698ceff9570e/src/assets/javascripts/extract.js#L8-L49) is called. It first [removes all previously displayed results](https://github.com/badBlackShark/pedestrian-search/blob/32d32297f63c3ad467e3ea2acfd8698ceff9570e/src/assets/javascripts/remove_results.js#L1-L13) and then gets the newline-separated links from the large textarea on the site, making sure the field isn't empty. It then [renders the table](https://github.com/badBlackShark/pedestrian-search/blob/32d32297f63c3ad467e3ea2acfd8698ceff9570e/src/assets/javascripts/extract.js#L51-L82) the results will appear in as soon as they're ready. Before making a request the script joins the WebSocket channel that will be used to stream the results in using a UUID generated by [the UUID library](https://github.com/uuidjs/uuid). The UUID is necessary to avoid multiple clients receiving the results from someone else's request.
Once this is done a POST request is made to the `/extract` endpoint, sending the URLs as JSON in the body. The `X-Request-ID` header is used to tell the server the UUID for the WebSocket channel, so the server knows where to send the results to.

Now the [controller](https://github.com/badBlackShark/pedestrian-search/blob/32d32297f63c3ad467e3ea2acfd8698ceff9570e/src/controllers/extract_controller.cr#L2-L44) accepts this request, making sure the content type is actually `application/json`. From here the timing for our total server time measurement starts. We construct our URLs from the request, making sure to omit all empty ones. By default the date extractor we want to use will emply the `LexborCombo` strategy that was described earlier. We attempt to construct a [`Job`](https://github.com/badBlackShark/pedestrian-search/blob/32d32297f63c3ad467e3ea2acfd8698ceff9570e/src/services/helpers/job.cr) for each of the provided URLs. For now only valid `Job`s will be displayed as results in the end, but the behavior could also very easily be changed to also display when a URL wasn't valid. All valid `Job`s are sent through a `Channel` in their own `Fiber` to our `DateExtractor`, specifically to the [`extract` method](https://github.com/badBlackShark/pedestrian-search/blob/32d32297f63c3ad467e3ea2acfd8698ceff9570e/src/services/date_extractor.cr#L11-L55), which allows for asynchronous computation.

This method first checks if the date has already been extracted for this website. If the cache is successfully hit the date simply gets returned without further requests or computation.
If the cache misses, we first need to get the content of the website we want to extract a date for. This is done by the [`Requester`](https://github.com/badBlackShark/pedestrian-search/blob/32d32297f63c3ad467e3ea2acfd8698ceff9570e/src/services/requester.cr).
The `Requester` first tries to get the content from the cache also and starts making requests only if that fails. If it does indeed fail the `Requester` makes a simple GET request to the site in question. If there's an error on the server's side the request will be retried after a certain backoff time for a certain amount of times, both of which are configurable on a per-job basis. Likewise a configurable amount of redirects will be automatically followed. If the requester succeeds in acquiring the site's content it is cached and then returned. If this is not successful, an [`ErrorResult`](https://github.com/badBlackShark/pedestrian-search/blob/32d32297f63c3ad467e3ea2acfd8698ceff9570e/src/services/helpers/error_result.cr) is returned.
No matter the outcome the result gets sent back to our `DateExtractor` instance. `ErrorResult`s immediately get returned to the controller. Assuming that the content could be fetched this is where the computation part of the workflow begins. The raw html is now sent to the [`extract_date`](https://github.com/badBlackShark/pedestrian-search/blob/32d32297f63c3ad467e3ea2acfd8698ceff9570e/src/services/date_extractor.cr#L57-L178) method to be further processed. We use Lexbor, as mentioned above, and then attempt four different strategies with descending accuracy to attempt to get a date. This algorithm will be described in detail later. If one of these strategies is successful a `Time` together with a [`DateSource`](https://github.com/badBlackShark/pedestrian-search/blob/32d32297f63c3ad467e3ea2acfd8698ceff9570e/src/services/helpers/date_source.cr) to indicate which strategy succeeded. If this was successful the extracted date is cached and a [`Result`](https://github.com/badBlackShark/pedestrian-search/blob/32d32297f63c3ad467e3ea2acfd8698ceff9570e/src/services/helpers/result.cr) is returned. If the algorithm didn't succeed in extraction an `ErrorResult` is returned instead.
Now we jump back to the controller, where the `Channel` we used to send our `Job`s now receives the results. Each of them gets broadcast as a message through the WebSocket channel with the UUID provided in the `X-Request-ID` header by our JavaScript script in JSON form. Once all results have been sent the stop the timer on how long we needed in total and send that to the frontend, too.
Back in the frontend each incoming result now [gets rendered](https://github.com/badBlackShark/pedestrian-search/blob/32d32297f63c3ad467e3ea2acfd8698ceff9570e/src/assets/javascripts/extract.js#L84-L154) to the frontend as soon as it arrives. Once the message with the total server time arrives the frontend also [renders that](https://github.com/badBlackShark/pedestrian-search/blob/32d32297f63c3ad467e3ea2acfd8698ceff9570e/src/assets/javascripts/extract.js#L43-L45) and then leaves the channel, as it knows that all the results have been sent and received.
This concludes the date extraction workflow.

### Searching

Once again we begin once the button, this time the "Search" one, is hit. Doing so calls [the `search()` function](https://github.com/badBlackShark/pedestrian-search/blob/32d32297f63c3ad467e3ea2acfd8698ceff9570e/src/assets/javascripts/search.js#L3-L52) of our frontend. Like the `extract()` function it first removes all previously displayed results and gets the links from the textarea. In addition to this it also gets the search tearms from the field next to the "Search" button. Before making a request it ensures that the field for links as well as the field for the search term weren't empty. Once that's clear a POST request to the `/search` endpoint is made, with both the urls as well as the search terms in JSON form as the body. No UUID is included this time as search results are all displayed at once once they're done, not one at a time like the date extraction results.
With this we jump into the `SearchController`(https://github.com/badBlackShark/pedestrian-search/blob/32d32297f63c3ad467e3ea2acfd8698ceff9570e/src/controllers/search_controller.cr#L2-L48). Skipping the parts that are identical with the previous workflow we again send our `Job`s through a `Channel`, this time to an instance of a [`Searcher`](https://github.com/badBlackShark/pedestrian-search/blob/32d32297f63c3ad467e3ea2acfd8698ceff9570e/src/services/searcher.cr), more specifically into the [`search` method](https://github.com/badBlackShark/pedestrian-search/blob/32d32297f63c3ad467e3ea2acfd8698ceff9570e/src/services/searcher.cr#L30-L71).
The actual algorithms used will be explained later, but in short we again use the `Requester` to get the content like before. A [list of stop words](https://github.com/badBlackShark/pedestrian-search/blob/32d32297f63c3ad467e3ea2acfd8698ceff9570e/src/services/searcher.cr#L7-L23) is used to clean the search terms before searching. We parse our html using `Lexbor` and then extract the site's [content](https://github.com/badBlackShark/pedestrian-search/blob/32d32297f63c3ad467e3ea2acfd8698ceff9570e/src/services/searcher.cr#L186-L218), [meta description](https://github.com/badBlackShark/pedestrian-search/blob/32d32297f63c3ad467e3ea2acfd8698ceff9570e/src/services/searcher.cr#L162-L172) (if set), and [meta title](https://github.com/badBlackShark/pedestrian-search/blob/32d32297f63c3ad467e3ea2acfd8698ceff9570e/src/services/searcher.cr#L129-L139) (also if set). We then use these to [calculate a score](https://github.com/badBlackShark/pedestrian-search/blob/32d32297f63c3ad467e3ea2acfd8698ceff9570e/src/services/searcher.cr#L89-L127) for the website. If the score passes a certain threshold we also use the content to [compute a preview snippet](https://github.com/badBlackShark/pedestrian-search/blob/32d32297f63c3ad467e3ea2acfd8698ceff9570e/src/services/searcher.cr#L141-L160), [highlighting the search terms](https://github.com/badBlackShark/pedestrian-search/blob/32d32297f63c3ad467e3ea2acfd8698ceff9570e/src/services/searcher.cr#L178-L184) in it. If the threshold is not passed we simply return an `ErrorResult` stating that that site's score was too low which will lead to it not being displayd among the results. If it was high enough we also compute the date for the website (publication or last modification) using the previously described routine. We then send it back to the controller as a [`SearchResult`](https://github.com/badBlackShark/pedestrian-search/blob/32d32297f63c3ad467e3ea2acfd8698ceff9570e/src/services/helpers/search_result.cr).
Once all the `SearchResult`s have been computed they get sent back together to the `Searcher` to [get ranked](https://github.com/badBlackShark/pedestrian-search/blob/32d32297f63c3ad467e3ea2acfd8698ceff9570e/src/services/searcher.cr#L73-L87). This gives each site bonus points based on recency and then returns the (up to) top ten results by score.
That `Array` of `SearchResult`s then gets sent back to the frontend as a response to the request to `/search` as JSON, along with the total server time needed.
Back in the frontend we then [render each result](https://github.com/badBlackShark/pedestrian-search/blob/32d32297f63c3ad467e3ea2acfd8698ceff9570e/src/assets/javascripts/search.js#L54-L100) and [display the total computation time](https://github.com/badBlackShark/pedestrian-search/blob/32d32297f63c3ad467e3ea2acfd8698ceff9570e/src/assets/javascripts/search.js#L45-L46). If no results were found [this is also displayed](https://github.com/badBlackShark/pedestrian-search/blob/32d32297f63c3ad467e3ea2acfd8698ceff9570e/src/assets/javascripts/search.js#L48-L49).
This concludes the searching workflow.

## Algorithms

We'll now take a look at the relevant algorithms used to power the workflows described above.

### Date Extraction

This routine only uses one algorithm, the one in the [`extract_date`](https://github.com/badBlackShark/pedestrian-search/blob/32d32297f63c3ad467e3ea2acfd8698ceff9570e/src/services/date_extractor.cr#L57-L178) method.
This algorithm essentially uses four different strategies to try to determine a date for the HTML content it's given. Here are they, in descending accuracy (how we determine which date to search for with the `LexborCombo` strategy will be described below):

1. A lot of websites have a `<script>` tag of type `application/ld+json`. This is used for SEO, which we can leverage. This JSON content can have some different forms with different kinds of nesting, so we first simply look for a date at the top level. If that isn't found we simply scan the raw JSON String for the first appearance of the kind of date we're looking for and take it.
2. If that didn't work, we check the `<meta>` tags for the kind of dates we're looking for using [a set of hints](https://github.com/badBlackShark/pedestrian-search/blob/32d32297f63c3ad467e3ea2acfd8698ceff9570e/src/services/date_extractor.cr#L5-L6). Depending on which kind of date we want we either take the oldest one we find (for a publication date) or the most recent one we find (for the last modified date).
3. If that also didn't work we check all the present `<time>` tags for something including one of our hints, respecting the kind of date we're looking for. If we do find one, we simply take that.
4. If even that didn't yield any results we scan the entirety of the HTML String for something that resembles a date and just take the first one we can find. This strategy no longer respecs what kind of date we're looking for, it simply takes the first date it can find. Ideally it's never used, but it is unfortunately necessary for sites like GitHub.

Now how do we determine which date to look for? If the `LexborPublished` or `LexborModified` strategy is used the choice is obviously clear. For the `LexborCombo` strategy we try to figure out if the article in question in news.
For the first strategy we look if the `@type` property of the SEO JSON includes the word "news". If it does we look for a publication date, otherwise we look for a modification date.
For strategy two and three we check the `<meta>` tags for an `og:type` tag. If it is "article" then we claim this site ot be news and look for a publication date, otherwise we look for a modification date going forward.

### Search

This algorithm has a couple components, which will be explained separately.

#### Content Extraction

The general idea of [this algorithm](https://github.com/badBlackShark/pedestrian-search/blob/32d32297f63c3ad467e3ea2acfd8698ceff9570e/src/services/searcher.cr#L186-L218) is that the actual article content of a website should be contained in `<p>` tags. However, not all sites do this (and instead use `<div>`s to display their content), and so part of this algorithm is inspired by [Mozilla's Readability](https://github.com/mozilla/readability). We basically look for `<div>`s that don't have any of the [red flags](https://github.com/badBlackShark/pedestrian-search/blob/32d32297f63c3ad467e3ea2acfd8698ceff9570e/src/services/searcher.cr#L5) we defined in their properties, or in any of their children's properties. We now check each child node of theirs for [being content](https://github.com/badBlackShark/pedestrian-search/blob/32d32297f63c3ad467e3ea2acfd8698ceff9570e/src/services/searcher.cr#L220-L224) and [not whitespace](https://github.com/badBlackShark/pedestrian-search/blob/32d32297f63c3ad467e3ea2acfd8698ceff9570e/src/services/searcher.cr#L226-L228). Content in this sense is defined as being text itself, or being an `<a>`, `<del>`, or `<ins>` node as well as all children being content by the same definition. Those child nodes of our `<div>` then get replaced by a `<p>` node with the same content.
After this we add all `<p>` nodes to our content String, besides those being empty or "Advertisment".

#### Title & Description Extraction

The algorithms for [extracting a description](https://github.com/badBlackShark/pedestrian-search/blob/32d32297f63c3ad467e3ea2acfd8698ceff9570e/src/services/searcher.cr#L162-L172) and [a title](https://github.com/badBlackShark/pedestrian-search/blob/32d32297f63c3ad467e3ea2acfd8698ceff9570e/src/services/searcher.cr#L129-L139) work very similarly. We go through all the `<meta>` tags looking for a tag with an attribute that includes "description" or "title" respectively. For the description we then simply return the longest of those tags' contents. With the title it turns out that simply taking the last one found produces very good results, so we go with that.

#### Scoring

The [scoring algorithm](https://github.com/badBlackShark/pedestrian-search/blob/32d32297f63c3ad467e3ea2acfd8698ceff9570e/src/services/searcher.cr#L89-L127) computes both an overall score for the website as well as individual scores for each search term. Generally each time a search term is found somewhere points are added to the total score and to that term's score.

-   Hits within the website's extracted content count 1x. So one point for each hit.
-   Hits within the entirety of the url or in the website's extracted title count 30x as they are deemed highly relevant.
-   Hits within the extracted description count 15x as the description should be a great condensed version of the site's content, albeit not quite as condensed as the url and the title.
-   If a search term is found to be part of the uri's hostname it is determined that this website was searched for specifically. If at least one other search term was also found somewhere else on the site a bonus of 100 points is awared.
-   If the website contained every single one of the search terms an additional bonus of 100 points is awarded.

#### Results Ranking

In addition to the scoring algorithm itself all results that received more than 31 points get a snippet generated (see below) and then later [ranked among each other](https://github.com/badBlackShark/pedestrian-search/blob/32d32297f63c3ad467e3ea2acfd8698ceff9570e/src/services/searcher.cr#L73-L87). Essentially results are split within those where a date could be extracted and ones without a date. Those with a date get bonus points towards their score depending on their relative recency. All results get one bonus point for each day they are more recent than compared to the oldest result. So if there's a result from today, one from 15 days ago, and one from 30 days ago, the first result would get 30 bonus points, the second one would get 15 bonus points, and the last result's score will stay the same.
All results, dated or not, will be then be combined and sorted by their updated scores, picking (up to) the ten best ones.

#### Snippet Generation

The [snippet generation algorithm](https://github.com/badBlackShark/pedestrian-search/blob/32d32297f63c3ad467e3ea2acfd8698ceff9570e/src/services/searcher.cr#L141-L160) first looks at the description extracted earlier, if one was found. If a search term appears in it, it simply takes that description as the preview snippet.
If there is no description set or it doesn't contain any of the search terms the content is scanned for the first appearance of the most relevant search term for that site, which is determined to be the one with [the highest individial score](https://github.com/badBlackShark/pedestrian-search/blob/32d32297f63c3ad467e3ea2acfd8698ceff9570e/src/services/searcher.cr#L174-L176). From that appearance the algorithm looks for [the beginning of the sentence](https://github.com/badBlackShark/pedestrian-search/blob/32d32297f63c3ad467e3ea2acfd8698ceff9570e/src/services/searcher.cr#L149-L150) where the search term first appeared, and from the sentence start onwards it picks the next 30 words (appending "..." if the snippet doesn't already end with a ".").

## Development

To start your Amber server:

1. Install dependencies with `shards install`
2. Build executables with `shards build`
3. Create and migrate your database with `bin/amber db create migrate`. Also see [creating the database](https://docs.amberframework.org/amber/guides/create-new-app#creating-the-database).
4. Start a redis instance using the instructions from the deployment section.
5. Start Amber server with `bin/amber watch`

Now you can visit http://localhost:3000/ from your browser.

Getting an error message you need help decoding? Check the [Amber troubleshooting guide](https://docs.amberframework.org/amber/troubleshooting), post a [tagged message on Stack Overflow](https://stackoverflow.com/questions/tagged/amber-framework), or visit [Amber on Gitter](https://gitter.im/amberframework/amber).

Using Docker? Please check [Amber Docker guides](https://docs.amberframework.org/amber/guides/docker).

## Tests

To run the test suite:

```
crystal spec
```

## Contributing

1. Fork it ( https://github.com/badBlackShark/pedestrian-search/fork )
2. Create your feature branch ( `git checkout -b my-new-feature` )
3. Commit your changes ( `git commit -am 'Add some feature'` )
4. Push to the branch ( `git push origin my-new-feature` )
5. Create a new Pull Request

## Contributors

-   [badBlackShark](https://github.com/badBlackShark) badBlackShark - creator, maintainer
