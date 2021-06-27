let socket = new Amber.Socket('/frontend');
socket.connect().then(() => {
  let channel = socket.channel('frontend_stream:1');
  channel.join();

  channel.on('message_new', (message) => {
    const json = JSON.parse(message['message']);
    if (json['type'] == 'result') {
      render_result(json['result']);
    } else {
      var status = document.getElementById('statusMessage');
      status.setAttribute('style', 'background-color: #00ff0050;');
      status.innerText = json['message'];
    }
  });
});

async function extract() {
  var urls = document.getElementById('linksarea').value.split('\n');
  urls = [...new Set(urls)];

  var status = document.getElementById('statusMessage');
  status.innerText = 'Extracting dates...';
  status.setAttribute('style', 'background-color: #eeee0050;');

  render_table();

  fetch('/extract', {
    method: 'POST',
    headers: {'Content-Type': 'application/json'},
    body: JSON.stringify({urls: urls}),
  });
}

function render_table() {
  remove_results();

  table = document.createElement('table');
  table.setAttribute('id', 'resultsTable');
  table.setAttribute('width', '100%');

  let thead = table.createTHead();

  let row = thead.insertRow();
  let th = document.createElement('th');
  let text = document.createTextNode('Link');
  th.appendChild(text);
  row.appendChild(th);
  th = document.createElement('th');
  text = document.createTextNode('Result');
  th.appendChild(text);
  row.appendChild(th);
  th = document.createElement('th');
  text = document.createTextNode('Request Time');
  th.appendChild(text);
  row.appendChild(th);
  th = document.createElement('th');
  text = document.createTextNode('Compute Time');
  th.appendChild(text);
  row.appendChild(th);
  th = document.createElement('th');
  text = document.createTextNode('Strategy Used');
  th.appendChild(text);
  row.appendChild(th);

  let parent = document.getElementById('results');
  parent.appendChild(table);
}

function render_result(result) {
  let table = document.getElementById('resultsTable');
  let row = document.createElement('tr');
  table.appendChild(row);

  let url_node = document.createElement('a');
  url_node.setAttribute('class', 'resultUrl');
  url_node.setAttribute('href', result.uri);
  url_node.innerText = result.uri;
  let url_slot = document.createElement('td');
  url_slot.appendChild(url_node);
  row.appendChild(url_slot);

  if (!result.code) {
    let date_node = document.createElement('span');
    date_node.setAttribute('class', 'resultDate');
    date_node.innerText = dayjs(result.date).format('MMM DD, YYYY');
    let date_slot = document.createElement('td');
    date_slot.appendChild(date_node);
    row.appendChild(date_slot);

    let request_time_node = document.createElement('span');
    request_time_node.setAttribute('class', 'resultRequestTime');
    request_time_node.innerText = result.request_time_needed + 'ms';
    let request_time_slot = document.createElement('td');
    request_time_slot.appendChild(request_time_node);
    row.appendChild(request_time_slot);

    let compute_time_node = document.createElement('span');
    compute_time_node.setAttribute('class', 'resultComputeTime');
    compute_time_node.innerText = result.compute_time_needed + 'ms';
    let compute_time_slot = document.createElement('td');
    compute_time_slot.appendChild(compute_time_node);
    row.appendChild(compute_time_slot);

    let strategy_node = document.createElement('span');
    strategy_node.setAttribute('class', 'strategy');
    strategy_node.innerText = result.date_source_text;
    let strategy_slot = document.createElement('td');
    strategy_slot.appendChild(strategy_node);
    row.appendChild(strategy_slot);
  } else {
    let message_node = document.createElement('span');
    message_node.setAttribute('class', 'resultError');
    message_node.innerText = result.message;
    let message_slot = document.createElement('td');
    message_slot.appendChild(message_node);
    row.appendChild(message_slot);

    let request_time_node = document.createElement('span');
    request_time_node.setAttribute('class', 'resultRequestTime');
    request_time_node.innerText = result.request_time_needed + 'ms';
    let request_time_slot = document.createElement('td');
    request_time_slot.appendChild(request_time_node);
    row.appendChild(request_time_slot);

    let compute_time_node = document.createElement('span');
    compute_time_node.setAttribute('class', 'resultComputeTime');
    compute_time_node.innerText = result.compute_time_needed + 'ms';
    let compute_time_slot = document.createElement('td');
    compute_time_slot.appendChild(compute_time_node);
    row.appendChild(compute_time_slot);

    let strategy_node = document.createElement('span');
    strategy_node.setAttribute('class', 'strategy');
    strategy_node.innerText = result.date_source_text;
    let strategy_slot = document.createElement('td');
    strategy_slot.appendChild(strategy_node);
    row.appendChild(strategy_slot);
  }
}
