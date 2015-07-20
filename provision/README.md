running the usergrid stack on aws
=================================

cassandra configuration environment variables:

    CLUSTER_NAME


getting started
---------------

 - generate key pair in the aws console or add a key pair to the aws console
 - start the community ami `ami-8ec1f293` called `CoreOS-stable-557.2.0-hvm` of size `m3.medium` as spot instance
 - set up an ssh alias called `aws` so you can ssh into the machine by typing `ssh aws`
 - run `aws_deploy.sh`


apns setup note
---------------

when generating the `notifier` in usergrid, a .p12 certificate is required.

to create this .p12 certificate, you have to select BOTH the private key (of type `private key`) and the public key signed by apple (of type `certificate`) in the apple keychain osx app AT THE SAME TIME and then export both of them into one .p12 file.
