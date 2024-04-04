source "https://rubygems.org"

ruby "3.2.0"

gem "bootsnap", require: false
gem "importmap-rails"
gem "net-ssh"
gem "pg"
gem "propshaft"
gem "puma"
gem "rails"
gem "stimulus-rails"
gem "turbo-rails"
gem "typhoeus"

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[mri mingw x64_mingw]
  gem "dotenv"
  gem "rspec-rails"
end

group :development do
  gem "web-console"
end

group :production do
  gem "cloudflare-rails" # fixes request.remote_ip behind Cloudflare proxy
end
