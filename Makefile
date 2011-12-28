APPID = org.webosinternals.pulseaudio.settings

package: clean
	cp -a c-binary node-service/bin
	rm -f node-service/bin/*.c
	rm -f node-service/bin/Makefile
	palm-package enyo-app package node-service
	rm -rf node-service/bin
	ar q ${APPID}_*.ipk pmPostInstall.script
	ar q ${APPID}_*.ipk pmPreRemove.script

test: package
	- palm-install -r ${APPID}
	palm-install ${APPID}_*.ipk
	palm-launch ${APPID}

clean:
	find . -name '*~' -delete
	rm -f ipkgtmp*.tar.gz
	rm -f ${APPID}_*.ipk

clobber: clean
