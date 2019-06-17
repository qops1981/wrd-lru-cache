# Interview Homework (LRU w/Web API)
#### William DeLuca

### Gem Dependencies
* `sinatra`

### Run Web API
The web API is a sinatra app that uses the LRU and Mars Trek classes
```bash
./web_api.rb
```
The API will load on your systems port 4441. You will need to either test locally OR expose port 4441 for remote testing.

### Endpoints
* `/coordinate/url/{lat}/{long}`
* `/cache`
* `/cache/hit_rate`
* `/cache/hit_counts`
* `/cache/hit_times`

### Metrics

#### Hit Rates Example
```json
{"hit":"51.16","mis":"48.84","dsc":"Hit Rates over the last 100 requests"}
```

#### Hit Counts Example
```json
{"hit":22,"mis":21,"total":43,"dsc":"Hit counts over the last 100 requests"}
```

#### Hit Times Example
```json
{"building":{"hit":{"sum":0.48393,"avg":0.04032,"min":0.01965,"max":0.11249},"miss":{"sum":0.64925,"avg":0.04328,"min":0.02503,"max":0.06572}},"full":{"miss":{"sum":0.30758,"avg":0.05126,"min":0.04152,"max":0.06616}}}
```