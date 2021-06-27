<head>
  <link rel="stylesheet" href="/css/index.css">
</head>

.row.justify-content-center
  .col-sm-12.col-md-6
    h2 = t "welcome_to_pedestrian"
    p Please enter the links you wish the crawl in the text area below and then hit the "Extract Dates" button!
    / .list-group
      / a.list-group-item.list-group-item-action target="_blank" href="https://docs.amberframework.org" Getting Started with Amber Framework
      / a.list-group-item.list-group-item-action target="_blank" href="https://github.com/veelenga/awesome-crystal" List of Awesome Crystal projects and shards
      / a.list-group-item.list-group-item-action target="_blank" href="https://crystalshards.xyz" What's hot in Crystal right now


  == form(action: "/", method: :post) do
    == csrf_tag
    .form-group
      == text_area(id: "linksarea", name: "linksarea", content: nil, required: true, placeholder: "Put your links to extract dates for here", rows: 20, cols: 100)
    == submit("Extract Dates", class: "btn btn-success btn-sm", onclick: "extract();return false")
    == submit("Clear Cache", class: "btn btn-danger btn-sm")


  == text_field(id: "searchfield", name: "searchField", content: nil, required: true, placeholder: "Search for anything")
  == submit("Search", class: "btn btn-success btn-sm", onclick: "search();return false")



<div class="statusContainer">
  <div class="statusArea">
    <p id="statusMessage">Hit the "Extract Dates" button to find article dates, or start a search.</p>
  </div>
</div>

<div id="results"></div>

<script src="/js/amber.min.js"></script>
<script src="/js/dayjs.min.js"></script>

<script src="/js/remove_results.js"></script>
<script src="/js/date-extract/extract.js"></script>
<script src="/js/search.js"></script>
