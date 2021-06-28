import * as dayjs from 'dayjs';

window.search = function () {
  remove_results();

  let urls = document.getElementById('linksarea').value.split('\n');
  urls = [...new Set(urls)];

  let status = document.getElementById('statusMessage');

  let search_term = document.getElementById('searchfield').value;

  if (urls.filter((url) => url.length > 0).length == 0) {
    status.innerText = 'No URLs to crawl were provided.';
    status.style.backgroundColor = '#ff000050';
    return;
  } else if (search_term.length == 0) {
    status.innerText = 'Please enter a search term to search.';
    status.style.backgroundColor = '#ff000050';
    return;
  }

  status.innerText = 'Searching...';
  status.style.backgroundColor = '#eeee0050';

  fetch('/search', {
    method: 'POST',
    headers: {'Content-Type': 'application/json'},
    body: JSON.stringify({urls: urls, search_term: search_term}),
  })
    .then((response) => response.json())
    .then((data) => {
      let parsed_results = data.results;

      if (parsed_results.length > 0) {
        let search_results = document.createElement('div');
        search_results.setAttribute('id', 'searchResults');
        let parent = document.getElementById('results');
        parent.appendChild(search_results);

        parsed_results.forEach((result) => {
          let result_div = render_search_result(result);
          search_results.appendChild(result_div);
        });
        status.innerText = 'Results found in ' + data.server_time + 'ms';
        status.style.backgroundColor = '#00ff0050';
      } else {
        status.innerText = 'Your query yielded no results.';
        status.style.backgroundColor = '#ff000050';
      }
    });
};

function render_search_result(result) {
  let result_div = document.createElement('div');
  result_div.setAttribute('class', 'searchResult');

  let url_div = document.createElement('div');
  url_div.setAttribute('class', 'searchResultUrlContainer');
  const url = new URL(result.uri);
  let url_node = document.createElement('a');
  url_node.setAttribute('class', 'searchResultUrl');
  url_node.setAttribute('href', result.uri);
  url_node.innerText = url.hostname + url.pathname;
  if (Array.from(url.searchParams).length > 0) {
    url_node.innerText += '?' + url.searchParams;
  }

  url_div.appendChild(url_node);
  result_div.appendChild(url_div);

  let title_div = document.createElement('div');
  title_div.setAttribute('class', 'searchResultTitleContainer');
  let title_node = document.createElement('a');
  title_node.setAttribute('class', 'searchResultTitle');
  title_node.setAttribute('href', result.uri);
  title_node.innerText = result.title || result.uri;
  title_div.appendChild(title_node);

  result_div.appendChild(title_div);

  let desc_div = document.createElement('div');
  desc_div.setAttribute('class', 'searchResultDescriptionContainer');
  let desc_content = document.createElement('div');
  desc_content.setAttribute('class', 'searchResultDescriptionContent');
  desc_div.appendChild(desc_content);

  if (result.date) {
    let date_node = document.createElement('span');
    date_node.setAttribute('class', 'searchResultDate');
    date_node.innerText = dayjs(result.date).format('MMM DD, YYYY') + ' - ';
    desc_content.appendChild(date_node);
  }

  desc_content.innerHTML += result.snippet || 'No suitable preview snippet could be generated.';

  result_div.appendChild(desc_div);

  return result_div;
}
