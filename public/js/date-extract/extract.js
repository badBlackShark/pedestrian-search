let socket = new Amber.Socket('/frontend');
socket.connect().then(() => {
  let channel = socket.channel('frontend_stream:1');
  channel.join();

  channel.on('message_new', (message) => {
    const json = JSON.parse(message['message']);
    console.log(json);
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
  status.innerText = 'Working on it...';
  status.setAttribute('style', 'background-color: #eeee0050;');

  render_table();

  fetch('/extract', {
    method: 'POST',
    headers: {'Content-Type': 'application/json'},
    body: JSON.stringify({urls: urls}),
  });
}

function render_table() {
  let table = document.getElementById('results_table');

  if (table) {
    table.remove();
  }

  table = document.createElement('table');
  table.setAttribute('id', 'results_table');
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
  text = document.createTextNode('Computation Time');
  th.appendChild(text);
  row.appendChild(th);

  let parent = document.getElementById('results');
  parent.appendChild(table);
}

function render_result(result) {
  let table = document.getElementById('results_table');
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
    date_node.innerText = result.date;
    let date_slot = document.createElement('td');
    date_slot.appendChild(date_node);
    row.appendChild(date_slot);

    let time_node = document.createElement('span');
    time_node.setAttribute('class', 'resultMs');
    time_node.innerText = result.time_needed + 'ms';
    let time_slot = document.createElement('td');
    time_slot.appendChild(time_node);
    row.appendChild(time_slot);
  } else {
    let message_node = document.createElement('span');
    message_node.setAttribute('class', 'resultError');
    message_node.innerText = result.message;
    let message_slot = document.createElement('td');
    message_slot.appendChild(message_node);
    row.appendChild(message_slot);

    let time_node = document.createElement('span');
    time_node.setAttribute('class', 'resultMs');
    time_node.innerText = result.time_needed + 'ms';
    let time_slot = document.createElement('td');
    time_slot.appendChild(time_node);
    row.appendChild(time_slot);
  }
}
