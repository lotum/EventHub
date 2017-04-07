
Pod::Spec.new do |s|

  s.name         = "LotumEventHub"
  s.version      = "0.0.1"
  s.summary      = "Observer pattern implementation in swift"

  s.description  = <<-DESC
      EventHub is a observer pattern implementation. You can register for events and emit those events.
                   DESC

  s.homepage     = "https://github.com/LOTUM/EventHub"
  s.license      = "Apache License, Version 2.0"

  s.author       = { "Sebastian" => "bastianschilbe@users.noreply.github.com" }

  s.source       = { :git => "https://github.com/LOTUM/EventHub.git", :tag => "#{s.version}" }

  s.source_files  = "EventHub/**/*.swift"

  s.requires_arc          = true

  s.ios.deployment_target = '9.0'

end
