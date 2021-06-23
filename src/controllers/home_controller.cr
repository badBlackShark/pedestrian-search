class HomeController < ApplicationController
  def index
    render("index.slang")
  end

  def clear
    WebsiteCache.clear!
    render("index.slang")
  end
end
