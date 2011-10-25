# Change this and uncomment if you do not have an environment var for IPHONE_IP set up
# Before upload to iphone, you should edit Ip config file: /tmp/iphoneIP, content like "192.168.1.2"

IPHONECONFIGFILE=/tmp/iphoneIP
IPHONE_IP=192.168.1.3

INFOPLIST_FILE=Info.plist
SOURCES=$(wildcard *.m)
RESPNG=$(wildcard *.png)

#CC=/usr/local/bin/arm-apple-darwin-gcc
CC=/Developer/Platforms/iPhoneOS.platform/Developer/usr/bin/arm-apple-darwin10-gcc-4.0.1
CFLAGS=-I/usr/local/arm-apple-darwin/include \
		-I/usr/sendwave/iphoneenv/iphone-filesystem/usr/include \
		-I/usr/sendwave/iphoneenv/arm-apple-darwin-curver/include \
		-F/usr/sendwave/iphoneenv/iphone-filesystem/System/Library/PrivateFrameworks \
		-F/usr/sendwave/iphoneenv/iphone-filesystem/System/Library/Frameworks \
		-fobjc-abi-version=2 \
		-march=armv6 \
		-DDEBUG_ENABLED \
		-mcpu=arm1176jzf-s 

LD=$(CC)
LDFLAGS=-framework Foundation \
		-framework CoreFoundation \
		-framework UIKit \
		-framework QuartzCore \
		-framework CoreGraphics \
		-framework GraphicsServices \
		-framework CoreSurface \
		-framework CoreAudio \
		-framework Celestial \
		-framework AudioToolbox \
		-framework AddressBookUI \
		-framework AddressBook \
		-F/usr/sendwave/iphoneenv/iphone-filesystem/System/Library/PrivateFrameworks \
		-F/usr/sendwave/iphoneenv/iphone-filesystem/System/Library/Frameworks \
		-lobjc \
		-bind_at_load \
		-multiply_defined suppress \
		-march=armv6 \
		-mcpu=arm1176jzf-s \
		-L/usr/local/arm-apple-darwin/lib \
		-L/usr/sendwave/iphoneenv/iphone-filesystem/usr/lib


PROJECT=libserial.dylib
SRC=serial.c
OBJS=serial.o

$(PROJECT): 
	$(CC) $(CFLAGS) $(CPPFLAGS) -c $(SRC) 
	$(LD) $(LDFLAGS) -o $(PROJECT) -dynamiclib $(OBJS)
	cp $(PROJECT) /Developer/Platforms/iPhoneOS.platform/Developer/usr/lib	

#up:
	@echo "----- upload -----"
	scp -r $(PROJECT) root@$(IPHONE_IP):/usr/lib
	scp -r ~dan/Documents/iScope/iScopeApp/build/Debug-iphoneos/iScope.app root@$(IPHONE_IP):/private/var/stash/Applications.OuI2mM/
	
clean:
	rm -fr *.o $(PROJECT)

up:
	@echo "----- upload -----"
	scp -r $(PROJECT) root@$(IPHONE_IP):/usr/lib
	scp -r ~dan/Documents/iScope/iScopeApp/build/Debug-iphoneos/iScope.app root@$(IPHONE_IP):/private/var/stash/Applications.pwn/
#	scp -r ~dan/Documents/iScope/iScopeApp/build/Debug-iphoneos/iScope.app root@$(IPHONE_IP):/private/var/stash/Applications.OuI2mM/
