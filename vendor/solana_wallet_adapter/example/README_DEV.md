### Run for Web (HTTPS)

Set up HTTPS on localhost using this [post](https://medium.com/@jonsamp/how-to-set-up-https-on-localhost-for-macos-b597bcf935ee)

1. Build for web
```
$ flutter clean && flutter build web
```

2. Run web server
```
$ cd build/web && http-server --ssl --cert ~/.localhost-ssl/localhost.crt --key ~/.localhost-ssl/localhost.key
```