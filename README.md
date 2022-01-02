# haProxy2SS
Download public proxy resource, check speed, and auto deploy as haproxy server

## Usage 
```
./freeSS.sh [params]
	-b BASE: base dir, where to find configs and functions. default: ./
	-t TIMEOUT: timeout time of check resource. default: 5s
	-c COUNT: parallel count when check resources. default: 50
	-p PORT: local listen port when check resources. default: 20000
	-f FILE: save valid resources to this file.
	-P script: script to be executed after success get resource
	-s: do not delete temp files
	-v: verbose output
	-D: debug mode
	-h: print help
```
## Example
### Colloct free SS and save to file ss.lst
```
./freeSS.sh -f ss.lst
```

### Colloct free SS and save to file ss.lst, and public to mqtt
```
./freeSS.sh -f ss.lst -P commands/mqtt_pub.sh
```

### Colloct free SS and update haproxy setting
```
./freeSS.sh -P commands/haProxy.sh
```


## folders
  - commands: sub-scripts
  - functions: public functions
  - protocols: protocol deps configs
    - decode-ss: 
      - ss://method:password@server:port
    - decode-ssr
      - ssr://server:port:protocol:method:obfs:password_base64/?params_base64
        - params_base64: obfsparam=obfsparam_base64&protoparam=protoparam_base64&remarks=remarks_base64&group=group_base64
  - sources: public proxy source
