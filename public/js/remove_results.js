async function remove_results() {
  let table = document.getElementById('resultsTable');

  if (table) {
    table.remove();
  }

  let searchResults = document.getElementById('searchResults');

  if (searchResults) {
    searchResults.remove();
  }
}
