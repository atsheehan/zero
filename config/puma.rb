workers(Integer(ENV["WEB_CONCURRENCY"] || 2))
threads_count = Integer(ENV["RAILS_MAX_THREADS"] || 5)
threads(threads_count, threads_count)

preload_app!

socket_file = File.expand_path(File.join(__dir__, "..", "tmp", "zero.sock"))
bind("unix://#{socket_file}")

rackup(DefaultRackup)
environment(ENV["RACK_ENV"] || "development")

on_worker_boot do
  ActiveRecord::Base.establish_connection
end
