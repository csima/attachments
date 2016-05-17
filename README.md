Description:

This project was just meant as a learning excercise for the gmail API. The frontend is a rails server (/attachments_web) that allows users to login via Google login and presents a search bar that allows the user to provide a keyword that will search their Gmail account for all attachments that are associated with those search results and download them into a single zip file. It maintains the email date & timestamp for each attachment. 

attachments_web - rails frontend for the API and website. Ideally I should replace this with a simple Go API server but I have no motivation to do so.
attachments_worker - workers are the backend. I initially wrote them in Ruby and it uses Sidekiq for a queue. This is the ruby version. Ignore this. Instead use the Go version.
attachments_goworker - the Go version of the workers. Much quicker, better memory footprint, much more stable and hey it's go so that makes it hip and cool.
redis - self explanatory

The project is built on top of Sidekiq for fast processing and on a good connection it's extremely fast. Last timed it can download about 400 attachments in less then 5 minutes. 

Each component has an individual Dockerfile for easy setup and deployment. 
Important Note: edit the required-configuration.env file in each folder and supply the appropriate environment variables - otherwise everything will puke. Make sure you set these variables in the Docker container.

In order to make this project work you have to sign up for a google developers account and walk thru creating a an app. Tutorial is here: https://developers.google.com/gmail/api/auth/about-auth#why_use_google_for_authentication 
You will also need an S3 location and of course the appropriate access keys etc to rw to s3.
