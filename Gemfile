source "https://rubygems.org"

ruby "3.3.5"

# Keep dotenv at top to ensure ENV variables are loaded before other gems initialize
gem "dotenv", require: "dotenv/load", groups: %i[development test]

gem "bootsnap", require: false
gem "importmap-rails"
gem "net-ssh"
gem "ostruct" # to supress deprecation warning, gem will not be part of Ruby 3.5
gem "pg"
gem "propshaft"
gem "puma"
gem "rails"
gem "sqlite3"
gem "stimulus-rails"
gem "turbo-rails"
gem "typhoeus"

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[mri mingw x64_mingw]
  gem "rspec-rails"
end

group :development do
  gem "web-console"
end

group :production do
  gem "cloudflare-rails" # fixes request.remote_ip behind Cloudflare proxy
end
