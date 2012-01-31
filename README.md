## Satellite Setup

This repo is a companion to the blog post [Beyond Heroku: "Satellite" Delayed Job Workers on EC2](http://artsy.github.com/blog/2012/01/31/beyond-heroku-satellite-delayed-job-workers-on-ec2/). See that page for a more complete walk-through of how it's used.

These files _will_ require modification to be relevant to your environment. In particular:

* `config/heroku.yml`: your own shared environment variables, including AWS credentials
* `lib/tasks/satellite.rake`: `KEY_NAME`, `IMAGE_ID`, `FLAVOR_ID`
* `config/satellite/cookbooks/example_app/recipes/deploy.rb`: git repo
* `config/satellite/cookbooks/example_app/files/default/authorized_keys`: any keys for SSH authorization
* `config/satellite/cookbooks/example_app/files/id_dsa`: a new private key, authorized for the git repo
* references to `example_app` throughout should be updated with your app name

(c) 2012 Art.sy, Inc.