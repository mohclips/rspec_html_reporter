# RSpec HTML Reporter

Publish pretty [rspec](http://rspec.info/) reports

This is a ruby RSpec custom formatter which generates pretty html reports showing the results of rspec tests. It has features to embed images and videos into report providing better debugging information in case test is failed. Check this [Sample Report](https://vbanthia.github.io/rspec_html_reporter/index.html).

# New Updates

## My updates 
July 2019
* Toggle spec details 

June 2019
* Added skip description
* Added group description
* Added OS details on overview page 
* Added TARGET_HOST environment variable (IP/host we are testing)
* Added CLOUD_ENV environment variable (Name of cloud environment)
* Graph shows count per example in labels
* Fix bug with UTF-8

* Better display of example titles
* Allow checkbox on/off of example statuses in reports


I updated this to help display CIS tests on images built in various cloud environments

## Examples

<a href=images/example_report1.PNG><img src=images/example_report1.PNG width=33%></a>  <a href=images/example_report2a.PNG><img src=images/example_report2a.PNG width=33%></a>  <a href=images/example_report2b.PNG><img src=images/example_report2b.PNG width=33%></a>

## Setup

Add this in your Gemfile:

```rb
gem 'rspec_html_reporter'
```
## Running

Either add below in your `.rspec` file

```rb
--format RspecHtmlReporter
```

or run RSpec with `--format RspecHtmlReporter` like below:

```bash
REPORT_PATH=reports/$(date +%s) bundle exec rspec --format RspecHtmlReporter spec
```

Above will create reports in `reports` directory.

## Usage
Images and videos can be embed by adding their path into example's metadata. Check this [Sample Test](./spec/embed_graphics_spec.rb).


## Credits
This library is forked from [vbanthia/rspec_html_reporter](https://github.com/vbanthia/rspec_html_reporter).
Which was forked from [kingsleyh/rspec_reports_formatter](https://github.com/kingsleyh/rspec_reports_formatter). Original Credits goes to *[kingsleyh](https://github.com/kingsleyh)*
