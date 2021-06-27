enum ErrorCode
  UnsupportedUriScheme  = 4000
  InternalFailure       = 5000
  StrategyFailure       = 5001
  RedirectDepthExceeded = 5002
  MaxRetriesExceeded    = 5003
  UnhandledHTTPStatus   = 5004
  InvalidBody           = 5005
  ScoreTooLow           = 5006
end
