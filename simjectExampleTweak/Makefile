TARGET := simulator:clang:latest:12.0
ARCHS := arm64
IPHONE_SIMULATOR_ROOT := /opt/simject

DEBUG := 0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME += simjectExampleTweak

simjectExampleTweak_FILES += simjectExampleTweak.x
simjectExampleTweak_CFLAGS += -fobjc-arc -Wno-deprecated-declarations

include $(THEOS_MAKE_PATH)/tweak.mk

setup:: clean all
	@sudo rm -f /opt/simject/$(TWEAK_NAME).dylib
	@sudo cp -v $(THEOS_OBJ_DIR)/$(TWEAK_NAME).dylib /opt/simject/$(TWEAK_NAME).dylib
	@sudo codesign -f -s - /opt/simject/$(TWEAK_NAME).dylib
	@sudo cp -v $(PWD)/$(TWEAK_NAME).plist /opt/simject
