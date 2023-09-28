Pod::Spec.new do |spec|
  spec.name         = "AppStats"
  spec.version      = "0.0.4"
  spec.summary      = "Collect app events."
  spec.description  = <<-DESC
                   - 收集 app 的一些信息，比如安装次数，启动次数，打开次数
                   - 埋点，保存一些自定义操作的记录
                   DESC

  spec.homepage     = "https://meilbn.com"
  spec.license      = "MIT"
  spec.author             = { "Meilbn" => "codingallnight@gmail.com" }
  # spec.social_media_url   = "https://twitter.com/meilbn"
  spec.platform     = :ios, "12.0"
  spec.source       = { :git => "https://github.com/meilbn/AppStats.git", :tag => "#{spec.version}" }
  spec.swift_version             = '5'
  spec.source_files  = "AppStats/*.swift"
  spec.dependency "Moya", "~> 15.0"
  spec.dependency "Alamofire", "~> 5.0"
  spec.dependency "RealmSwift", "~> 10.0"
  spec.dependency "SwiftyJSON", "~> 5.0"
end