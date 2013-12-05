Kickstart a Drupal development environment
==========================================

This is a meager attempt to make the traditional Drupal Quickstart Development Environment (QS DE) virtualbox applianace (See http://drupal.org/project/quickstart) auto install via Vagrant on Ubuntu 12.04.

The Vagrantfile has many variables you can configure to make this vagrant more "yours".


## Install

- Install Vagrant (http://downloads.vagrantup.com)
- Install Virtualbox (https://www.virtualbox.org/wiki/Downloads)
- Clone this repo (git clone git@github.com:elvis2/vagrant-kickstart-drupal.git)
- Goto the repo (cd vagrant-kickstart-drupal)
- Run: vagrant up
- Grab a cup of coffee.


## Comments

- I have used the Drupal Quickstart for years. I take no credit for all the hard work that was / is put in (by other developers) to make the QS DE.

- Vagrant Kickstart Drupal is headless, meaning you will not get an Ubuntu GUI to login too. All you developement tools need to be available locally, unless you like to code in VI or another text editor.

- I purposely choose to use the word Kickstart instead of Quickstart simply because there are so many Drupal Quickstart related repos on github.com. The difference I am to bring is to automate everything with less keystrokes and less knowledge of Virtualbox.

- This repo has nothing to do with the Drupal Commerce Kickstart installation profile. Though, you could install the profile once you have "vagrant kickstart drupal".


## Warnings

This repo shouldn't be for development purposes just yet. Feel free to install and test. If you find issues or a better way of doing something, just create an issue in github.
