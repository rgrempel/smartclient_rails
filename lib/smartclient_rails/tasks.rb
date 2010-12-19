require 'rake'

namespace :smartclient_rails do
  desc "Copy javascript files to public/javascript"
  task :copy_javascript do
    FileList[File.expand_path('../javascript/*.js', __FILE__)].each do |source|
      cp source, Rails.root.join('public', 'javascripts'), :verbose => true
    end
  end
end
