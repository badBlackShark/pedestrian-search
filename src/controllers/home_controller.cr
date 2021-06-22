class HomeController < ApplicationController
  def index
    render("index.slang")
  end

  def extract
    links = params.[:linksarea].split("\r\n")
    links.each { |link| p link }
  end
end
