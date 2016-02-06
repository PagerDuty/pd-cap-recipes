## Releasing pd-cap-deploy

First make sure that the PR you are about to merge into master meets the following:

* It has been peer reviewed by at least one relevant person.
* Make sure that you have updated the `lib/pd-cap-recipes/version.rb` file to the appropriate next revision.
* You have updated the [CHANGELOG.md](CHANGELOG.md) file to contain information on changes in the release.
*

Next merge the PR and delete the branch you where using.

Create a tag for the version, the format is v1.2.3, you can do this by using the release function in GitHub.

You now are ready to let the world know what you've done!
Send an email to library-releases@pagerduty.com, here is an example:
  ```
  This release adds flags for disabling git and hipchat integration. Useful when doing deployments to VMs or containers that are not meant to require such integrations. Also new is the deploy:slow option which will deploy to in % based blocks of machines.

  upgrade is Discretionary.

  The upgrade is backwards compatible with previous releases.

  PRs:
  https://github.com/PagerDuty/pd-cap-recipes/pull/36
  https://github.com/PagerDuty/pd-cap-recipes/pull/37

  README contains details about using these features:

  https://github.com/PagerDuty/pd-cap-recipes/blob/v0.4.2/README.md
  ```
Generally make sure you [follow these guidelines](https://pagerduty.atlassian.net/wiki/display/ENG/Library+Release+Guidelines).
