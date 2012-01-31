if ENV['SENDGRID_USERNAME'].present?
  ActionMailer::Base.smtp_settings = {
    :user_name => ENV['SENDGRID_USERNAME'],
    :password => ENV['SENDGRID_PASSWORD'],
    :domain => ENV['SENDGRID_DOMAIN'],
    :address => 'smtp.sendgrid.net',
    :port => '25',
    :authentication => :plain
  }
end

