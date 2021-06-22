struct FrontendSocket < Amber::WebSockets::ClientSocket
  channel "frontend_stream:*", FrontendChannel

  def on_connect
    true
  end
end
