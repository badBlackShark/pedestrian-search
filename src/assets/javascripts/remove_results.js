window.remove_results = function () {
  let table = document.getElementById('resultsTable');

  if (table) {
    table.remove();
  }

  let searchResults = document.getElementById('searchResults');

  if (searchResults) {
    searchResults.remove();
  }
};
